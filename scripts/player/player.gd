extends CharacterBody2D
class_name Player

const RESOURCE_IDS := ["salvage", "parts", "medicine"]
const DEFAULT_ATTACK_FLASH_COLOR := Color(1.0, 0.83, 0.42, 0.75)
const DEFAULT_ATTACK_FLASH_START_SCALE := Vector2(0.8, 0.8)
const DEFAULT_ATTACK_FLASH_PEAK_SCALE := Vector2(1.1, 1.1)
const DEFAULT_ATTACK_FLASH_DURATION := 0.08
const DEFAULT_ATTACK_INDICATOR_WINDUP_COLOR := Color(1.0, 0.9, 0.62, 0.22)
const DEFAULT_ATTACK_INDICATOR_STRIKE_COLOR := Color(1.0, 0.98, 0.88, 0.9)
const DEFAULT_ATTACK_INDICATOR_WINDUP_START_SCALE := Vector2(0.82, 0.82)
const DEFAULT_ATTACK_INDICATOR_STRIKE_PEAK_SCALE := Vector2(1.05, 1.05)
const DEFAULT_HELD_WEAPON_OFFSET := Vector2(10.0, -10.0)
const DEFAULT_HELD_WEAPON_COLOR := Color(0.86, 0.86, 0.9, 1.0)
const WEAPON_DEFINITION_SCRIPT := preload("res://scripts/data/weapon_definition.gd")
const DEFAULT_WEAPON_RESOURCE := preload("res://data/weapons/kitchen_knife.tres")

signal health_changed(current: int, maximum: int)
signal energy_changed(current: int, maximum: int)
signal resources_changed(resources: Dictionary)
signal message_requested(text: String)
signal player_died()
signal interaction_prompt_changed(text: String)

@export var max_health: int = 100
@export var max_energy: int = 100
@export var move_speed: float = 180.0
@export var medicine_heal_amount: int = 35
@export_range(0.0, 4000.0, 10.0) var knockback_decay: float = 1500.0
var _equipped_weapon: Resource
@export var equipped_weapon: Resource:
	get:
		return _equipped_weapon
	set(value):
		_equipped_weapon = value
		if is_node_ready():
			_cancel_attack_windup()
			_apply_equipped_weapon()

var current_health: int
var current_energy: int
var resources: Dictionary = {
	"salvage": 0,
	"parts": 0,
	"medicine": 0,
}

var is_dead: bool = false
var is_busy: bool = false
var facing_direction: Vector2 = Vector2.UP
var attack_cooldown_remaining: float = 0.0
var _base_body_color: Color
var _nearby_interactables: Array[Node2D] = []
var _busy_label: String = ""
var _action_complete_callback: Callable
var _interaction_gate_callback: Callable
var _attack_windup_pending: bool = false
var _attack_windup_weapon: Resource
var _attack_windup_visual_only: bool = false
var _attack_flash_color: Color = DEFAULT_ATTACK_FLASH_COLOR
var _attack_flash_start_scale: Vector2 = DEFAULT_ATTACK_FLASH_START_SCALE
var _attack_flash_peak_scale: Vector2 = DEFAULT_ATTACK_FLASH_PEAK_SCALE
var _attack_flash_duration: float = DEFAULT_ATTACK_FLASH_DURATION
var _attack_indicator_windup_color: Color = DEFAULT_ATTACK_INDICATOR_WINDUP_COLOR
var _attack_indicator_strike_color: Color = DEFAULT_ATTACK_INDICATOR_STRIKE_COLOR
var _attack_indicator_windup_start_scale: Vector2 = DEFAULT_ATTACK_INDICATOR_WINDUP_START_SCALE
var _attack_indicator_strike_peak_scale: Vector2 = DEFAULT_ATTACK_INDICATOR_STRIKE_PEAK_SCALE
var _attack_indicator_lead_time: float = 0.12
var _attack_indicator_windup_start_alpha: float = 0.45
var _attack_indicator_windup_end_alpha: float = 1.0
var _attack_indicator_strike_alpha: float = 0.95
var _attack_indicator_strike_fade_duration: float = 0.10
var _attack_indicator_tween: Tween
var _invalid_weapon_warning_emitted: bool = false
var _damage_feedback_tween: Tween
var _starting_weapon: Resource
var _knockback_velocity: Vector2 = Vector2.ZERO
var _obtained_weapons: Array[Resource] = []

