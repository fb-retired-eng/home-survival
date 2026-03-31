extends CharacterBody2D
class_name Player

const RESOURCE_IDS := ["salvage", "parts", "medicine", "bullets", "food"]
const DEFAULT_ATTACK_FLASH_COLOR := Color(1.0, 0.83, 0.42, 0.75)
const DEFAULT_ATTACK_FLASH_START_SCALE := Vector2(0.8, 0.8)
const DEFAULT_ATTACK_FLASH_PEAK_SCALE := Vector2(1.1, 1.1)
const DEFAULT_ATTACK_FLASH_DURATION := 0.08
const DEFAULT_MUZZLE_FLASH_COLOR := Color(1.0, 0.87, 0.55, 0.95)
const DEFAULT_MUZZLE_FLASH_SCALE := Vector2(1.0, 1.0)
const DEFAULT_MUZZLE_FLASH_DURATION := 0.05
const DEFAULT_TRACER_COLOR := Color(1.0, 0.95, 0.78, 0.9)
const DEFAULT_TRACER_WIDTH := 2.0
const DEFAULT_TRACER_DURATION := 0.05
const DEFAULT_ATTACK_INDICATOR_WINDUP_COLOR := Color(1.0, 0.9, 0.62, 0.22)
const DEFAULT_ATTACK_INDICATOR_STRIKE_COLOR := Color(1.0, 0.98, 0.88, 0.9)
const DEFAULT_ATTACK_INDICATOR_WINDUP_START_SCALE := Vector2(0.82, 0.82)
const DEFAULT_ATTACK_INDICATOR_STRIKE_PEAK_SCALE := Vector2(1.05, 1.05)
const DEFAULT_HELD_WEAPON_OFFSET := Vector2(10.0, -10.0)
const DEFAULT_HELD_WEAPON_COLOR := Color(0.86, 0.86, 0.9, 1.0)
const DEFAULT_SPREAD_HITSCAN_CONE_DEGREES := 30.0
const WEAPON_DEFINITION_SCRIPT := preload("res://scripts/data/weapon_definition.gd")
const DEFAULT_WEAPON_RESOURCE := preload("res://data/weapons/kitchen_knife.tres")

signal health_changed(current: int, maximum: int)
signal energy_changed(current: int, maximum: int)
signal resources_changed(resources: Dictionary)
signal message_requested(text: String)
signal player_died()
signal interaction_prompt_changed(text: String)
signal weapon_changed(display_name: String, weapon_id: StringName)
signal weapon_status_changed(text: String)

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
	"bullets": 0,
	"food": 0,
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
var _muzzle_flash_color: Color = DEFAULT_MUZZLE_FLASH_COLOR
var _muzzle_flash_scale: Vector2 = DEFAULT_MUZZLE_FLASH_SCALE
var _muzzle_flash_duration: float = DEFAULT_MUZZLE_FLASH_DURATION
var _tracer_color: Color = DEFAULT_TRACER_COLOR
var _tracer_width: float = DEFAULT_TRACER_WIDTH
var _tracer_duration: float = DEFAULT_TRACER_DURATION
var _attack_indicator_windup_color: Color = DEFAULT_ATTACK_INDICATOR_WINDUP_COLOR
var _attack_indicator_strike_color: Color = DEFAULT_ATTACK_INDICATOR_STRIKE_COLOR
var _attack_indicator_windup_start_scale: Vector2 = DEFAULT_ATTACK_INDICATOR_WINDUP_START_SCALE
var _attack_indicator_strike_peak_scale: Vector2 = DEFAULT_ATTACK_INDICATOR_STRIKE_PEAK_SCALE
var _attack_indicator_lead_time: float = 0.12
var _attack_indicator_windup_start_alpha: float = 0.45
var _attack_indicator_windup_end_alpha: float = 1.0
var _attack_indicator_strike_alpha: float = 0.95
var _attack_indicator_strike_fade_duration: float = 0.10
var _impact_hit_color: Color = Color(1.0, 0.84, 0.54, 0.95)
var _impact_block_color: Color = Color(0.95, 0.94, 0.88, 0.88)
var _impact_flash_scale: float = 1.0
var _impact_flash_duration: float = 0.07
var _attack_indicator_tween: Tween
var _invalid_weapon_warning_emitted: bool = false
var _damage_feedback_tween: Tween
var _starting_weapon: Resource
var _knockback_velocity: Vector2 = Vector2.ZERO
var _obtained_weapons: Array[Resource] = []
var _magazine_ammo_by_weapon_id: Dictionary = {}
var _reload_time_remaining: float = 0.0
var _reload_weapon_id: StringName = StringName()
var _shot_impact_tween: Tween

