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
const STRUCTURE_ATTACK_BLOCKER_MASK := 2 | 4
const GAMEPLAY_Z_BASE := 1000
const VISUAL_BOB_HEIGHT := 2.4
const VISUAL_LEAN_RADIANS := 0.08
const VISUAL_BREATHE_SCALE := 0.025
const STATE_RING_BUILD_COLOR := Color(0.98, 0.84, 0.52, 1.0)
const STATE_RING_RELOAD_COLOR := Color(0.52, 0.82, 1.0, 1.0)
const STATE_RING_BUSY_COLOR := Color(0.7, 0.95, 0.72, 1.0)

signal health_changed(current: int, maximum: int)
signal energy_changed(current: int, maximum: int)
signal resources_changed(resources: Dictionary)
signal message_requested(text: String)
signal player_died()
signal interaction_prompt_changed(text: String)
signal weapon_changed(display_name: String, weapon_id: StringName)
signal weapon_status_changed(text: String)
signal weapon_trait_changed(text: String)
signal weapon_noise_emitted(source_position: Vector2, noise_radius: float, noise_alert_budget: float, weapon_id: StringName)
signal build_mode_toggled(active: bool)
signal build_placement_requested()
signal build_selection_prev_requested()
signal build_selection_next_requested()
signal build_rotation_requested()

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
var _busy_label: String = ""
var _action_complete_callback: Callable
var _attack_windup_pending: bool = false
var _attack_windup_weapon: Resource
var _attack_windup_visual_only: bool = false
var _collision_mask_base: int = 0
var _collision_mask_exemption_counts: Dictionary = {}
var _recycle_action_was_down: bool = false
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
var _damage_feedback_tween: Tween
var _starting_weapon: Resource
var _knockback_velocity: Vector2 = Vector2.ZERO
var _shot_impact_tween: Tween
var _build_mode_active: bool = false
var _build_mode_allowed: bool = true
var _visual_time: float = 0.0
var _state_ring_alpha: float = 0.0

@onready var body_shadow: Polygon2D = $BodyShadow
@onready var state_ring: Polygon2D = $StateRing
@onready var visual_root: Node2D = $VisualRoot
@onready var body_visual: Polygon2D = $VisualRoot/Body
@onready var facing_marker: Polygon2D = $VisualRoot/FacingMarker
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
@onready var combat_audio = $CombatAudio
@onready var interaction_controller = $InteractionController
@onready var loadout_controller = $LoadoutController
@onready var combat_controller = $CombatController

var _spawn_position: Vector2


func _ready() -> void:
	add_to_group("player")
	set_process_input(true)
	set_process(true)
	_spawn_position = global_position
	current_health = max_health
	current_energy = max_energy
	_collision_mask_base = collision_mask
	_base_body_color = body_visual.color
	if attack_area_shape.shape != null:
		attack_area_shape.shape = attack_area_shape.shape.duplicate()
	_starting_weapon = equipped_weapon
	loadout_controller.configure(_starting_weapon)
	loadout_controller.message_requested.connect(func(text: String) -> void:
		message_requested.emit(text)
	)
	loadout_controller.resources_changed.connect(func(updated_resources: Dictionary) -> void:
		resources = updated_resources
		resources_changed.emit(updated_resources.duplicate(true))
	)
	loadout_controller.equipped_weapon_resource_changed.connect(func(weapon: Resource) -> void:
		_equipped_weapon = weapon
		resources = loadout_controller.resources
		_cancel_attack_windup()
		_apply_equipped_weapon()
	)
	loadout_controller.weapon_changed.connect(func(display_name: String, weapon_id: StringName) -> void:
		weapon_changed.emit(display_name, weapon_id)
	)
	loadout_controller.weapon_status_changed.connect(func(text: String) -> void:
		weapon_status_changed.emit(text)
	)
	loadout_controller.weapon_trait_changed.connect(func(text: String) -> void:
		weapon_trait_changed.emit(text)
	)
	resources = loadout_controller.resources
	combat_controller.configure(self)
	_apply_equipped_weapon()
	interaction_controller.configure(self)
	interaction_controller.prompt_changed.connect(func(text: String) -> void:
		interaction_prompt_changed.emit(text)
	)
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