@onready var body_visual: Polygon2D = $Body
@onready var facing_marker: Polygon2D = $FacingMarker
@onready var attack_pivot: Node2D = $AttackPivot
@onready var weapon_visual: Polygon2D = $AttackPivot/WeaponVisual
@onready var attack_area: Area2D = $AttackPivot/AttackArea
@onready var attack_area_shape: CollisionShape2D = $AttackPivot/AttackArea/CollisionShape2D
@onready var attack_indicator: Polygon2D = $AttackPivot/AttackIndicator
@onready var attack_flash: Polygon2D = $AttackPivot/AttackFlash
@onready var pickup_detector: Area2D = $PickupDetector
@onready var interaction_detector: Area2D = $InteractionDetector
@onready var action_timer: Timer = $ActionTimer
@onready var attack_windup_timer: Timer = $AttackWindupTimer

var _spawn_position: Vector2


func _ready() -> void:
	add_to_group("player")
	_spawn_position = global_position
	current_health = max_health
	current_energy = max_energy
	_base_body_color = body_visual.color
	if attack_area_shape.shape != null:
		attack_area_shape.shape = attack_area_shape.shape.duplicate()
	_starting_weapon = _resolve_valid_weapon_resource(equipped_weapon)
	_equipped_weapon = _starting_weapon
	if _starting_weapon != null:
		_obtained_weapons = [_starting_weapon]
	_apply_equipped_weapon()
	_update_facing_visuals()
	pickup_detector.area_entered.connect(_on_pickup_detector_area_entered)
	interaction_detector.area_entered.connect(_on_interaction_detector_area_entered)
	interaction_detector.area_exited.connect(_on_interaction_detector_area_exited)
	interaction_detector.body_entered.connect(_on_interaction_detector_body_entered)
	interaction_detector.body_exited.connect(_on_interaction_detector_body_exited)
	action_timer.timeout.connect(_on_action_timer_timeout)
	attack_windup_timer.timeout.connect(_on_attack_windup_timer_timeout)
	_emit_full_state()
	_update_interaction_prompt()
	_update_render_order()


func _physics_process(delta: float) -> void:
	_decay_knockback(delta)
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_render_order()
		return
	
	if is_busy:
		velocity = _knockback_velocity
		move_and_slide()
		_update_render_order()
		return

	attack_cooldown_remaining = max(attack_cooldown_remaining - delta, 0.0)
	_handle_movement()
	velocity += _knockback_velocity
	move_and_slide()
	_update_render_order()

	if Input.is_action_just_pressed("interact"):
		_attempt_interact()

	if Input.is_action_just_pressed("attack"):
		_attempt_attack()

	if Input.is_action_just_pressed("use_medicine"):
		_attempt_use_medicine()

	if Input.is_action_just_pressed("switch_weapon"):
		_attempt_switch_weapon()


func add_resource(resource_id: String, amount: int, show_message: bool = true) -> bool:
	if amount == 0:
		return false

	if not RESOURCE_IDS.has(resource_id):
		message_requested.emit("Invalid resource id: %s" % resource_id)
		return false

	var current_amount: int = int(resources.get(resource_id, 0))
	resources[resource_id] = max(current_amount + amount, 0)
	resources_changed.emit(resources.duplicate(true))
	if show_message:
		message_requested.emit("%s +%d" % [resource_id.capitalize(), amount])
	return true


func spend_resource(resource_id: String, amount: int) -> bool:
	if amount <= 0:
		return true

	if not RESOURCE_IDS.has(resource_id):
		message_requested.emit("Invalid resource id: %s" % resource_id)
		return false

	var current_amount: int = int(resources.get(resource_id, 0))
	if current_amount < amount:
		return false

	resources[resource_id] = current_amount - amount
	resources_changed.emit(resources.duplicate(true))
	_update_interaction_prompt()
	return true


