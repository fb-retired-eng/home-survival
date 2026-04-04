extends CharacterBody2D
class_name GameEnemy

const EnemyDefinitionResource = preload("res://scripts/data/enemy_definition.gd")
const HEALTH_BAR_FILL_HALF_WIDTH := 14.0
const HEALTH_BAR_FILL_HALF_HEIGHT := 2.0
const GAMEPLAY_Z_BASE := 1000
const THREAT_INDICATOR_GRACE_TIME := 0.65

signal died(enemy)

@export var definition: EnemyDefinitionResource
@export var enemy_id: StringName = &"zombie_basic"
@export var max_health: int = 50
@export var defense_flat_reduction: int = 0
@export_range(0.0, 4.0, 0.05) var defense_multiplier: float = 1.0
@export var move_speed: float = 70.0
@export var player_damage: int = 10
@export_range(0.0, 1200.0, 10.0) var player_knockback_force: float = 90.0
@export var structure_damage: int = 10
@export var structure_damage_type: StringName = &"impact"
@export_range(0.0, 240.0, 1.0) var attack_range_override: float = 0.0
@export_range(0.0, 240.0, 1.0) var structure_attack_range_override: float = 0.0
@export_range(0.0, 2.0, 0.05) var knockback_multiplier: float = 1.0
@export_range(0.0, 4000.0, 10.0) var knockback_decay: float = 900.0
@export var attack_cooldown: float = 1.0
@export var attack_prep_time: float = 0.25

var current_health: int
var _damage_cooldown_remaining: float = 0.0
var _base_color: Color
var _behavior_context: StringName = &"exploration"
var _player_ref
var _enemy_layer_ref: Node
var _placeables_root: Node
var _wave_sockets: Array = []
var _player_obstructing_this_frame: bool = false
var _preferred_socket_ids: PackedStringArray = []
var _facing_direction: Vector2 = Vector2.DOWN
var _is_chasing_player: bool = false
var _is_exploration_suspended: bool = false
var _is_alerted_to_player: bool = false
var _is_investigating_noise: bool = false
var _noise_investigation_position: Vector2 = Vector2.ZERO
var _noise_investigation_remaining: float = 0.0
var _noise_investigation_detect_delay_remaining: float = 0.0
var _attack_prep_remaining: float = 0.0
var _attack_prep_armed: bool = false
var _attack_prep_target_id: int = 0
var _attack_prep_lost_target_grace_remaining: float = 0.0
var _slow_effect_multiplier: float = 1.0
var _slow_effect_remaining: float = 0.0
var _damage_feedback_tween: Tween
var _exploration_anchor_position: Vector2 = Vector2.ZERO
var _exploration_anchor_facing: Vector2 = Vector2.ZERO
var _has_exploration_anchor: bool = false
var _knockback_velocity: Vector2 = Vector2.ZERO
var _base_facing_marker_color: Color
var _base_elite_aura_color: Color
var _visual_time: float = 0.0
var _health_bar_alpha: float = 0.0
var _visual_movement_ratio: float = 0.0
var _visual_bob_offset_y: float = 0.0
var _visual_body_rotation: float = 0.0
var _threat_indicator_grace_remaining: float = 0.0
var _presentation_scale: Vector2 = Vector2.ONE
var _visual_bob_height: float = 1.2
var _visual_breathe_scale: float = 0.016
var _visual_turn_speed: float = 10.0
var _visual_move_stretch_x: float = 0.03
var _visual_move_stretch_y: float = 0.022
var _prep_pose_offset: Vector2 = Vector2.ZERO
var _prep_pose_scale: Vector2 = Vector2.ONE
var _prep_pose_tilt_radians: float = 0.0
var _damage_feedback_distance: float = 4.0
var _damage_feedback_scale: Vector2 = Vector2(1.06, 0.94)
var _damage_feedback_duration: float = 0.12
var _damage_feedback_rotation_offset: float = 0.0