func _process(delta: float) -> void:
	_update_visual_animation(delta)


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

	if Input.is_action_just_pressed("build_mode"):
		_attempt_toggle_build_mode()

	if _build_mode_active:
		if Input.is_action_just_pressed("build_prev"):
			build_selection_prev_requested.emit()
		if Input.is_action_just_pressed("build_next"):
			build_selection_next_requested.emit()
		if Input.is_action_just_pressed("build_rotate"):
			build_rotation_requested.emit()
		if Input.is_action_just_pressed("interact"):
			build_placement_requested.emit()
		var recycle_action_down := Input.is_action_pressed("recycle")
		if recycle_action_down and not _recycle_action_was_down:
			_attempt_recycle()
		_recycle_action_was_down = recycle_action_down
		return

	_recycle_action_was_down = false

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
	return loadout_controller.add_resource(resource_id, amount, show_message)


func spend_resource(resource_id: String, amount: int) -> bool:
	var spent: bool = loadout_controller.spend_resource(resource_id, amount)
	if spent:
		_update_interaction_prompt()
	return spent


func has_resources(costs: Dictionary) -> bool:
	return loadout_controller.has_resources(costs)


func spend_resources(costs: Dictionary) -> bool:
	var spent: bool = loadout_controller.spend_resources(costs)
	if spent:
		_update_interaction_prompt()
	return spent


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
	interaction_controller.set_interaction_gate(callback)


func refresh_interaction_prompt() -> void:
	interaction_controller.refresh_prompt()


func set_build_mode_allowed(allowed: bool) -> void:
	_build_mode_allowed = allowed
	if not allowed and _build_mode_active:
		set_build_mode_active(false, false)


func push_collision_mask_exemption(layer_number: int) -> void:
	if layer_number <= 0:
		return
	_collision_mask_exemption_counts[layer_number] = int(_collision_mask_exemption_counts.get(layer_number, 0)) + 1
	_rebuild_collision_mask()


func pop_collision_mask_exemption(layer_number: int) -> void:
	if layer_number <= 0:
		return
	var current_count := int(_collision_mask_exemption_counts.get(layer_number, 0))
	if current_count <= 1:
		_collision_mask_exemption_counts.erase(layer_number)
	else:
		_collision_mask_exemption_counts[layer_number] = current_count - 1
	_rebuild_collision_mask()


func clear_collision_mask_exemptions() -> void:
	_collision_mask_exemption_counts.clear()
	_rebuild_collision_mask()


func set_build_mode_active(active: bool, show_message: bool = true) -> void:
	if _build_mode_active == active:
		return
	_build_mode_active = active
	build_mode_toggled.emit(_build_mode_active)
	if show_message:
		if _build_mode_active:
			message_requested.emit("Build mode active")
		else:
			message_requested.emit("Build mode closed")
	_update_interaction_prompt()


func is_build_mode_active() -> bool:
	return _build_mode_active


func take_damage(amount: int, _source: Variant = null) -> void:
	if is_dead or amount <= 0:
		return

	_apply_knockback_from_source(_source)
	current_health = max(current_health - amount, 0)
	health_changed.emit(current_health, max_health)
	_flash_body(Color(1.0, 0.45, 0.45, 1.0))
	_play_damage_feedback(_source)
	_play_combat_sound(&"player_hurt", randf_range(0.98, 1.04), -1.0)

	if current_health == 0:
		_die()


func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return

	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)
	_flash_body(Color(0.52, 0.87, 0.62, 1.0))


func equip_weapon(weapon: Resource, show_message: bool = true) -> bool:
	return loadout_controller.equip_weapon(weapon, show_message)


