extends CharacterBody2D
class_name Zombie

const EnemyDefinitionResource = preload("res://scripts/data/enemy_definition.gd")
const ResourcePickupScene = preload("res://scenes/world/ResourcePickup.tscn")
const HEALTH_BAR_FILL_HALF_WIDTH := 14.0
const HEALTH_BAR_FILL_HALF_HEIGHT := 2.0

signal died(zombie: Zombie)

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

@onready var elite_aura: Polygon2D = $EliteAura
@onready var body_visual: Polygon2D = $Body
@onready var facing_marker: Polygon2D = $FacingMarker
@onready var health_bar_background: Polygon2D = $HealthBarBackground
@onready var health_bar_fill: Polygon2D = $HealthBarFill
@onready var attack_flash: Polygon2D = $AttackFlash
@onready var damage_area: Area2D = $DamageArea
@onready var body_touch_area: Area2D = $BodyTouchArea
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")
	_base_color = body_visual.color
	_base_facing_marker_color = facing_marker.color
	_base_elite_aura_color = elite_aura.color
	_apply_definition()
	current_health = max_health
	_refresh_player_reference()
	_update_facing_direction(_facing_direction)
	_refresh_health_bar()


func configure_wave_context(player_ref, defense_sockets: Array, preferred_socket_ids: PackedStringArray = PackedStringArray()) -> void:
	_behavior_context = &"wave"
	_player_ref = player_ref
	_wave_sockets = defense_sockets.duplicate()
	_preferred_socket_ids = preferred_socket_ids
	_clear_noise_investigation()
	_refresh_spawn_facing()


func configure_exploration_context(player_ref, initial_facing_direction: Vector2 = Vector2.ZERO, refresh_facing: bool = false, anchor_position: Vector2 = Vector2.ZERO, set_anchor: bool = false) -> void:
	_behavior_context = &"exploration"
	_player_ref = player_ref
	_wave_sockets.clear()
	_preferred_socket_ids = PackedStringArray()
	_clear_noise_investigation()
	if set_anchor:
		_exploration_anchor_position = anchor_position
		_exploration_anchor_facing = initial_facing_direction
		_has_exploration_anchor = true
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
		_clear_noise_investigation()
	if collision_shape != null:
		collision_shape.disabled = suspended
	if damage_area != null:
		damage_area.monitoring = not suspended
		damage_area.monitorable = not suspended


func is_engaged_with_player() -> bool:
	var live_player = _get_live_player()
	if _behavior_context != &"exploration" or _is_exploration_suspended or live_player == null:
		return false

	return _is_chasing_player or _is_player_body_touching(live_player)


func get_noise_alert_weight() -> float:
	if definition == null:
		return 1.0
	return max(float(definition.noise_alert_weight), 0.0)


func is_investigating_noise() -> bool:
	return _has_active_noise_investigation()


func is_attack_prep_armed() -> bool:
	return _attack_prep_armed


func get_slow_effect_multiplier() -> float:
	return _slow_effect_multiplier


func _physics_process(delta: float) -> void:
	_damage_cooldown_remaining = max(_damage_cooldown_remaining - delta, 0.0)
	_attack_prep_remaining = max(_attack_prep_remaining - delta, 0.0)
	_attack_prep_lost_target_grace_remaining = max(_attack_prep_lost_target_grace_remaining - delta, 0.0)
	_noise_investigation_remaining = max(_noise_investigation_remaining - delta, 0.0)
	_noise_investigation_detect_delay_remaining = max(_noise_investigation_detect_delay_remaining - delta, 0.0)
	_slow_effect_remaining = max(_slow_effect_remaining - delta, 0.0)
	if _slow_effect_remaining <= 0.0:
		_slow_effect_multiplier = 1.0
	_decay_knockback(delta)
	_update_player_chase_state()
	var primary_target = _get_current_target()
	_player_obstructing_this_frame = false
	if _knockback_velocity.length_squared() > 0.01:
		velocity = _knockback_velocity
	elif _has_active_noise_investigation() and not _is_chasing_player:
		var investigate_offset := _noise_investigation_position - global_position
		if investigate_offset.length() <= 12.0 or _noise_investigation_remaining <= 0.0:
			_clear_noise_investigation()
			velocity = Vector2.ZERO
		else:
			velocity = investigate_offset.normalized() * move_speed * _slow_effect_multiplier
			_update_facing_direction(investigate_offset)
	elif primary_target != null and is_instance_valid(primary_target) and not _is_target_in_damage_range(primary_target):
		velocity = _compute_move_velocity(primary_target)
		if not velocity.is_zero_approx():
			_update_facing_direction(velocity)
	else:
		if primary_target != null and is_instance_valid(primary_target):
			_update_facing_direction(_get_target_point(primary_target) - global_position)
		velocity = Vector2.ZERO

	move_and_slide()
	_player_obstructing_this_frame = _is_player_obstructing(primary_target)

	if _is_under_knockback():
		return

	var attack_target = _get_attack_target(primary_target)
	var is_attack_delayed := _process_attack_prep(attack_target)
	_update_attack_prep_visual()
	if _damage_cooldown_remaining > 0.0:
		return
	if is_attack_delayed:
		return
	if _try_damage_target(attack_target):
		_damage_cooldown_remaining = attack_cooldown
		_reset_attack_prep()
		return
	if _attack_prep_armed:
		_reset_attack_prep()