@onready var body_visual: Polygon2D = $Body
@onready var facing_marker: Polygon2D = $FacingMarker
@onready var attack_pivot: Node2D = $AttackPivot
@onready var weapon_visual: Polygon2D = $AttackPivot/WeaponVisual
@onready var attack_area: Area2D = $AttackPivot/AttackArea
@onready var attack_area_shape: CollisionShape2D = $AttackPivot/AttackArea/CollisionShape2D
@onready var attack_indicator: Polygon2D = $AttackPivot/AttackIndicator
@onready var attack_flash: Polygon2D = $AttackPivot/AttackFlash
@onready var muzzle_flash: Polygon2D = $AttackPivot/MuzzleFlash
@onready var shot_tracer: Line2D = $ShotTracer
@onready var shot_impact: Polygon2D = $ShotImpact
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
	_update_reload(delta)
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

	if Input.is_action_just_pressed("reload_weapon"):
		_attempt_reload(false)


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
	_ensure_weapon_runtime_state(resolved_weapon)

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
	_ensure_weapon_runtime_state(resolved_weapon)

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
	if attack_cooldown_remaining > 0.0 or _attack_windup_pending or _is_reloading_weapon():
		return

	var weapon: Resource = _get_equipped_weapon()
	if weapon == null:
		return

	if _uses_weapon_magazine(weapon):
		if _get_weapon_magazine_ammo(weapon) <= 0:
			if _get_bullet_reserve_amount() <= 0:
				message_requested.emit("Out of bullets")
			else:
				_attempt_reload(true)
			return

		if current_energy < weapon.energy_cost:
			message_requested.emit("Too tired")
			return

		if not spend_energy(weapon.energy_cost):
			message_requested.emit("Too tired")
			return
		_start_attack_sequence(weapon, false)
		return

	var hit_targets := _get_attack_targets_for_weapon(weapon)

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


func _play_hitscan_effect(end_point: Vector2, impact_kind: String) -> void:
	_show_attack_indicator_strike()
	_play_muzzle_flash()
	_play_shot_tracer(end_point)
	_play_shot_impact(end_point, impact_kind)


func _play_muzzle_flash() -> void:
	muzzle_flash.visible = true
	muzzle_flash.position = _get_muzzle_local_position()
	muzzle_flash.scale = _muzzle_flash_scale * 0.72
	muzzle_flash.modulate = Color(_muzzle_flash_color.r, _muzzle_flash_color.g, _muzzle_flash_color.b, 1.0)
	var tween := create_tween()
	tween.parallel().tween_property(muzzle_flash, "scale", _muzzle_flash_scale, _muzzle_flash_duration)
	tween.parallel().tween_property(muzzle_flash, "modulate:a", 0.0, _muzzle_flash_duration)
	tween.finished.connect(func() -> void:
		muzzle_flash.visible = false
		muzzle_flash.scale = Vector2.ONE
		muzzle_flash.modulate = Color(_muzzle_flash_color.r, _muzzle_flash_color.g, _muzzle_flash_color.b, 1.0)
	)


func _play_shot_tracer(end_point: Vector2) -> void:
	var muzzle_global := attack_pivot.to_global(_get_muzzle_local_position())
	shot_tracer.visible = true
	shot_tracer.width = _tracer_width
	shot_tracer.default_color = _tracer_color
	shot_tracer.points = PackedVector2Array([
		to_local(muzzle_global),
		to_local(end_point),
	])
	shot_tracer.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var tween := create_tween()
	tween.tween_property(shot_tracer, "modulate:a", 0.0, _tracer_duration)
	tween.finished.connect(func() -> void:
		shot_tracer.visible = false
		shot_tracer.points = PackedVector2Array()
		shot_tracer.modulate = Color(1.0, 1.0, 1.0, 1.0)
	)