func obtain_weapon(weapon: Resource, auto_equip: bool = true, show_message: bool = true) -> bool:
	return loadout_controller.obtain_weapon(weapon, auto_equip, show_message)


func _handle_movement() -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_vector * move_speed

	if input_vector.is_zero_approx():
		return

	facing_direction = input_vector.normalized()
	_update_facing_visuals()


func _attempt_attack() -> void:
	combat_controller.attempt_attack()


func _play_attack_flash() -> void:
	combat_controller._play_attack_flash()


func _play_hitscan_effect(end_point: Vector2, impact_kind: String) -> void:
	combat_controller._play_hitscan_effect(end_point, impact_kind)


func _play_muzzle_flash() -> void:
	combat_controller._play_muzzle_flash()


func _play_shot_tracer(end_point: Vector2) -> void:
	combat_controller._play_shot_tracer(end_point)


func _play_shot_impact(end_point: Vector2, impact_kind: String) -> void:
	combat_controller._play_shot_impact(end_point, impact_kind)


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


func _attempt_toggle_build_mode() -> void:
	if is_dead or is_busy:
		return
	if _build_mode_active:
		set_build_mode_active(false, false)
		return
	if not _build_mode_allowed:
		message_requested.emit("Build mode unavailable")
		return
	if _has_active_combat_action():
		message_requested.emit("Finish current action first")
		return
	set_build_mode_active(true)


func _has_active_combat_action() -> bool:
	return _attack_windup_pending or _is_reloading_weapon() or attack_cooldown_remaining > 0.0


func _attempt_switch_weapon() -> void:
	if is_dead or is_busy or _attack_windup_pending:
		return
	var was_reloading := _is_reloading_weapon()
	if _is_reloading_weapon():
		_cancel_reload()

	var current_weapon := _get_equipped_weapon()
	if current_weapon == null:
		return

	var current_weapon_empty: bool = _uses_weapon_magazine(current_weapon) and _get_weapon_magazine_ammo(current_weapon) <= 0
	if attack_cooldown_remaining > 0.0 and not was_reloading and not current_weapon_empty:
		return

	var obtained_weapons: Array[Resource] = loadout_controller.get_obtained_weapons()
	if obtained_weapons.size() <= 1:
		message_requested.emit("Only %s available" % current_weapon.display_name)
		return

	var current_index: int = _get_obtained_weapon_index(current_weapon.weapon_id)
	if current_index < 0:
		current_index = 0

	var next_index: int = (current_index + 1) % obtained_weapons.size()
	equip_weapon(obtained_weapons[next_index], true)


func _attempt_interact() -> void:
	interaction_controller.attempt_interact()


func _attempt_recycle() -> void:
	if is_dead or is_busy or not _build_mode_active or _has_active_combat_action():
		return
	interaction_controller.attempt_recycle()


func _die() -> void:
	is_dead = true
	cancel_timed_action()
	_cancel_attack_windup()
	clear_collision_mask_exemptions()
	velocity = Vector2.ZERO
	message_requested.emit("You died")
	player_died.emit()
	_update_interaction_prompt()


func reset_for_new_run() -> void:
	is_dead = false
	cancel_timed_action()
	set_build_mode_active(false, false)
	clear_collision_mask_exemptions()
	current_health = max_health
	current_energy = max_energy
	_cancel_attack_windup()
	attack_cooldown_remaining = 0.0
	_knockback_velocity = Vector2.ZERO
	_recycle_action_was_down = false
	velocity = Vector2.ZERO
	interaction_controller.clear_interactables()
	loadout_controller.reset_for_new_run()
	resources = loadout_controller.resources
	global_position = _spawn_position
	_emit_full_state()
	_update_interaction_prompt()
	_update_render_order()
	_state_ring_alpha = 0.0