func _compute_move_velocity(primary_target) -> Vector2:
	if primary_target == null or not is_instance_valid(primary_target):
		return Vector2.ZERO

	var target_offset: Vector2 = _get_target_point(primary_target) - global_position
	if target_offset.is_zero_approx():
		return Vector2.ZERO

	var move_direction := target_offset.normalized()
	var separation := _get_enemy_separation_vector()
	if not separation.is_zero_approx():
		move_direction += separation * _get_separation_weight()

	var sidestep := _get_enemy_block_sidestep(primary_target, target_offset)
	if not sidestep.is_zero_approx():
		move_direction += sidestep * _get_sidestep_weight()

	if move_direction.is_zero_approx():
		return Vector2.ZERO

	return move_direction.normalized() * move_speed * _slow_effect_multiplier


func _update_facing_direction(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return

	_facing_direction = direction.normalized()
	body_visual.rotation = _facing_direction.angle() - PI / 2.0
	facing_marker.rotation = _facing_direction.angle() + PI / 2.0
	attack_flash.rotation = facing_marker.rotation


func _refresh_spawn_facing(preferred_direction: Vector2 = Vector2.ZERO) -> void:
	if not preferred_direction.is_zero_approx():
		_update_facing_direction(preferred_direction)
		return

	var primary_target = _get_current_target()
	if primary_target != null and is_instance_valid(primary_target):
		_update_facing_direction(_get_target_point(primary_target) - global_position)
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
	_refresh_health_bar()
	_flash_body(Color(1.0, 0.55, 0.55, 1.0))
	_play_damage_feedback(_source)

	if current_health == 0:
		_spawn_death_drop()
		died.emit(self)
		queue_free()


func _get_current_target():
	var live_player = _get_live_player()
	var target_mode := _get_target_mode_for_context()
	if _is_chasing_player and live_player != null and _does_chase_override_target_mode(target_mode):
		return live_player

	if _behavior_context != &"wave" and _should_idle_until_player_detected() and not _is_chasing_player:
		return null

	var structure_target = _get_closest_intact_structure()
	match target_mode:
		EnemyDefinitionResource.WaveTargetMode.SOCKET_THEN_PLAYER:
			if structure_target != null:
				return structure_target
			return live_player
		EnemyDefinitionResource.WaveTargetMode.PLAYER_THEN_SOCKET:
			if live_player != null:
				return live_player
			return structure_target
		EnemyDefinitionResource.WaveTargetMode.SOCKET_ONLY:
			if structure_target != null:
				return structure_target
			if _should_fallback_to_player_when_no_sockets():
				return live_player
			return null
		EnemyDefinitionResource.WaveTargetMode.PLAYER_ONLY:
			return live_player

	return live_player


func _get_attack_target(primary_target):
	var live_player = _get_live_player()
	if _should_attack_player_on_contact() and live_player != null and _is_player_body_touching(live_player):
		if primary_target == null or primary_target != live_player:
			return live_player

	if primary_target == null:
		return null

	if _behavior_context == &"wave":
		if _should_attack_obstructing_player() and _player_obstructing_this_frame and live_player != null:
			return live_player

	return primary_target


func _get_closest_intact_structure():
	var preferred_structures := _get_intact_preferred_structures()
	if not preferred_structures.is_empty():
		return _get_closest_structure_from_list(preferred_structures)

	return _get_closest_structure_from_list(_get_all_structure_targets())


func _get_intact_preferred_structures() -> Array:
	var preferred_structures: Array = []
	if _preferred_socket_ids.is_empty():
		return preferred_structures

	for socket in _wave_sockets:
		if not is_instance_valid(socket):
			continue

		if not _is_structure_target(socket):
			continue

		if not _preferred_socket_ids.has(String(socket.socket_id)):
			continue

		if socket.has_method("is_breached") and socket.is_breached():
			continue

		preferred_structures.append(socket)

	for placeable in get_tree().get_nodes_in_group("placeables"):
		if not is_instance_valid(placeable):
			continue
		if not placeable.has_method("get_placeable_id"):
			continue
		if placeable.has_method("is_breached") and placeable.is_breached():
			continue
		preferred_structures.append(placeable)

	return preferred_structures


func _get_all_structure_targets() -> Array:
	var structures: Array = []
	for socket in _wave_sockets:
		if is_instance_valid(socket) and _is_structure_target(socket) and not (socket.has_method("is_breached") and socket.is_breached()):
			structures.append(socket)
	for placeable in get_tree().get_nodes_in_group("placeables"):
		if not is_instance_valid(placeable):
			continue
		if not placeable.has_method("get_placeable_id"):
			continue
		if placeable.has_method("is_breached") and placeable.is_breached():
			continue
		structures.append(placeable)
	return structures


func _get_closest_structure_from_list(structure_list: Array):
	var closest_structure = null
	var best_distance := INF

	for structure in structure_list:
		if not is_instance_valid(structure):
			continue

		var distance := global_position.distance_squared_to(structure.global_position)
		if distance < best_distance:
			best_distance = distance
			closest_structure = structure

	return closest_structure


func _is_structure_target(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	return target.is_in_group("defense_sockets") or target.is_in_group("placeables")


func _is_target_in_damage_range(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	if _is_structure_target(target):
		return global_position.distance_to(_get_target_point(target)) <= _get_structure_damage_range_estimate()

	if attack_range_override > 0.0:
		return global_position.distance_to(_get_target_point(target)) <= attack_range_override

	if target is PhysicsBody2D:
		return damage_area.overlaps_body(target)

	if target is Area2D:
		return damage_area.overlaps_area(target)

	return false


func _try_damage_target(target) -> bool:
	if not _can_execute_attack(target):
		return false

	var damage_amount := _get_damage_amount_for_target(target)
	if _is_structure_target(target):
		target.take_damage(damage_amount, {
			"attacker": self,
			"damage_type": structure_damage_type,
		})
	else:
		target.take_damage(damage_amount, {
			"attacker": self,
			"damage_type": structure_damage_type,
			"knockback_force": player_knockback_force,
			"knockback_direction": _facing_direction,
		})
	_play_attack_flash()
	return true


func _can_execute_attack(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	if not target.has_method("take_damage"):
		return false

	if not _is_target_in_damage_range(target):
		return false

	if _is_structure_target(target):
		return true

	if not _has_clear_attack_path(target):
		return false

	if not _is_facing_target_for_attack(target):
		return false

	return true


func _can_begin_attack_prep(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	if not target.has_method("take_damage"):
		return false

	if not _is_target_in_damage_range(target):
		return false

	if _is_structure_target(target):
		return true

	if not _is_facing_target_for_attack(target):
		return false

	if target.is_in_group("player") and _is_player_body_touching(target):
		return true

	return _has_clear_attack_path(target)


func _is_player_obstructing(primary_target) -> bool:
	var live_player = _get_live_player()
	if not _should_attack_obstructing_player() or live_player == null:
		return false

	if primary_target == live_player:
		return true

	if not _is_target_in_damage_range(live_player):
		return false

	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		if collision == null:
			continue

		if collision.get_collider() == live_player:
			return true

	return _is_player_between_target(primary_target)


func _get_damage_amount_for_target(target) -> int:
	if target != null and target.is_in_group("player"):
		return player_damage

	return structure_damage


func _apply_definition() -> void:
	if definition == null:
		return

	enemy_id = definition.enemy_id
	body_visual.color = definition.body_color
	_base_color = definition.body_color
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
	if definition.is_elite:
		elite_aura.visible = true
		var aura_color := definition.body_color.lerp(Color(1.0, 0.84, 0.34, 1.0), 0.5)
		elite_aura.color = Color(aura_color.r, aura_color.g, aura_color.b, 0.46)
		facing_marker.color = Color(1.0, 0.9, 0.52, 1.0)
	else:
		elite_aura.visible = false
		elite_aura.color = _base_elite_aura_color
		facing_marker.color = _base_facing_marker_color
	_refresh_health_bar()


func _refresh_health_bar() -> void:
	if health_bar_background == null or health_bar_fill == null:
		return

	var max_health_value: int = max(max_health, 1)
	var health_ratio: float = clamp(float(current_health) / float(max_health_value), 0.0, 1.0)
	health_bar_background.visible = max_health_value > 0
	health_bar_fill.visible = health_ratio > 0.0
	if not health_bar_fill.visible:
		return

	var fill_width: float = lerpf(0.0, HEALTH_BAR_FILL_HALF_WIDTH * 2.0, health_ratio)
	var left_x: float = -HEALTH_BAR_FILL_HALF_WIDTH
	var right_x: float = left_x + fill_width
	health_bar_fill.polygon = PackedVector2Array([
		Vector2(left_x, -HEALTH_BAR_FILL_HALF_HEIGHT),
		Vector2(right_x, -HEALTH_BAR_FILL_HALF_HEIGHT),
		Vector2(right_x, HEALTH_BAR_FILL_HALF_HEIGHT),
		Vector2(left_x, HEALTH_BAR_FILL_HALF_HEIGHT),
	])
	health_bar_fill.color = Color(
		lerpf(0.92, 0.3, health_ratio),
		lerpf(0.24, 0.92, health_ratio),
		0.28,
		0.96
	)


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
	if source == null or typeof(source) != TYPE_DICTIONARY:
		return
	if not bool(source.get("interrupt_attack_prep", false)):
		return
	if not _attack_prep_armed:
		return
	_reset_attack_prep()


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


func _is_under_knockback() -> bool:
	return _knockback_velocity.length_squared() > 0.01


func _resolve_damage_taken(base_damage: int, source: Variant) -> int:
	var damage_type := StringName(&"melee")
	if source is Dictionary:
		damage_type = StringName(source.get("damage_type", &"melee"))

	if definition != null:
		return int(definition.compute_damage_taken(base_damage, damage_type))

	var reduced_damage: int = max(base_damage - defense_flat_reduction, 0)
	return max(int(round(reduced_damage * defense_multiplier)), 0)


func _is_player_between_target(primary_target) -> bool:
	if primary_target == null or not is_instance_valid(primary_target):
		return false

	var live_player = _get_live_player()
	if live_player == null:
		return false

	var target_vector: Vector2 = _get_target_point(primary_target) - global_position
	var player_vector: Vector2 = live_player.global_position - global_position
	var target_length := target_vector.length()
	if target_length <= 0.001:
		return false

	var target_direction := target_vector / target_length
	var projection := player_vector.dot(target_direction)
	if projection < 0.0 or projection > target_length:
		return false

	var closest_point := global_position + target_direction * projection
	if closest_point.distance_to(live_player.global_position) > _get_obstruction_width():
		return false

	return _has_clear_line_to_target(live_player, true)


func _get_live_player():
	_refresh_player_reference()
	if _player_ref == null or not is_instance_valid(_player_ref) or _player_ref.is_dead:
		return null
	return _player_ref


func _update_player_chase_state() -> void:
	var live_player = _get_live_player()
	var was_alerted := _is_alerted_to_player
	var was_chasing := _is_chasing_player
	if live_player == null:
		_is_chasing_player = false
		_is_alerted_to_player = false
		if was_alerted or was_chasing:
			_reset_attack_prep()
		return

	var distance_to_player: float = global_position.distance_to(live_player.global_position)
	if _is_player_body_touching(live_player):
		_alert_to_player(live_player)

	if _is_alerted_to_player:
		_is_chasing_player = distance_to_player <= _get_player_chase_break_radius()
		if not _is_chasing_player:
			_is_alerted_to_player = false
			_reset_attack_prep()
		return

	if not _should_chase_player_when_nearby() or not _can_detect_player_for_chase(live_player):
		_is_chasing_player = false
		if was_alerted or was_chasing:
			_is_alerted_to_player = false
			_reset_attack_prep()
		return

	if _is_chasing_player:
		_is_chasing_player = distance_to_player <= _get_player_chase_break_radius()
		return

	if _has_active_noise_investigation() and _noise_investigation_detect_delay_remaining > 0.0:
		_is_chasing_player = false
		return

	if distance_to_player <= _get_player_detection_radius():
		_alert_to_player(live_player)
		_is_chasing_player = true


func _has_active_noise_investigation() -> bool:
	return _is_investigating_noise and _noise_investigation_remaining > 0.0


func _clear_noise_investigation() -> void:
	_is_investigating_noise = false
	_noise_investigation_position = Vector2.ZERO
	_noise_investigation_remaining = 0.0
	_noise_investigation_detect_delay_remaining = 0.0


func _get_noise_investigation_duration() -> float:
	return 3.0


func _get_noise_investigation_detect_delay() -> float:
	return 0.45


func receive_noise_alert(player_ref, source_position: Vector2) -> void:
	if _behavior_context != &"exploration" or _is_exploration_suspended:
		return
	if _is_alerted_to_player or _is_chasing_player:
		return
	if player_ref != null and is_instance_valid(player_ref):
		_player_ref = player_ref
	_is_investigating_noise = true
	_noise_investigation_position = source_position
	_noise_investigation_remaining = _get_noise_investigation_duration()
	_noise_investigation_detect_delay_remaining = _get_noise_investigation_detect_delay()
	_update_facing_direction(source_position - global_position)


func _process_attack_prep(attack_target) -> bool:
	if _damage_cooldown_remaining > 0.0:
		_reset_attack_prep()
		return false

	if not _can_begin_attack_prep(attack_target):
		if _attack_prep_armed and _attack_prep_lost_target_grace_remaining > 0.0:
			return _attack_prep_remaining > 0.0
		_reset_attack_prep()
		return false

	var target_id: int = attack_target.get_instance_id()
	if not _attack_prep_armed or _attack_prep_target_id != target_id:
		_attack_prep_armed = true
		_attack_prep_target_id = target_id
		_attack_prep_remaining = _get_attack_prep_time()

	_attack_prep_lost_target_grace_remaining = 0.08
	return _attack_prep_remaining > 0.0


func _reset_attack_prep() -> void:
	_attack_prep_armed = false
	_attack_prep_remaining = 0.0
	_attack_prep_target_id = 0
	_attack_prep_lost_target_grace_remaining = 0.0
	if _damage_cooldown_remaining <= 0.0:
		attack_flash.visible = false
		attack_flash.scale = Vector2.ONE
		attack_flash.modulate = Color(
			_get_attack_tell_color().r,
			_get_attack_tell_color().g,
			_get_attack_tell_color().b,
			_get_attack_tell_start_alpha()
		)


func _update_attack_prep_visual() -> void:
	if _damage_cooldown_remaining > 0.0:
		return

	if not _attack_prep_armed:
		attack_flash.visible = false
		attack_flash.scale = Vector2.ONE
		attack_flash.modulate = Color(
			_get_attack_tell_color().r,
			_get_attack_tell_color().g,
			_get_attack_tell_color().b,
			_get_attack_tell_start_alpha()
		)
		return

	var tell_lead_time := _get_attack_tell_lead_time()
	if tell_lead_time <= 0.0 or _attack_prep_remaining > tell_lead_time:
		attack_flash.visible = false
		return

	var progress: float = clamp(1.0 - (_attack_prep_remaining / tell_lead_time), 0.0, 1.0)
	attack_flash.visible = true
	var tell_color := _get_attack_tell_color()
	var start_scale := _get_attack_tell_start_scale()
	var ready_scale := _get_attack_tell_ready_scale()
	attack_flash.scale = start_scale.lerp(ready_scale, progress)
	attack_flash.modulate = Color(
		tell_color.r,
		tell_color.g,
		tell_color.b,
		lerpf(_get_attack_tell_start_alpha(), _get_attack_tell_ready_alpha(), progress)
	)


func _alert_to_player_from_source(source: Variant) -> void:
	var live_player = _get_live_player()
	if live_player == null:
		return

	if source is Dictionary:
		var attacker = source.get("attacker")
		if attacker != null and is_instance_valid(attacker) and attacker.is_in_group("player"):
			_player_ref = attacker
			_alert_to_player(attacker)


func _is_player_body_touching(player_target) -> bool:
	if player_target == null or not is_instance_valid(player_target):
		return false
	if body_touch_area == null:
		return false

	return body_touch_area.overlaps_body(player_target)


func _refresh_player_reference() -> void:
	if _player_ref != null and is_instance_valid(_player_ref) and not _player_ref.is_dead:
		return

	var candidate = get_tree().get_first_node_in_group("player")
	if candidate != null and is_instance_valid(candidate):
		_player_ref = candidate


func _decay_knockback(delta: float) -> void:
	if _knockback_velocity.is_zero_approx():
		_knockback_velocity = Vector2.ZERO
		return

	var decayed_speed := move_toward(_knockback_velocity.length(), 0.0, knockback_decay * delta)
	if decayed_speed <= 0.01:
		_knockback_velocity = Vector2.ZERO
		return

	_knockback_velocity = _knockback_velocity.normalized() * decayed_speed


func _get_target_mode_for_context() -> int:
	if definition == null:
		if _behavior_context == &"wave":
			return EnemyDefinitionResource.WaveTargetMode.SOCKET_THEN_PLAYER
		return EnemyDefinitionResource.WaveTargetMode.PLAYER_ONLY

	if _behavior_context == &"wave":
		return definition.wave_target_mode
	return definition.exploration_target_mode


func _does_chase_override_target_mode(target_mode: int) -> bool:
	if definition == null:
		return (
			target_mode == EnemyDefinitionResource.WaveTargetMode.PLAYER_THEN_SOCKET
			or target_mode == EnemyDefinitionResource.WaveTargetMode.PLAYER_ONLY
		)

	if definition.chase_overrides_target_mode:
		return true

	return (
		target_mode == EnemyDefinitionResource.WaveTargetMode.PLAYER_THEN_SOCKET
		or target_mode == EnemyDefinitionResource.WaveTargetMode.PLAYER_ONLY
	)


func _should_fallback_to_player_when_no_sockets() -> bool:
	if definition == null:
		return true
	return definition.fallback_to_player_when_no_sockets


func _should_chase_player_when_nearby() -> bool:
	if definition == null:
		return true
	return definition.chase_player_when_nearby


func _should_idle_until_player_detected() -> bool:
	if definition == null:
		return false
	return definition.idle_until_player_detected


func _get_player_detection_radius() -> float:
	if definition == null:
		return 88.0
	return definition.player_detection_radius


func _should_alert_nearby_enemies() -> bool:
	if definition == null:
		return true
	return definition.alert_nearby_enemies


func _get_ally_alert_radius() -> float:
	if definition == null:
		return 84.0
	return definition.ally_alert_radius


func _get_player_chase_break_radius() -> float:
	if definition == null:
		return 128.0
	return definition.player_chase_break_radius


func _get_attack_prep_time() -> float:
	if definition == null:
		return attack_prep_time
	return definition.attack_prep_time


func _should_attack_obstructing_player() -> bool:
	if definition == null:
		return true
	return definition.attack_player_when_obstructing


func _should_attack_player_on_contact() -> bool:
	if definition == null:
		return true
	return definition.attack_player_on_contact


func _get_obstruction_width() -> float:
	if definition == null:
		return 18.0
	return definition.obstruction_width


func _get_separation_radius() -> float:
	if definition == null:
		return 30.0
	return definition.separation_radius


func _get_separation_weight() -> float:
	if definition == null:
		return 1.0
	return definition.separation_weight


func _get_sidestep_weight() -> float:
	if definition == null:
		return 0.9
	return definition.sidestep_weight


func _get_attack_facing_dot_threshold() -> float:
	if definition == null:
		return 0.25
	return definition.attack_facing_dot_threshold


func _get_attack_tell_color() -> Color:
	if definition == null:
		return Color(1.0, 0.82, 0.42, 0.72)
	return definition.attack_tell_color


func _get_attack_tell_start_scale() -> Vector2:
	if definition == null:
		return Vector2(0.62, 0.62)
	return definition.attack_tell_start_scale


func _get_attack_tell_ready_scale() -> Vector2:
	if definition == null:
		return Vector2(0.98, 0.98)
	return definition.attack_tell_ready_scale


func _get_attack_tell_start_alpha() -> float:
	if definition == null:
		return 0.18
	return definition.attack_tell_start_alpha


func _get_attack_tell_ready_alpha() -> float:
	if definition == null:
		return 0.72
	return definition.attack_tell_ready_alpha


func _get_attack_tell_lead_time() -> float:
	var prep_time := _get_attack_prep_time()
	if definition == null:
		return min(0.3, prep_time)
	return min(definition.attack_tell_lead_time, prep_time)


func _get_attack_flash_peak_scale() -> Vector2:
	if definition == null:
		return Vector2(1.08, 1.08)
	return definition.attack_flash_peak_scale


func _get_attack_flash_start_scale() -> Vector2:
	if definition == null:
		return Vector2(0.78, 0.78)
	return definition.attack_flash_start_scale


func _get_attack_strike_color() -> Color:
	if definition == null:
		return Color(1.0, 0.98, 0.86, 0.98)
	return definition.attack_strike_color


func _get_attack_flash_duration() -> float:
	if definition == null:
		return 0.08
	return definition.attack_flash_duration


func _get_detection_facing_dot_threshold() -> float:
	if definition == null:
		return 0.0
	return definition.detection_facing_dot_threshold


func _is_facing_target_for_detection(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	var to_target: Vector2 = _get_target_point(target) - global_position
	if to_target.is_zero_approx():
		return true

	var target_direction: Vector2 = to_target.normalized()
	return _facing_direction.dot(target_direction) >= _get_detection_facing_dot_threshold()


func _is_facing_target_for_attack(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	var to_target: Vector2 = target.global_position - global_position
	if to_target.is_zero_approx():
		return true

	var target_direction: Vector2 = to_target.normalized()
	return _facing_direction.dot(target_direction) >= _get_attack_facing_dot_threshold()


func _can_detect_player_for_chase(player_target) -> bool:
	if player_target == null or not is_instance_valid(player_target):
		return false

	if not _is_facing_target_for_detection(player_target):
		return false

	return _has_clear_line_to_target(player_target, true)


func _has_clear_line_to_target(target, ignore_other_enemies: bool = false) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	return _has_clear_line_to_point(target, target.global_position, ignore_other_enemies)


func _has_clear_line_to_point(target, target_point: Vector2, ignore_other_enemies: bool = false) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	var query := PhysicsRayQueryParameters2D.create(global_position, target_point)
	query.exclude = [self]
	if ignore_other_enemies:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy == self or enemy == target or not is_instance_valid(enemy):
				continue
			query.exclude.append(enemy)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true

	return hit.get("collider") == target


func _get_enemy_separation_vector() -> Vector2:
	var radius := _get_separation_radius()
	if radius <= 0.0:
		return Vector2.ZERO

	var push := Vector2.ZERO
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == self or not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		if not enemy.visible:
			continue

		var offset: Vector2 = global_position - enemy.global_position
		var distance := offset.length()
		if distance <= 0.001 or distance >= radius:
			continue

		push += offset.normalized() * ((radius - distance) / radius)

	if push.is_zero_approx():
		return Vector2.ZERO

	return push.normalized()


func _get_enemy_block_sidestep(primary_target, target_offset: Vector2) -> Vector2:
	if primary_target == null or not is_instance_valid(primary_target):
		return Vector2.ZERO

	var blocker = _get_enemy_blocking_path(primary_target)
	if blocker == null:
		return Vector2.ZERO

	var forward := target_offset.normalized()
	var blocker_offset: Vector2 = blocker.global_position - global_position
	var cross := 0.0
	if not blocker_offset.is_zero_approx():
		cross = forward.cross(blocker_offset.normalized())

	var side_sign := 1.0 if int(get_instance_id()) % 2 == 0 else -1.0
	if abs(cross) > 0.01:
		side_sign = -sign(cross)

	return forward.orthogonal() * side_sign


func _get_enemy_blocking_path(primary_target):
	if primary_target == null or not is_instance_valid(primary_target):
		return null

	var target_point := _get_target_point(primary_target)
	var query := PhysicsRayQueryParameters2D.create(global_position, target_point)
	query.exclude = [self, primary_target]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null

	var collider = hit.get("collider")
	if collider != null and is_instance_valid(collider) and collider.is_in_group("enemies"):
		if not (collider is Node2D):
			return null
		if collider.global_position.distance_to(target_point) > _get_damage_range_estimate() * 1.25:
			return null
		return collider

	return null


func _has_clear_attack_path(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	if target.is_in_group("defense_sockets"):
		return _has_clear_structure_attack_path(target)

	return _has_clear_line_to_point(target, _get_target_point(target), false)


func _get_target_point(target) -> Vector2:
	if target == null or not is_instance_valid(target):
		return global_position

	if target.has_method("get_attack_aim_point"):
		return target.get_attack_aim_point(global_position)

	return target.global_position


func _has_clear_structure_attack_path(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	return true


func _get_damage_range_estimate() -> float:
	if damage_area == null:
		return attack_range_override if attack_range_override > 0.0 else 18.0

	var area_shape: CollisionShape2D = damage_area.get_node_or_null("CollisionShape2D")
	if area_shape == null or area_shape.shape == null:
		return attack_range_override if attack_range_override > 0.0 else 18.0

	if area_shape.shape is CircleShape2D:
		return max(area_shape.shape.radius, attack_range_override)

	return attack_range_override if attack_range_override > 0.0 else 18.0


func _get_structure_damage_range_estimate() -> float:
	if structure_attack_range_override > 0.0:
		return structure_attack_range_override
	return _get_damage_range_estimate()


func _alert_to_player(player_ref, propagate: bool = true) -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return

	_player_ref = player_ref
	_clear_noise_investigation()
	var was_alerted := _is_alerted_to_player
	_is_alerted_to_player = true
	_is_chasing_player = true
	if not was_alerted and propagate:
		_alert_nearby_enemies(player_ref)


func _alert_nearby_enemies(player_ref) -> void:
	if not _should_alert_nearby_enemies():
		return

	var alert_radius := _get_ally_alert_radius()
	if alert_radius <= 0.0:
		return

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == self or not is_instance_valid(enemy):
			continue
		if not (enemy is Zombie):
			continue
		if enemy.global_position.distance_to(global_position) > alert_radius:
			continue

		enemy.receive_ally_alert(player_ref)


func receive_ally_alert(player_ref) -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return
	_alert_to_player(player_ref, false)


func _spawn_death_drop() -> void:
	if definition == null:
		return

	var drop_parent: Node = get_parent()
	var scene_tree := get_tree()
	var current_scene := scene_tree.current_scene if scene_tree != null else null
	var world_node = current_scene.get_node_or_null("World") if current_scene != null else null
	if world_node != null:
		drop_parent = world_node

	if drop_parent == null:
		return

	var drop_entries: Array[Dictionary] = []
	var salvage_amount: int = maxi(int(definition.drop_salvage), 0)
	if salvage_amount > 0:
		if definition.bonus_salvage > 0 and randf() < definition.bonus_salvage_chance:
			salvage_amount += definition.bonus_salvage
		drop_entries.append({"resource_id": "salvage", "amount": salvage_amount})
	if definition.drop_parts > 0:
		drop_entries.append({"resource_id": "parts", "amount": definition.drop_parts})
	if definition.drop_bullets > 0:
		drop_entries.append({"resource_id": "bullets", "amount": definition.drop_bullets})
	if definition.drop_food > 0:
		drop_entries.append({"resource_id": "food", "amount": definition.drop_food})

	for drop_entry in drop_entries:
		var pickup = ResourcePickupScene.instantiate()
		pickup.resource_id = String(drop_entry.get("resource_id", "salvage"))
		pickup.amount = int(drop_entry.get("amount", 1))
		drop_parent.add_child(pickup)
		pickup.global_position = global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0))

	if definition.is_elite and definition.weapon_drop != null and definition.weapon_drop_chance > 0.0 and randf() <= definition.weapon_drop_chance:
		var weapon_pickup = ResourcePickupScene.instantiate()
		weapon_pickup.is_weapon_drop = true
		weapon_pickup.weapon_reward = definition.weapon_drop
		drop_parent.add_child(weapon_pickup)
		weapon_pickup.global_position = global_position + Vector2(0.0, -14.0)


func _flash_body(flash_color: Color) -> void:
	body_visual.color = flash_color
	var tween := create_tween()
	tween.tween_property(body_visual, "color", _base_color, 0.12)


func _play_damage_feedback(source: Variant) -> void:
	if _damage_feedback_tween != null and is_instance_valid(_damage_feedback_tween):
		_damage_feedback_tween.kill()

	var knock_direction := _get_damage_knock_direction(source)
	body_visual.position = knock_direction * 4.0
	body_visual.scale = Vector2(1.06, 0.94)
	facing_marker.position = knock_direction * 4.0
	facing_marker.scale = Vector2(1.06, 0.94)

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


func _play_attack_flash() -> void:
	attack_flash.visible = true
	attack_flash.scale = _get_attack_flash_start_scale()
	var strike_color := _get_attack_strike_color()
	attack_flash.modulate = Color(strike_color.r, strike_color.g, strike_color.b, 1.0)
	var tween := create_tween()
	tween.parallel().tween_property(attack_flash, "scale", _get_attack_flash_peak_scale(), _get_attack_flash_duration())
	tween.parallel().tween_property(attack_flash, "modulate:a", 0.0, _get_attack_flash_duration())
	tween.finished.connect(func() -> void:
		attack_flash.visible = false
		attack_flash.scale = Vector2.ONE
		attack_flash.modulate = Color(
			_get_attack_tell_color().r,
			_get_attack_tell_color().g,
			_get_attack_tell_color().b,
			_get_attack_tell_start_alpha()
		)
	)