func _play_shot_impact(end_point: Vector2, impact_kind: String) -> void:
	if shot_impact == null:
		return
	if _shot_impact_tween != null and is_instance_valid(_shot_impact_tween):
		_shot_impact_tween.kill()

	var impact_color := _impact_hit_color if impact_kind == "enemy" else _impact_block_color
	shot_impact.position = to_local(end_point)
	shot_impact.visible = true
	shot_impact.scale = Vector2.ONE * (_impact_flash_scale * 0.7)
	shot_impact.color = impact_color
	shot_impact.modulate = Color(impact_color.r, impact_color.g, impact_color.b, 1.0)

	_shot_impact_tween = create_tween()
	_shot_impact_tween.parallel().tween_property(shot_impact, "scale", Vector2.ONE * _impact_flash_scale, _impact_flash_duration)
	_shot_impact_tween.parallel().tween_property(shot_impact, "modulate:a", 0.0, _impact_flash_duration)
	_shot_impact_tween.finished.connect(func() -> void:
		shot_impact.visible = false
		shot_impact.scale = Vector2.ONE
		shot_impact.modulate = Color(1.0, 1.0, 1.0, 1.0)
	)


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


func _attempt_reload(auto_triggered: bool) -> void:
	var weapon: Resource = _get_equipped_weapon()
	_begin_reload(weapon, auto_triggered)


func _attempt_switch_weapon() -> void:
	if is_dead or is_busy or _attack_windup_pending:
		return
	var was_reloading := _is_reloading_weapon()
	if _is_reloading_weapon():
		_cancel_reload()

	var current_weapon := _get_equipped_weapon()
	if current_weapon == null:
		return

	if attack_cooldown_remaining > 0.0 and not was_reloading:
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
		"bullets": 0,
		"food": 0,
	}
	_cancel_attack_windup()
	attack_cooldown_remaining = 0.0
	_reload_time_remaining = 0.0
	_reload_weapon_id = StringName()
	_knockback_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	_nearby_interactables.clear()
	_obtained_weapons.clear()
	_magazine_ammo_by_weapon_id.clear()
	if _starting_weapon != null:
		_obtained_weapons.append(_starting_weapon)
		_ensure_weapon_runtime_state(_starting_weapon)
		equipped_weapon = _starting_weapon
	global_position = _spawn_position
	_emit_full_state()
	_update_interaction_prompt()
	_update_render_order()


func _emit_full_state() -> void:
	health_changed.emit(current_health, max_health)
	energy_changed.emit(current_energy, max_energy)
	resources_changed.emit(resources.duplicate(true))
	_emit_weapon_state()


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
		var attack_result := _get_visual_only_attack_result_for_weapon(windup_weapon)
		_attack_windup_weapon = null
		_attack_windup_visual_only = false
		_play_attack_effect(windup_weapon, attack_result)
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


func get_equipped_weapon_display_name() -> String:
	var weapon: Resource = _get_equipped_weapon()
	if weapon == null:
		return ""
	return weapon.display_name