@onready var body_shadow: Polygon2D = $BodyShadow
@onready var state_indicator: Polygon2D = $StateIndicator
@onready var visual_root: Node2D = $VisualRoot
@onready var elite_aura: Polygon2D = $VisualRoot/EliteAura
@onready var body_visual: Polygon2D = $VisualRoot/Body
@onready var facing_marker: Polygon2D = $VisualRoot/FacingMarker
@onready var health_bar_background: Polygon2D = $VisualRoot/HealthBarBackground
@onready var health_bar_fill: Polygon2D = $VisualRoot/HealthBarFill
@onready var attack_tell: Polygon2D = $VisualRoot/AttackTell
@onready var attack_flash: Polygon2D = $VisualRoot/AttackFlash
@onready var damage_area: Area2D = $DamageArea
@onready var body_touch_area: Area2D = $BodyTouchArea
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var combat_audio: Node2D = $CombatAudio
@onready var combat_controller = $CombatController
@onready var targeting_controller = $TargetingController
@onready var presentation_controller = $PresentationController
@onready var movement_controller = $MovementController
@onready var runtime_controller = $RuntimeController


func _ready() -> void:
	add_to_group("enemies")
	set_process(true)
	_base_color = body_visual.color
	_base_facing_marker_color = facing_marker.color
	_base_elite_aura_color = elite_aura.color
	combat_controller.configure(self)
	targeting_controller.configure(self)
	presentation_controller.configure(self)
	movement_controller.configure(self)
	runtime_controller.configure(self)
	_apply_definition()
	current_health = max_health
	runtime_controller.cache_runtime_context()
	runtime_controller.refresh_player_reference()
	_update_facing_direction(_facing_direction)
	presentation_controller.sync_initial_pose()
	presentation_controller.refresh_health_bar()
	presentation_controller.update_render_order()


func _process(delta: float) -> void:
	presentation_controller.process_visuals(delta)


func configure_runtime_context(player_ref = null, enemy_layer: Node = null, placeables_root: Node = null) -> void:
	if player_ref != null and is_instance_valid(player_ref):
		_player_ref = player_ref
	if enemy_layer != null and is_instance_valid(enemy_layer):
		_enemy_layer_ref = enemy_layer
	if placeables_root != null and is_instance_valid(placeables_root):
		_placeables_root = placeables_root
	runtime_controller.cache_runtime_context()


func configure_wave_context(player_ref, defense_sockets: Array, preferred_socket_ids: PackedStringArray = PackedStringArray()) -> void:
	_behavior_context = &"wave"
	_player_ref = player_ref
	_wave_sockets = defense_sockets.duplicate()
	_preferred_socket_ids = preferred_socket_ids
	targeting_controller.clear_noise_investigation()
	runtime_controller.cache_runtime_context()
	_refresh_spawn_facing()


func configure_exploration_context(player_ref, initial_facing_direction: Vector2 = Vector2.ZERO, refresh_facing: bool = false, anchor_position: Vector2 = Vector2.ZERO, set_anchor: bool = false) -> void:
	_behavior_context = &"exploration"
	_player_ref = player_ref
	_wave_sockets.clear()
	_preferred_socket_ids = PackedStringArray()
	targeting_controller.clear_noise_investigation()
	if set_anchor:
		_exploration_anchor_position = anchor_position
		_exploration_anchor_facing = initial_facing_direction
		_has_exploration_anchor = true
	runtime_controller.cache_runtime_context()
	set_exploration_suspended(false)
	if refresh_facing:
		_refresh_spawn_facing(initial_facing_direction)


func has_exploration_anchor() -> bool:
	return _has_exploration_anchor


func get_exploration_anchor_position() -> Vector2:
	return _exploration_anchor_position


func get_exploration_anchor_facing() -> Vector2:
	return _exploration_anchor_facing


func set_exploration_suspended(suspended: bool) -> void:
	if _behavior_context != &"exploration":
		return

	_is_exploration_suspended = suspended
	visible = not suspended
	set_physics_process(not suspended)
	velocity = Vector2.ZERO
	_knockback_velocity = Vector2.ZERO
	if suspended:
		targeting_controller.clear_noise_investigation()
	if collision_shape != null:
		collision_shape.disabled = suspended
	if damage_area != null:
		damage_area.monitoring = not suspended
		damage_area.monitorable = not suspended