func has_resources(costs: Dictionary) -> bool:
	for resource_id in costs.keys():
		var amount := int(costs[resource_id])
		if amount <= 0:
			continue

		if not RESOURCE_IDS.has(String(resource_id)):
			return false

		if int(resources.get(String(resource_id), 0)) < amount:
			return false

	return true


func spend_resources(costs: Dictionary) -> bool:
	if not has_resources(costs):
		return false

	for resource_id in costs.keys():
		var amount := int(costs[resource_id])
		if amount <= 0:
			continue
		spend_resource(String(resource_id), amount)

	_update_interaction_prompt()
	return true


func can_spend_energy(amount: int) -> bool:
	return current_energy >= amount


func spend_energy(amount: int) -> bool:
	if amount <= 0:
		return true

	if current_energy < amount:
		return false

	current_energy -= amount
	energy_changed.emit(current_energy, max_energy)
	_update_interaction_prompt()
	return true


func restore_energy(amount: int) -> void:
	if amount <= 0:
		return

	current_energy = min(current_energy + amount, max_energy)
	energy_changed.emit(current_energy, max_energy)
	_update_interaction_prompt()


func restore_full_energy() -> void:
	current_energy = max_energy
	energy_changed.emit(current_energy, max_energy)
	_update_interaction_prompt()


func begin_timed_action(duration: float, label: String, on_complete: Callable) -> bool:
	if is_dead or is_busy:
		return false

	is_busy = true
	_busy_label = label
	_action_complete_callback = on_complete
	action_timer.start(duration)
	_update_interaction_prompt()
	return true


func cancel_timed_action() -> void:
	if not is_busy:
		return

	action_timer.stop()
	is_busy = false
	_busy_label = ""
	_action_complete_callback = Callable()
	_update_interaction_prompt()


func set_interaction_gate(callback: Callable) -> void:
	_interaction_gate_callback = callback
	_update_interaction_prompt()


func refresh_interaction_prompt() -> void:
	_update_interaction_prompt()


func take_damage(amount: int, _source: Variant = null) -> void:
	if is_dead or amount <= 0:
		return

	_apply_knockback_from_source(_source)
	current_health = max(current_health - amount, 0)
	health_changed.emit(current_health, max_health)
	_flash_body(Color(1.0, 0.45, 0.45, 1.0))
	_play_damage_feedback(_source)

	if current_health == 0:
		_die()


func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return

	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)
	_flash_body(Color(0.52, 0.87, 0.62, 1.0))


func equip_weapon(weapon: Resource, show_message: bool = true) -> bool:
	var resolved_weapon := _resolve_strict_weapon_resource(weapon)
	if resolved_weapon == null:
		if show_message:
			message_requested.emit("Invalid weapon")
		return false

	if not _has_obtained_weapon_id(resolved_weapon.weapon_id):
		_obtained_weapons.append(resolved_weapon)

	var current_weapon := _get_equipped_weapon()
	if current_weapon != null and current_weapon.weapon_id == resolved_weapon.weapon_id:
		if show_message:
			message_requested.emit("%s ready" % resolved_weapon.display_name)
		return false

	equipped_weapon = resolved_weapon
	if show_message:
		message_requested.emit("Equipped %s" % resolved_weapon.display_name)
	return true


func obtain_weapon(weapon: Resource, auto_equip: bool = true, show_message: bool = true) -> bool:
	var resolved_weapon := _resolve_strict_weapon_resource(weapon)
	if resolved_weapon == null:
		if show_message:
			message_requested.emit("Invalid weapon")
		return false

	var already_owned := _has_obtained_weapon_id(resolved_weapon.weapon_id)
	if not already_owned:
		_obtained_weapons.append(resolved_weapon)

	if auto_equip:
		var equipped := equip_weapon(resolved_weapon, false)
		if show_message:
			if not already_owned:
				message_requested.emit("Found %s" % resolved_weapon.display_name)
			elif equipped:
				message_requested.emit("Switched to %s" % resolved_weapon.display_name)
			else:
				message_requested.emit("%s ready" % resolved_weapon.display_name)
		return equipped or not already_owned

	if show_message and not already_owned:
		message_requested.emit("Found %s" % resolved_weapon.display_name)
	return not already_owned