func get_obtained_weapon_ids() -> PackedStringArray:
	var weapon_ids := PackedStringArray()
	for weapon in _obtained_weapons:
		if weapon == null:
			continue
		weapon_ids.append(String(weapon.weapon_id))
	return weapon_ids


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
	_ensure_weapon_runtime_state(weapon)

	var applied_attack_area_position: Vector2 = weapon.attack_area_offset
	var applied_attack_area_size: Vector2 = weapon.attack_area_size
	if weapon.attack_mode == "hitscan":
		applied_attack_area_position = Vector2(weapon.attack_area_offset.x, -weapon.attack_range * 0.5)
		applied_attack_area_size = Vector2(weapon.attack_area_size.x, weapon.attack_range)
	elif weapon.attack_mode == "spread_hitscan":
		var half_angle_radians := deg_to_rad(maxf(weapon.attack_cone_degrees, DEFAULT_SPREAD_HITSCAN_CONE_DEGREES) * 0.5)
		var derived_width := maxf(tan(half_angle_radians) * weapon.attack_range * 2.0, weapon.attack_area_size.x)
		applied_attack_area_position = Vector2(weapon.attack_area_offset.x, -weapon.attack_range * 0.5)
		applied_attack_area_size = Vector2(derived_width, weapon.attack_range)

	weapon_visual.position = weapon.held_visual_offset if weapon.held_visual_polygon.size() >= 3 else DEFAULT_HELD_WEAPON_OFFSET
	weapon_visual.polygon = weapon.held_visual_polygon if weapon.held_visual_polygon.size() >= 3 else _get_default_held_weapon_polygon()
	weapon_visual.color = weapon.held_visual_color if weapon.held_visual_polygon.size() >= 3 else DEFAULT_HELD_WEAPON_COLOR
	attack_area.position = applied_attack_area_position
	attack_indicator.position = applied_attack_area_position
	if attack_area_shape.shape is RectangleShape2D:
		var shape := attack_area_shape.shape as RectangleShape2D
		shape.size = applied_attack_area_size
		attack_indicator.polygon = PackedVector2Array([
			Vector2(-applied_attack_area_size.x * 0.5, -applied_attack_area_size.y * 0.5),
			Vector2(applied_attack_area_size.x * 0.5, -applied_attack_area_size.y * 0.5),
			Vector2(applied_attack_area_size.x * 0.5, applied_attack_area_size.y * 0.5),
			Vector2(-applied_attack_area_size.x * 0.5, applied_attack_area_size.y * 0.5)
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
	_muzzle_flash_color = weapon.muzzle_flash_color
	_muzzle_flash_scale = weapon.muzzle_flash_scale
	_muzzle_flash_duration = weapon.muzzle_flash_duration
	_tracer_color = weapon.tracer_color
	_tracer_width = weapon.tracer_width
	_tracer_duration = weapon.tracer_duration
	_impact_hit_color = weapon.impact_hit_color
	_impact_block_color = weapon.impact_block_color
	_impact_flash_scale = weapon.impact_flash_scale
	_impact_flash_duration = weapon.impact_flash_duration
	muzzle_flash.color = weapon.muzzle_flash_color
	muzzle_flash.modulate = Color(weapon.muzzle_flash_color.r, weapon.muzzle_flash_color.g, weapon.muzzle_flash_color.b, 1.0)
	shot_tracer.default_color = weapon.tracer_color
	shot_tracer.width = weapon.tracer_width
	_emit_weapon_state()


func _get_attack_result_for_weapon(weapon: Resource) -> Dictionary:
	if weapon == null:
		return {
			"targets": [],
			"end_point": global_position,
			"impact_kind": "none",
		}

	if weapon.attack_mode == "hitscan":
		return _get_hitscan_attack_result(weapon)
	if weapon.attack_mode == "spread_hitscan":
		return _get_spread_hitscan_attack_result(weapon)
	return {
		"targets": _get_melee_attack_targets(),
		"end_point": attack_pivot.to_global(weapon.attack_area_offset),
		"impact_kind": "enemy",
	}


func _get_visual_only_attack_result_for_weapon(weapon: Resource) -> Dictionary:
	if weapon == null:
		return {
			"targets": [],
			"end_point": global_position,
			"impact_kind": "none",
		}

	if weapon.attack_mode == "hitscan" or weapon.attack_mode == "spread_hitscan":
		var ray_start := attack_pivot.to_global(_get_muzzle_local_position())
		return {
			"targets": [],
			"end_point": ray_start + facing_direction * float(weapon.attack_range),
			"impact_kind": "miss",
		}

	return {
		"targets": [],
		"end_point": attack_pivot.to_global(weapon.attack_area_offset),
		"impact_kind": "miss",
	}


func _get_attack_targets_for_weapon(weapon: Resource) -> Array:
	return Array(_get_attack_result_for_weapon(weapon).get("targets", []))


func _get_melee_attack_targets() -> Array:
	return _get_enemy_targets_in_attack_shape()


func _get_enemy_targets_in_attack_shape() -> Array:
	var hit_targets: Array = []
	if attack_area_shape == null or attack_area_shape.shape == null:
		return hit_targets

	var shape_query := PhysicsShapeQueryParameters2D.new()
	shape_query.shape = attack_area_shape.shape
	shape_query.transform = attack_area.global_transform
	shape_query.collision_mask = attack_area.collision_mask
	shape_query.exclude = [self]

	for result in get_world_2d().direct_space_state.intersect_shape(shape_query):
		var body = result.get("collider")
		if body == null or body == self:
			continue
		if not body.is_in_group("enemies"):
			continue
		if not body.has_method("take_damage"):
			continue
		hit_targets.append(body)
	return hit_targets


func _get_hitscan_attack_result(weapon: Resource) -> Dictionary:
	var candidates := _get_enemy_targets_in_attack_shape()

	var direct_space_state := get_world_2d().direct_space_state
	var ray_start := attack_pivot.to_global(_get_muzzle_local_position())
	var max_end := ray_start + facing_direction * float(weapon.attack_range)
	var miss_query := PhysicsRayQueryParameters2D.create(ray_start, max_end)
	miss_query.exclude = [self]
	var miss_hit := direct_space_state.intersect_ray(miss_query)
	var end_point: Vector2 = max_end
	var impact_kind := "miss"
	if not miss_hit.is_empty():
		end_point = miss_hit.get("position", max_end)
		var miss_collider = miss_hit.get("collider")
		if miss_collider != null and miss_collider.is_in_group("defense_sockets"):
			impact_kind = "structure"

	if candidates.is_empty():
		return {
			"targets": [],
			"end_point": end_point,
			"impact_kind": impact_kind,
		}

	candidates.sort_custom(func(a, b):
		return ray_start.distance_squared_to(a.global_position) < ray_start.distance_squared_to(b.global_position)
	)

	for candidate in candidates:
		if ray_start.distance_to(candidate.global_position) > float(weapon.attack_range):
			continue
		var ray_query := PhysicsRayQueryParameters2D.create(ray_start, candidate.global_position)
		ray_query.exclude = [self]
		var hit := direct_space_state.intersect_ray(ray_query)
		if hit.is_empty():
			continue
		if hit.get("collider") == candidate:
			return {
				"targets": [candidate],
				"end_point": hit.get("position", candidate.global_position),
				"impact_kind": "enemy",
			}

	return {
		"targets": [],
		"end_point": end_point,
		"impact_kind": impact_kind,
	}


func _get_spread_hitscan_attack_result(weapon: Resource) -> Dictionary:
	var candidates := _get_enemy_targets_in_attack_shape()

	var direct_space_state := get_world_2d().direct_space_state
	var ray_start := attack_pivot.to_global(_get_muzzle_local_position())
	var max_end := ray_start + facing_direction * float(weapon.attack_range)
	var miss_query := PhysicsRayQueryParameters2D.create(ray_start, max_end)
	miss_query.exclude = [self]
	var miss_hit := direct_space_state.intersect_ray(miss_query)
	var end_point: Vector2 = max_end
	var impact_kind := "miss"
	if not miss_hit.is_empty():
		end_point = miss_hit.get("position", max_end)
		var miss_collider = miss_hit.get("collider")
		if miss_collider != null and miss_collider.is_in_group("defense_sockets"):
			impact_kind = "structure"

	if candidates.is_empty():
		return {
			"targets": [],
			"end_point": end_point,
			"impact_kind": impact_kind,
		}

	var max_angle_degrees := maxf(weapon.attack_cone_degrees, DEFAULT_SPREAD_HITSCAN_CONE_DEGREES) * 0.5
	var valid_targets: Array = []
	candidates.sort_custom(func(a, b):
		return ray_start.distance_squared_to(a.global_position) < ray_start.distance_squared_to(b.global_position)
	)

	for candidate in candidates:
		var to_candidate: Vector2 = candidate.global_position - ray_start
		if to_candidate.is_zero_approx():
			continue
		if to_candidate.length() > float(weapon.attack_range):
			continue
		var angle_to_candidate: float = rad_to_deg(absf(facing_direction.angle_to(to_candidate.normalized())))
		if angle_to_candidate > max_angle_degrees:
			continue

		var ray_query := PhysicsRayQueryParameters2D.create(ray_start, candidate.global_position)
		ray_query.exclude = [self]
		var hit := direct_space_state.intersect_ray(ray_query)
		if hit.is_empty():
			continue
		if hit.get("collider") != candidate:
			continue
		valid_targets.append(candidate)
		if valid_targets.size() == 1:
			end_point = hit.get("position", candidate.global_position)
			impact_kind = "enemy"

	return {
		"targets": valid_targets,
		"end_point": end_point,
		"impact_kind": impact_kind,
	}


func _commit_attack(weapon_override: Resource = null) -> void:
	var weapon: Resource = weapon_override
	if weapon == null:
		weapon = _get_equipped_weapon()
	if weapon == null:
		return

	var attack_result := _get_attack_result_for_weapon(weapon)
	var hit_targets: Array = Array(attack_result.get("targets", []))
	var consumes_ammo := _uses_weapon_magazine(weapon)
	if consumes_ammo:
		_consume_weapon_magazine_round(weapon)
	if hit_targets.is_empty():
		_play_attack_effect(weapon, attack_result)
		_flash_body(Color(1.0, 0.82, 0.54, 1.0))
		if consumes_ammo:
			attack_cooldown_remaining = weapon.attack_cooldown
		elif _attack_windup_weapon != null:
			restore_energy(int(weapon.energy_cost))
			_apply_miss_recovery(weapon)
		attack_windup_timer.stop()
		_attack_windup_pending = false
		_attack_windup_weapon = null
		_attack_windup_visual_only = false
		return

	_play_attack_effect(weapon, attack_result)
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


func _get_muzzle_local_position() -> Vector2:
	return weapon_visual.position + Vector2(0.0, -10.0)


func _emit_weapon_state() -> void:
	var weapon: Resource = _get_equipped_weapon()
	if weapon == null:
		weapon_changed.emit("", StringName())
		weapon_status_changed.emit("Weapon: None")
		return
	weapon_changed.emit(weapon.display_name, weapon.weapon_id)
	weapon_status_changed.emit(get_weapon_status_text())


func _apply_miss_recovery(weapon: Resource) -> void:
	if weapon == null:
		return
	attack_cooldown_remaining = max(attack_cooldown_remaining, float(weapon.miss_recovery_time))


func get_weapon_status_text() -> String:
	var weapon: Resource = _get_equipped_weapon()
	if weapon == null:
		return "Weapon: None"
	if not _uses_weapon_magazine(weapon):
		return "Weapon: %s" % weapon.display_name

	var ammo_in_mag := _get_weapon_magazine_ammo(weapon)
	var status := "Weapon: %s %d/%d | ◉%d" % [weapon.display_name, ammo_in_mag, int(weapon.magazine_size), _get_bullet_reserve_amount()]
	if _is_reloading_weapon() and _reload_weapon_id == weapon.weapon_id:
		status += " ↻"
	return status


func _uses_weapon_magazine(weapon: Resource) -> bool:
	return weapon != null and bool(weapon.uses_magazine)


func _begin_reload(weapon: Resource, auto_triggered: bool) -> void:
	if weapon == null or not _uses_weapon_magazine(weapon):
		return
	if is_dead or is_busy or _attack_windup_pending or _is_reloading_weapon():
		return

	var current_ammo := _get_weapon_magazine_ammo(weapon)
	if current_ammo >= int(weapon.magazine_size):
		if not auto_triggered:
			message_requested.emit("Magazine full")
		return
	if _get_bullet_reserve_amount() <= 0:
		message_requested.emit("Out of bullets")
		return

	_reload_weapon_id = weapon.weapon_id
	_reload_time_remaining = float(weapon.reload_time)
	_emit_weapon_state()
	if auto_triggered:
		message_requested.emit("%s empty. Reloading..." % weapon.display_name)
	else:
		message_requested.emit("Reloading %s" % weapon.display_name)


func _ensure_weapon_runtime_state(weapon: Resource) -> void:
	if weapon == null or not _uses_weapon_magazine(weapon):
		return
	if not _magazine_ammo_by_weapon_id.has(weapon.weapon_id):
		_magazine_ammo_by_weapon_id[weapon.weapon_id] = int(weapon.magazine_size)


func _get_weapon_magazine_ammo(weapon: Resource) -> int:
	if weapon == null or not _uses_weapon_magazine(weapon):
		return 0
	_ensure_weapon_runtime_state(weapon)
	return int(_magazine_ammo_by_weapon_id.get(weapon.weapon_id, int(weapon.magazine_size)))


func _set_weapon_magazine_ammo(weapon: Resource, amount: int) -> void:
	if weapon == null or not _uses_weapon_magazine(weapon):
		return
	_magazine_ammo_by_weapon_id[weapon.weapon_id] = clampi(amount, 0, int(weapon.magazine_size))
	_emit_weapon_state()


func _consume_weapon_magazine_round(weapon: Resource) -> void:
	if weapon == null or not _uses_weapon_magazine(weapon):
		return
	var remaining_ammo: int = maxi(_get_weapon_magazine_ammo(weapon) - 1, 0)
	_set_weapon_magazine_ammo(weapon, remaining_ammo)
	if remaining_ammo == 0:
		_begin_reload(weapon, true)


func _is_reloading_weapon() -> bool:
	return _reload_time_remaining > 0.0 and _reload_weapon_id != StringName()


func _cancel_reload() -> void:
	if not _is_reloading_weapon():
		return
	_reload_time_remaining = 0.0
	_reload_weapon_id = StringName()
	_emit_weapon_state()


func _update_reload(delta: float) -> void:
	if not _is_reloading_weapon():
		return
	_reload_time_remaining = max(_reload_time_remaining - delta, 0.0)
	if _reload_time_remaining > 0.0:
		return
	_complete_reload()


func _complete_reload() -> void:
	var reloaded_weapon := _find_obtained_weapon_by_id(_reload_weapon_id)
	_reload_time_remaining = 0.0
	_reload_weapon_id = StringName()
	if reloaded_weapon == null:
		_emit_weapon_state()
		return
	var current_ammo := _get_weapon_magazine_ammo(reloaded_weapon)
	var bullets_needed := maxi(int(reloaded_weapon.magazine_size) - current_ammo, 0)
	var bullets_to_load := mini(bullets_needed, _get_bullet_reserve_amount())
	if bullets_to_load <= 0:
		message_requested.emit("Out of bullets")
		_emit_weapon_state()
		return
	spend_resource("bullets", bullets_to_load)
	_set_weapon_magazine_ammo(reloaded_weapon, current_ammo + bullets_to_load)
	message_requested.emit("%s reloaded" % reloaded_weapon.display_name)


func _find_obtained_weapon_by_id(weapon_id: StringName) -> Resource:
	for weapon in _obtained_weapons:
		if weapon != null and weapon.weapon_id == weapon_id:
			return weapon
	return null


func _get_bullet_reserve_amount() -> int:
	return int(resources.get("bullets", 0))


func _start_attack_sequence(weapon: Resource, visual_only: bool) -> void:
	if weapon.attack_windup <= 0.0:
		if visual_only:
			_play_attack_effect(weapon, _get_visual_only_attack_result_for_weapon(weapon))
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


func _play_attack_effect(weapon: Resource, attack_result: Dictionary) -> void:
	if weapon != null and weapon.attack_mode == "hitscan":
		_play_hitscan_effect(
			attack_result.get("end_point", attack_pivot.global_position),
			String(attack_result.get("impact_kind", "miss"))
		)
		return
	_play_attack_flash()