func _rebuild_collision_mask() -> void:
	var updated_mask := _collision_mask_base
	for layer_number in _collision_mask_exemption_counts.keys():
		var layer := int(layer_number)
		if layer <= 0:
			continue
		updated_mask &= ~(1 << (layer - 1))
	collision_mask = updated_mask


func _emit_full_state() -> void:
	health_changed.emit(current_health, max_health)
	energy_changed.emit(current_energy, max_energy)
	loadout_controller.emit_full_state()


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
	combat_controller.on_attack_windup_timer_timeout()


func _update_interaction_prompt() -> void:
	interaction_controller.refresh_prompt()


func _register_interactable(interactable: Node2D) -> void:
	interaction_controller.register_interactable(interactable)


func _unregister_interactable(interactable: Node2D) -> void:
	interaction_controller.unregister_interactable(interactable)


func _update_render_order() -> void:
	z_as_relative = false
	z_index = GAMEPLAY_Z_BASE + int(round(global_position.y))


func _update_facing_visuals() -> void:
	attack_pivot.rotation = facing_direction.angle() + PI / 2.0
	facing_marker.rotation = attack_pivot.rotation


func _update_visual_animation(delta: float) -> void:
	if visual_root == null or body_shadow == null or state_ring == null:
		return

	var movement_ratio := clampf(velocity.length() / maxf(move_speed, 1.0), 0.0, 1.0)
	_visual_time += delta * lerpf(2.0, 9.0, movement_ratio)
	var breathe := sin(_visual_time * 2.2) * VISUAL_BREATHE_SCALE
	var bob := sin(_visual_time * 10.0) * VISUAL_BOB_HEIGHT * movement_ratio
	var lean_target := clampf(velocity.x / maxf(move_speed, 1.0), -1.0, 1.0) * VISUAL_LEAN_RADIANS

	visual_root.position = Vector2(0.0, bob)
	visual_root.rotation = lerpf(visual_root.rotation, lean_target, minf(delta * 10.0, 1.0))
	var stretch_x := 1.0 + 0.045 * movement_ratio + maxf(breathe, 0.0)
	var stretch_y := 1.0 - 0.03 * movement_ratio - minf(breathe, 0.0)
	visual_root.scale = Vector2(stretch_x, stretch_y)

	body_shadow.scale = Vector2(1.0 - 0.14 * movement_ratio, 1.0 + 0.08 * movement_ratio)
	body_shadow.modulate = Color(1.0, 1.0, 1.0, 0.18 + 0.07 * movement_ratio)

	var target_ring_alpha := 0.0
	var ring_color := STATE_RING_BUILD_COLOR
	if is_dead:
		target_ring_alpha = 0.0
	elif _build_mode_active:
		target_ring_alpha = 0.55
		ring_color = STATE_RING_BUILD_COLOR
	elif _is_reloading_weapon():
		target_ring_alpha = 0.5
		ring_color = STATE_RING_RELOAD_COLOR
	elif is_busy:
		target_ring_alpha = 0.42
		ring_color = STATE_RING_BUSY_COLOR
	_state_ring_alpha = move_toward(_state_ring_alpha, target_ring_alpha, delta * 4.0)
	if _state_ring_alpha <= 0.01:
		state_ring.visible = false
		return
	state_ring.visible = true
	var pulse := 1.0 + 0.08 * sin(_visual_time * 5.0)
	state_ring.scale = Vector2.ONE * pulse
	state_ring.color = Color(ring_color.r, ring_color.g, ring_color.b, _state_ring_alpha * (0.82 + 0.12 * sin(_visual_time * 4.0)))


func get_equipped_weapon_display_name() -> String:
	return loadout_controller.get_equipped_weapon_display_name()


func get_obtained_weapon_ids() -> PackedStringArray:
	return loadout_controller.get_obtained_weapon_ids()