func _handle_movement() -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_vector * move_speed

	if input_vector.is_zero_approx():
		return

	facing_direction = input_vector.normalized()
	_update_facing_visuals()


func _attempt_attack() -> void:
	if attack_cooldown_remaining > 0.0 or _attack_windup_pending:
		return

	var weapon: Resource = _get_equipped_weapon()
	if weapon == null:
		return

	var hit_targets := _get_attack_targets()

	if hit_targets.is_empty():
		_start_attack_sequence(weapon, true)
		return

	if current_energy < weapon.energy_cost:
		message_requested.emit("Too tired")
		return

	if not spend_energy(weapon.energy_cost):
		message_requested.emit("Too tired")
		return
	_start_attack_sequence(weapon, false)


func _play_attack_flash() -> void:
	attack_flash.visible = true
	attack_flash.scale = _attack_flash_start_scale
	attack_flash.modulate = Color(_attack_flash_color.r, _attack_flash_color.g, _attack_flash_color.b, 1.0)
	var tween := create_tween()
	tween.parallel().tween_property(attack_flash, "scale", _attack_flash_peak_scale, _attack_flash_duration)
	tween.parallel().tween_property(attack_flash, "modulate:a", 0.0, _attack_flash_duration)
	tween.finished.connect(func() -> void:
		attack_flash.visible = false
		attack_flash.scale = Vector2.ONE
		attack_flash.modulate = Color(_attack_flash_color.r, _attack_flash_color.g, _attack_flash_color.b, 1.0)
	)
	_show_attack_indicator_strike()


func _attempt_use_medicine() -> void:
	var medicine_count: int = int(resources.get("medicine", 0))
	if medicine_count <= 0:
		message_requested.emit("No medicine")
		return

	if current_health >= max_health:
		message_requested.emit("Health full")
		return

	if not spend_resource("medicine", 1):
		message_requested.emit("No medicine")
		return

	heal(medicine_heal_amount)
	message_requested.emit("Used medicine")
	_update_interaction_prompt()


func _attempt_switch_weapon() -> void:
	if is_dead or is_busy or _attack_windup_pending:
		return

	var current_weapon := _get_equipped_weapon()
	if current_weapon == null:
		return

	if attack_cooldown_remaining > 0.0:
		return

	if _obtained_weapons.size() <= 1:
		message_requested.emit("Only %s available" % current_weapon.display_name)
		return

	var current_index := _get_obtained_weapon_index(current_weapon.weapon_id)
	if current_index < 0:
		current_index = 0

	var next_index := (current_index + 1) % _obtained_weapons.size()
	equip_weapon(_obtained_weapons[next_index], true)


func _attempt_interact() -> void:
	var interactable := _get_active_interactable()
	if interactable == null:
		return

	if interactable.has_method("interact"):
		interactable.interact(self)


func _die() -> void:
	is_dead = true
	cancel_timed_action()
	_cancel_attack_windup()
	velocity = Vector2.ZERO
	message_requested.emit("You died")
	player_died.emit()
	_update_interaction_prompt()


func reset_for_new_run() -> void:
	is_dead = false
	cancel_timed_action()
	current_health = max_health
	current_energy = max_energy
	resources = {
		"salvage": 0,
		"parts": 0,
		"medicine": 0,
	}
	_cancel_attack_windup()
	attack_cooldown_remaining = 0.0
	_knockback_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	_nearby_interactables.clear()
	_obtained_weapons.clear()
	if _starting_weapon != null:
		_obtained_weapons.append(_starting_weapon)
		equipped_weapon = _starting_weapon
	global_position = _spawn_position
	_emit_full_state()
	_update_interaction_prompt()
	_update_render_order()