func is_engaged_with_player() -> bool:
	var live_player = runtime_controller.get_live_player()
	if _behavior_context != &"exploration" or _is_exploration_suspended or live_player == null:
		return false

	return _is_chasing_player or runtime_controller.is_player_body_touching(live_player)


func is_investigating_noise() -> bool:
	return targeting_controller.has_active_noise_investigation()


func is_attack_prep_armed() -> bool:
	return _attack_prep_armed


func get_slow_effect_multiplier() -> float:
	return _slow_effect_multiplier


func apply_external_slow(slow_factor: float, duration: float) -> void:
	var clamped_slow_factor := clampf(slow_factor, 0.0, 1.0)
	if clamped_slow_factor <= 0.0 or duration <= 0.0:
		return
	_slow_effect_multiplier = minf(_slow_effect_multiplier, clamped_slow_factor)
	_slow_effect_remaining = maxf(_slow_effect_remaining, duration)


func _physics_process(delta: float) -> void:
	_damage_cooldown_remaining = max(_damage_cooldown_remaining - delta, 0.0)
	_attack_prep_remaining = max(_attack_prep_remaining - delta, 0.0)
	_attack_prep_lost_target_grace_remaining = max(_attack_prep_lost_target_grace_remaining - delta, 0.0)
	_noise_investigation_remaining = max(_noise_investigation_remaining - delta, 0.0)
	_noise_investigation_detect_delay_remaining = max(_noise_investigation_detect_delay_remaining - delta, 0.0)
	_slow_effect_remaining = max(_slow_effect_remaining - delta, 0.0)
	_threat_indicator_grace_remaining = max(_threat_indicator_grace_remaining - delta, 0.0)
	if _slow_effect_remaining <= 0.0:
		_slow_effect_multiplier = 1.0
	movement_controller.decay_knockback(delta)
	targeting_controller.update_player_chase_state()
	var primary_target = targeting_controller.get_current_target()
	_player_obstructing_this_frame = false
	if _knockback_velocity.length_squared() > 0.01:
		velocity = _knockback_velocity
	elif targeting_controller.has_active_noise_investigation() and not _is_chasing_player:
		var investigate_offset := _noise_investigation_position - global_position
		if investigate_offset.length() <= 12.0 or _noise_investigation_remaining <= 0.0:
			targeting_controller.clear_noise_investigation()
			velocity = Vector2.ZERO
		else:
			velocity = investigate_offset.normalized() * move_speed * _slow_effect_multiplier
			_update_facing_direction(investigate_offset)
	elif primary_target != null and is_instance_valid(primary_target) and not combat_controller.is_target_in_damage_range(primary_target):
		velocity = movement_controller.compute_move_velocity(primary_target)
		if not velocity.is_zero_approx():
			_update_facing_direction(velocity)
	else:
		if primary_target != null and is_instance_valid(primary_target):
			_update_facing_direction(combat_controller.get_target_point(primary_target) - global_position)
		velocity = Vector2.ZERO

	move_and_slide()
	presentation_controller.update_render_order()
	_player_obstructing_this_frame = movement_controller.is_player_obstructing(primary_target)

	if movement_controller.is_under_knockback():
		return

	var attack_target: Variant = combat_controller.get_attack_target(primary_target)
	var is_attack_delayed: bool = combat_controller.process_attack_prep(attack_target)
	combat_controller.update_attack_prep_visual()
	if _damage_cooldown_remaining > 0.0:
		return
	if is_attack_delayed:
		return
	if combat_controller.try_damage_target(attack_target):
		_damage_cooldown_remaining = attack_cooldown
		combat_controller.reset_attack_prep()
		return
	if _attack_prep_armed:
		combat_controller.reset_attack_prep()