func get_save_state() -> Dictionary:
	var loadout_state: Dictionary = loadout_controller.get_save_state()
	return {
		"position": {
			"x": global_position.x,
			"y": global_position.y,
		},
		"health": current_health,
		"energy": current_energy,
		"resources": loadout_state.get("resources", {}).duplicate(true),
		"equipped_weapon_id": String(loadout_state.get("equipped_weapon_id", "")),
		"obtained_weapon_ids": loadout_state.get("obtained_weapon_ids", PackedStringArray()),
		"build_mode_active": _build_mode_active,
	}


func apply_save_state(save_state: Dictionary, weapon_lookup: Callable) -> void:
	var position_data: Dictionary = save_state.get("position", {})
	global_position = Vector2(
		float(position_data.get("x", global_position.x)),
		float(position_data.get("y", global_position.y))
	)
	current_health = clampi(int(save_state.get("health", max_health)), 0, max_health)
	current_energy = clampi(int(save_state.get("energy", max_energy)), 0, max_energy)

	loadout_controller.apply_save_state(save_state, weapon_lookup)
	resources = loadout_controller.resources

	set_build_mode_active(bool(save_state.get("build_mode_active", false)), false)
	_emit_full_state()
	_update_interaction_prompt()
	_update_render_order()


func _get_equipped_weapon() -> Resource:
	return loadout_controller.get_equipped_weapon()


func _get_obtained_weapon_index(weapon_id: StringName) -> int:
	var obtained_weapons: Array[Resource] = loadout_controller.get_obtained_weapons()
	for index in obtained_weapons.size():
		var weapon: Resource = obtained_weapons[index]
		if weapon != null and weapon.weapon_id == weapon_id:
			return index
	return -1


func _apply_equipped_weapon() -> void:
	var weapon: Resource = _get_equipped_weapon()
	if weapon == null:
		return
	combat_controller.apply_weapon_visuals(weapon)


func _get_attack_result_for_weapon(weapon: Resource) -> Dictionary:
	return combat_controller.get_attack_result_for_weapon(weapon)


func _get_visual_only_attack_result_for_weapon(weapon: Resource) -> Dictionary:
	return combat_controller.get_visual_only_attack_result_for_weapon(weapon)


func _get_attack_targets_for_weapon(weapon: Resource) -> Array:
	return combat_controller.get_attack_targets_for_weapon(weapon)


func _get_melee_attack_targets() -> Array:
	return combat_controller._get_melee_attack_targets()


func _get_enemy_targets_in_attack_shape() -> Array:
	return combat_controller._get_enemy_targets_in_attack_shape()


func _is_enemy_blocked_by_structure(enemy) -> bool:
	return combat_controller._is_enemy_blocked_by_structure(enemy)


func _get_hitscan_attack_result(weapon: Resource) -> Dictionary:
	return combat_controller._get_hitscan_attack_result(weapon)


func _get_spread_hitscan_attack_result(weapon: Resource) -> Dictionary:
	return combat_controller._get_spread_hitscan_attack_result(weapon)


func _commit_attack(weapon_override: Resource = null) -> void:
	combat_controller.commit_attack(weapon_override)


func _emit_weapon_noise(weapon: Resource) -> void:
	combat_controller._emit_weapon_noise(weapon)


func _cancel_attack_windup() -> void:
	combat_controller.cancel_attack_windup()


func _show_attack_indicator_windup(duration: float) -> void:
	combat_controller._show_attack_indicator_windup(duration)


func _show_attack_indicator_strike() -> void:
	combat_controller._show_attack_indicator_strike()


func _hide_attack_indicator() -> void:
	combat_controller._hide_attack_indicator()


func _stop_attack_indicator_tween() -> void:
	combat_controller._stop_attack_indicator_tween()


func _get_default_held_weapon_polygon() -> PackedVector2Array:
	return combat_controller.get_default_held_weapon_polygon()


func _get_muzzle_local_position() -> Vector2:
	return combat_controller.get_muzzle_local_position()


func _emit_weapon_state() -> void:
	loadout_controller.emit_full_state()