func _emit_full_state() -> void:
	health_changed.emit(current_health, max_health)
	energy_changed.emit(current_energy, max_energy)
	resources_changed.emit(resources.duplicate(true))


func _flash_body(flash_color: Color) -> void:
	body_visual.color = flash_color
	var tween := create_tween()
	tween.tween_property(body_visual, "color", _base_body_color, 0.12)


func _play_damage_feedback(source: Variant) -> void:
	if _damage_feedback_tween != null and is_instance_valid(_damage_feedback_tween):
		_damage_feedback_tween.kill()

	var knock_direction := _get_damage_knock_direction(source)
	body_visual.position = knock_direction * 5.0
	body_visual.scale = Vector2(1.08, 0.92)
	facing_marker.position = knock_direction * 5.0
	facing_marker.scale = Vector2(1.08, 0.92)

	_damage_feedback_tween = create_tween()
	_damage_feedback_tween.parallel().tween_property(body_visual, "position", Vector2.ZERO, 0.12)
	_damage_feedback_tween.parallel().tween_property(body_visual, "scale", Vector2.ONE, 0.12)
	_damage_feedback_tween.parallel().tween_property(facing_marker, "position", Vector2.ZERO, 0.12)
	_damage_feedback_tween.parallel().tween_property(facing_marker, "scale", Vector2.ONE, 0.12)


func _get_damage_knock_direction(source: Variant) -> Vector2:
	var attacker_position := global_position
	if source is Dictionary:
		var attacker = source.get("attacker")
		if attacker != null and is_instance_valid(attacker) and attacker is Node2D:
			attacker_position = attacker.global_position
	elif source != null and is_instance_valid(source) and source is Node2D:
		attacker_position = source.global_position

	var knock_direction := global_position - attacker_position
	if knock_direction.is_zero_approx():
		return Vector2(0.0, 1.0)
	return knock_direction.normalized()


func _apply_knockback_from_source(source: Variant) -> void:
	if not (source is Dictionary):
		return

	var base_force := float(source.get("knockback_force", 0.0))
	if base_force <= 0.0:
		return

	var knockback_direction := Vector2.ZERO
	var source_direction = source.get("knockback_direction", Vector2.ZERO)
	if source_direction is Vector2 and not (source_direction as Vector2).is_zero_approx():
		knockback_direction = (source_direction as Vector2).normalized()
	else:
		knockback_direction = _get_damage_knock_direction(source)

	if knockback_direction.is_zero_approx():
		return

	_knockback_velocity = knockback_direction * base_force


func _decay_knockback(delta: float) -> void:
	if _knockback_velocity.is_zero_approx():
		_knockback_velocity = Vector2.ZERO
		return

	var decayed_speed := move_toward(_knockback_velocity.length(), 0.0, knockback_decay * delta)
	if decayed_speed <= 0.01:
		_knockback_velocity = Vector2.ZERO
		return

	_knockback_velocity = _knockback_velocity.normalized() * decayed_speed


func _on_pickup_detector_area_entered(area: Area2D) -> void:
	if area.has_method("collect"):
		area.collect(self)


func _on_interaction_detector_area_entered(area: Area2D) -> void:
	_register_interactable(area)


func _on_interaction_detector_area_exited(area: Area2D) -> void:
	_unregister_interactable(area)


func _on_interaction_detector_body_entered(body: Node2D) -> void:
	_register_interactable(body)


func _on_interaction_detector_body_exited(body: Node2D) -> void:
	_unregister_interactable(body)


func _on_action_timer_timeout() -> void:
	is_busy = false
	var callback := _action_complete_callback
	_action_complete_callback = Callable()
	_busy_label = ""
	if callback.is_valid() and not is_dead:
		callback.call()
	_update_interaction_prompt()


func _on_attack_windup_timer_timeout() -> void:
	if is_dead:
		_cancel_attack_windup()
		return

	_attack_windup_pending = false
	if _attack_windup_visual_only:
		var windup_weapon := _attack_windup_weapon
		_attack_windup_weapon = null
		_attack_windup_visual_only = false
		_play_attack_flash()
		_flash_body(Color(1.0, 0.82, 0.54, 1.0))
		_apply_miss_recovery(windup_weapon)
		return

	_commit_attack(_attack_windup_weapon)