func _update_facing_direction(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return

	_facing_direction = direction.normalized()


func _refresh_spawn_facing(preferred_direction: Vector2 = Vector2.ZERO) -> void:
	if not preferred_direction.is_zero_approx():
		_update_facing_direction(preferred_direction)
		return

	var primary_target = targeting_controller.get_current_target()
	if primary_target != null and is_instance_valid(primary_target):
		_update_facing_direction(combat_controller.get_target_point(primary_target) - global_position)
		return

	var random_direction := Vector2.RIGHT.rotated(randf() * TAU)
	_update_facing_direction(random_direction)


func take_damage(amount: int, _source: Variant = null) -> void:
	if amount <= 0:
		return

	_alert_to_player_from_source(_source)
	_apply_knockback_from_source(_source)
	_apply_attack_interrupt_from_source(_source)
	_apply_slow_effect_from_source(_source)
	var damage_amount := _resolve_damage_taken(amount, _source)
	if damage_amount <= 0:
		return

	current_health = max(current_health - damage_amount, 0)
	_threat_indicator_grace_remaining = maxf(_threat_indicator_grace_remaining, THREAT_INDICATOR_GRACE_TIME)
	presentation_controller.refresh_health_bar()
	presentation_controller.flash_body(Color(1.0, 0.55, 0.55, 1.0))
	presentation_controller.play_damage_feedback(_source)
	_play_combat_sound(&"enemy_hurt", randf_range(0.94, 1.06), -2.0)

	if current_health == 0:
		runtime_controller.spawn_death_drop()
		died.emit(self)
		queue_free()


func _apply_definition() -> void:
	if definition == null:
		return

	enemy_id = definition.enemy_id
	max_health = definition.max_health
	defense_flat_reduction = definition.defense_flat_reduction
	defense_multiplier = definition.defense_multiplier
	move_speed = definition.move_speed
	player_damage = definition.player_damage
	player_knockback_force = definition.player_knockback_force
	structure_damage = definition.structure_damage
	structure_damage_type = definition.structure_damage_type
	attack_range_override = definition.attack_range_override
	structure_attack_range_override = definition.structure_attack_range_override
	knockback_multiplier = definition.knockback_multiplier
	knockback_decay = definition.knockback_decay
	attack_cooldown = definition.attack_interval
	attack_prep_time = definition.attack_prep_time
	presentation_controller.apply_definition_visuals()
	presentation_controller.refresh_health_bar()


func _apply_knockback_from_source(source: Variant) -> void:
	if knockback_multiplier <= 0.0:
		return
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
		var attacker = source.get("attacker")
		if attacker != null and is_instance_valid(attacker) and attacker is Node2D:
			knockback_direction = (global_position - attacker.global_position).normalized()

	if knockback_direction.is_zero_approx():
		return

	var applied_force := base_force * knockback_multiplier
	if applied_force <= 0.0:
		return

	_knockback_velocity = knockback_direction * applied_force


func _apply_attack_interrupt_from_source(source: Variant) -> void:
	combat_controller.apply_attack_interrupt_from_source(source)


func _apply_slow_effect_from_source(source: Variant) -> void:
	if source == null or typeof(source) != TYPE_DICTIONARY:
		return
	var slow_factor := float(source.get("slow_factor", 0.0))
	if slow_factor <= 0.0:
		return
	var clamped_slow_factor := clampf(slow_factor, 0.0, 1.0)
	if clamped_slow_factor <= 0.0:
		return
	var duration := float(source.get("slow_duration", 1.1))
	_slow_effect_multiplier = minf(_slow_effect_multiplier, clamped_slow_factor)
	_slow_effect_remaining = maxf(_slow_effect_remaining, duration)


func _resolve_damage_taken(base_damage: int, source: Variant) -> int:
	var damage_type := StringName(&"melee")
	if source is Dictionary:
		damage_type = StringName(source.get("damage_type", &"melee"))

	if definition != null:
		return int(definition.compute_damage_taken(base_damage, damage_type))

	var reduced_damage: int = max(base_damage - defense_flat_reduction, 0)
	return max(int(round(reduced_damage * defense_multiplier)), 0)


func _alert_to_player_from_source(source: Variant) -> void:
	targeting_controller.alert_to_player_from_source(source)

func _play_combat_sound(sound_id: StringName, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	if combat_audio != null and is_instance_valid(combat_audio) and combat_audio.has_method("play_sound"):
		combat_audio.play_sound(sound_id, pitch_scale, volume_db)