func _build_attack_damage_map(weapon: Resource, hit_targets: Array) -> Dictionary:
	return combat_controller.build_attack_damage_map(weapon, hit_targets)


func _apply_miss_recovery(weapon: Resource) -> void:
	combat_controller.apply_miss_recovery(weapon)


func get_weapon_status_text() -> String:
	return loadout_controller.get_weapon_status_text()


func get_weapon_trait_text() -> String:
	return loadout_controller.get_weapon_trait_text()


func _uses_weapon_magazine(weapon: Resource) -> bool:
	return loadout_controller.uses_weapon_magazine(weapon)


func _begin_reload(weapon: Resource, auto_triggered: bool) -> void:
	if weapon == null or not _uses_weapon_magazine(weapon):
		return
	if is_dead or is_busy or _attack_windup_pending or _is_reloading_weapon():
		return
	loadout_controller.begin_reload(weapon, auto_triggered)
	if _is_reloading_weapon():
		_play_combat_sound(&"player_reload_start", randf_range(0.98, 1.03), -4.0)


func _ensure_weapon_runtime_state(weapon: Resource) -> void:
	loadout_controller.ensure_weapon_runtime_state(weapon)


func _get_weapon_magazine_ammo(weapon: Resource) -> int:
	return loadout_controller.get_weapon_magazine_ammo(weapon)


func _set_weapon_magazine_ammo(weapon: Resource, amount: int) -> void:
	loadout_controller.set_weapon_magazine_ammo(weapon, amount)


func _consume_weapon_magazine_round(weapon: Resource) -> void:
	loadout_controller.consume_weapon_magazine_round(weapon)


func _is_reloading_weapon() -> bool:
	return loadout_controller.is_reloading_weapon()


func _cancel_reload() -> void:
	loadout_controller.cancel_reload()


func _update_reload(delta: float) -> void:
	var was_reloading := _is_reloading_weapon()
	loadout_controller.update_reload(delta)
	if was_reloading and not _is_reloading_weapon():
		_play_combat_sound(&"player_reload_done", randf_range(0.99, 1.02), -3.0)


func _complete_reload() -> void:
	var was_reloading: bool = _is_reloading_weapon()
	loadout_controller.complete_reload()
	if was_reloading and not _is_reloading_weapon():
		_play_combat_sound(&"player_reload_done", randf_range(0.99, 1.02), -3.0)


func _get_bullet_reserve_amount() -> int:
	return loadout_controller.get_bullet_reserve_amount()


func _start_attack_sequence(weapon: Resource, visual_only: bool) -> void:
	combat_controller.start_attack_sequence(weapon, visual_only)


func _play_attack_effect(weapon: Resource, attack_result: Dictionary) -> void:
	combat_controller.play_attack_effect(weapon, attack_result)


func _play_combat_sound(sound_id: StringName, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	if combat_audio != null and is_instance_valid(combat_audio) and combat_audio.has_method("play_sound"):
		combat_audio.play_sound(sound_id, pitch_scale, volume_db)


func play_feedback_sound(sound_id: StringName, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	_play_combat_sound(sound_id, pitch_scale, volume_db)


func _get_attack_sound_id_for_weapon(weapon: Resource) -> StringName:
	return combat_controller.get_attack_sound_id_for_weapon(weapon)


func _get_attack_sound_pitch_for_weapon(weapon: Resource) -> float:
	return combat_controller.get_attack_sound_pitch_for_weapon(weapon)


func _get_attack_sound_volume_for_weapon(weapon: Resource) -> float:
	return combat_controller.get_attack_sound_volume_for_weapon(weapon)


func _get_attack_impact_sound_id(impact_kind: String) -> StringName:
	return combat_controller.get_attack_impact_sound_id(impact_kind)


func _get_attack_impact_volume(impact_kind: String) -> float:
	return combat_controller.get_attack_impact_volume(impact_kind)