func _get_active_interactable() -> Node2D:
	var best_interactable: Node2D = null
	var best_priority := -INF
	var best_distance := INF

	for interactable in _nearby_interactables:
		if not is_instance_valid(interactable):
			continue

		if _interaction_gate_callback.is_valid() and not _interaction_gate_callback.call(interactable):
			continue

		if interactable.has_method("can_interact") and not interactable.can_interact(self):
			continue

		var priority := 0.0
		if interactable.has_method("get_interaction_priority"):
			priority = float(interactable.get_interaction_priority(self))

		var distance := global_position.distance_squared_to(interactable.global_position)
		if priority > best_priority or (is_equal_approx(priority, best_priority) and distance < best_distance):
			best_priority = priority
			best_distance = distance
			best_interactable = interactable

	return best_interactable


func _update_interaction_prompt() -> void:
	if is_dead:
		interaction_prompt_changed.emit("")
		return

	if is_busy:
		interaction_prompt_changed.emit(_busy_label)
		return

	var interactable := _get_active_interactable()
	if interactable != null and interactable.has_method("get_interaction_label"):
		interaction_prompt_changed.emit(str(interactable.get_interaction_label(self)))
		return

	interaction_prompt_changed.emit("")


func _register_interactable(interactable: Node2D) -> void:
	if interactable == null or not interactable.has_method("get_interaction_label"):
		return

	if interactable.has_method("is_direct_interactable") and not interactable.is_direct_interactable():
		return
	
	if _nearby_interactables.has(interactable):
		return

	_nearby_interactables.append(interactable)
	_update_interaction_prompt()


func _unregister_interactable(interactable: Node2D) -> void:
	_nearby_interactables.erase(interactable)
	_update_interaction_prompt()


func _update_render_order() -> void:
	z_index = int(round(global_position.y))


func _update_facing_visuals() -> void:
	attack_pivot.rotation = facing_direction.angle() + PI / 2.0
	facing_marker.rotation = attack_pivot.rotation


func _get_equipped_weapon() -> Resource:
	if _is_valid_weapon_resource(equipped_weapon):
		_invalid_weapon_warning_emitted = false
		return equipped_weapon
	if _is_valid_weapon_resource(DEFAULT_WEAPON_RESOURCE):
		if not _invalid_weapon_warning_emitted:
			push_warning("Player equipped_weapon is invalid; falling back to kitchen_knife.")
			_invalid_weapon_warning_emitted = true
		return DEFAULT_WEAPON_RESOURCE
	return null


func _resolve_valid_weapon_resource(resource: Resource) -> Resource:
	if _is_valid_weapon_resource(resource):
		return resource
	if _is_valid_weapon_resource(DEFAULT_WEAPON_RESOURCE):
		return DEFAULT_WEAPON_RESOURCE
	return null


func _resolve_strict_weapon_resource(resource: Resource) -> Resource:
	if _is_valid_weapon_resource(resource):
		return resource
	return null


func _has_obtained_weapon_id(weapon_id: StringName) -> bool:
	return _get_obtained_weapon_index(weapon_id) >= 0


func _get_obtained_weapon_index(weapon_id: StringName) -> int:
	for index in _obtained_weapons.size():
		var weapon: Resource = _obtained_weapons[index]
		if weapon != null and weapon.weapon_id == weapon_id:
			return index
	return -1


func _apply_equipped_weapon() -> void:
	var weapon: Resource = _get_equipped_weapon()
	if weapon == null:
		return

	weapon_visual.position = weapon.held_visual_offset if weapon.held_visual_polygon.size() >= 3 else DEFAULT_HELD_WEAPON_OFFSET
	weapon_visual.polygon = weapon.held_visual_polygon if weapon.held_visual_polygon.size() >= 3 else _get_default_held_weapon_polygon()
	weapon_visual.color = weapon.held_visual_color if weapon.held_visual_polygon.size() >= 3 else DEFAULT_HELD_WEAPON_COLOR
	attack_area.position = weapon.attack_area_offset
	attack_indicator.position = weapon.attack_area_offset
	if attack_area_shape.shape is RectangleShape2D:
		var shape := attack_area_shape.shape as RectangleShape2D
		shape.size = weapon.attack_area_size
		attack_indicator.polygon = PackedVector2Array([
			Vector2(-weapon.attack_area_size.x * 0.5, -weapon.attack_area_size.y * 0.5),
			Vector2(weapon.attack_area_size.x * 0.5, -weapon.attack_area_size.y * 0.5),
			Vector2(weapon.attack_area_size.x * 0.5, weapon.attack_area_size.y * 0.5),
			Vector2(-weapon.attack_area_size.x * 0.5, weapon.attack_area_size.y * 0.5)
		])
	_attack_flash_color = weapon.attack_flash_color
	_attack_flash_start_scale = weapon.attack_flash_start_scale
	_attack_indicator_windup_color = weapon.attack_indicator_windup_color
	_attack_indicator_strike_color = weapon.attack_indicator_strike_color
	_attack_indicator_windup_start_scale = weapon.attack_indicator_windup_start_scale
	_attack_indicator_strike_peak_scale = weapon.attack_indicator_strike_peak_scale
	_attack_indicator_lead_time = min(weapon.attack_indicator_lead_time, weapon.attack_windup)
	_attack_indicator_windup_start_alpha = weapon.attack_indicator_windup_start_alpha
	_attack_indicator_windup_end_alpha = weapon.attack_indicator_windup_end_alpha
	_attack_indicator_strike_alpha = weapon.attack_indicator_strike_alpha
	_attack_indicator_strike_fade_duration = weapon.attack_indicator_strike_fade_duration
	attack_indicator.color = weapon.attack_indicator_windup_color
	attack_indicator.modulate = Color(1.0, 1.0, 1.0, 1.0)
	attack_indicator.scale = Vector2.ONE
	attack_flash.color = weapon.attack_flash_color
	attack_flash.modulate = Color(weapon.attack_flash_color.r, weapon.attack_flash_color.g, weapon.attack_flash_color.b, 1.0)
	_attack_flash_peak_scale = weapon.attack_flash_peak_scale
	_attack_flash_duration = weapon.attack_flash_duration


func _get_attack_targets() -> Array:
	var hit_targets: Array = []
	for body in attack_area.get_overlapping_bodies():
		if body == self:
			continue
		if not body.is_in_group("enemies"):
			continue
		if not body.has_method("take_damage"):
			continue
		hit_targets.append(body)
	return hit_targets


func _commit_attack(weapon_override: Resource = null) -> void:
	var weapon: Resource = weapon_override
	if weapon == null:
		weapon = _get_equipped_weapon()
	if weapon == null:
		return

	var hit_targets := _get_attack_targets()
	if hit_targets.is_empty():
		_play_attack_flash()
		_flash_body(Color(1.0, 0.82, 0.54, 1.0))
		if _attack_windup_weapon != null:
			restore_energy(int(weapon.energy_cost))
		_apply_miss_recovery(weapon)
		attack_windup_timer.stop()
		_attack_windup_pending = false
		_attack_windup_weapon = null
		_attack_windup_visual_only = false
		return

	_play_attack_flash()
	attack_cooldown_remaining = weapon.attack_cooldown
	_flash_body(Color(1.0, 0.82, 0.54, 1.0))

	for body in hit_targets:
		if is_instance_valid(body):
			body.take_damage(weapon.damage, {
				"attacker": self,
				"damage_type": weapon.damage_type,
				"knockback_force": weapon.knockback_force,
				"knockback_direction": facing_direction,
			})
	_attack_windup_weapon = null
	_attack_windup_visual_only = false


func _cancel_attack_windup() -> void:
	attack_windup_timer.stop()
	_attack_windup_pending = false
	_attack_windup_weapon = null
	_attack_windup_visual_only = false
	_hide_attack_indicator()


func _show_attack_indicator_windup(duration: float) -> void:
	_stop_attack_indicator_tween()
	attack_indicator.color = _attack_indicator_windup_color
	attack_indicator.scale = _attack_indicator_windup_start_scale
	attack_indicator.modulate = Color(1.0, 1.0, 1.0, _attack_indicator_windup_start_alpha)
	attack_indicator.visible = false
	if duration <= 0.0:
		return
	var tell_duration: float = min(_attack_indicator_lead_time, duration)
	if tell_duration <= 0.0:
		return
	var tell_delay: float = max(duration - tell_duration, 0.0)
	_attack_indicator_tween = create_tween()
	if tell_delay > 0.0:
		_attack_indicator_tween.tween_interval(tell_delay)
	_attack_indicator_tween.tween_callback(func() -> void:
		attack_indicator.visible = true
		attack_indicator.color = _attack_indicator_windup_color
		attack_indicator.scale = _attack_indicator_windup_start_scale
		attack_indicator.modulate = Color(1.0, 1.0, 1.0, _attack_indicator_windup_start_alpha)
	)
	_attack_indicator_tween.parallel().tween_property(attack_indicator, "scale", Vector2.ONE, max(tell_duration, 0.05))
	_attack_indicator_tween.parallel().tween_property(attack_indicator, "modulate:a", _attack_indicator_windup_end_alpha, max(tell_duration, 0.05))


func _show_attack_indicator_strike() -> void:
	_stop_attack_indicator_tween()
	attack_indicator.visible = true
	attack_indicator.color = _attack_indicator_strike_color
	attack_indicator.scale = _attack_indicator_strike_peak_scale
	attack_indicator.modulate = Color(1.0, 1.0, 1.0, _attack_indicator_strike_alpha)
	_attack_indicator_tween = create_tween()
	_attack_indicator_tween.parallel().tween_property(attack_indicator, "scale", Vector2.ONE, _attack_indicator_strike_fade_duration)
	_attack_indicator_tween.parallel().tween_property(attack_indicator, "modulate:a", 0.0, _attack_indicator_strike_fade_duration)
	_attack_indicator_tween.finished.connect(func() -> void:
		_hide_attack_indicator()
	)


func _hide_attack_indicator() -> void:
	_stop_attack_indicator_tween()
	attack_indicator.visible = false
	attack_indicator.color = _attack_indicator_windup_color
	attack_indicator.scale = Vector2.ONE
	attack_indicator.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _stop_attack_indicator_tween() -> void:
	if _attack_indicator_tween != null and is_instance_valid(_attack_indicator_tween):
		_attack_indicator_tween.kill()
	_attack_indicator_tween = null


func _is_valid_weapon_resource(resource: Resource) -> bool:
	if resource == null:
		return false
	if resource.get_script() != WEAPON_DEFINITION_SCRIPT and not resource.is_class("WeaponDefinition"):
		return false
	if not resource.has_method("is_valid_definition"):
		return false
	return resource.is_valid_definition()


func _get_default_held_weapon_polygon() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-2, -10),
		Vector2(2, -10),
		Vector2(2, 8),
		Vector2(-2, 8),
	])


func _apply_miss_recovery(weapon: Resource) -> void:
	if weapon == null:
		return
	attack_cooldown_remaining = max(attack_cooldown_remaining, float(weapon.miss_recovery_time))


func _start_attack_sequence(weapon: Resource, visual_only: bool) -> void:
	if weapon.attack_windup <= 0.0:
		if visual_only:
			_play_attack_flash()
			_flash_body(Color(1.0, 0.82, 0.54, 1.0))
			_apply_miss_recovery(weapon)
			return
		_commit_attack(weapon)
		return

	_attack_windup_pending = true
	_attack_windup_weapon = weapon
	_attack_windup_visual_only = visual_only
	_show_attack_indicator_windup(weapon.attack_windup)
	attack_windup_timer.start(weapon.attack_windup)
