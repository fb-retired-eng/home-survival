extends Node
class_name EnemyTargetingController

const EnemyDefinitionResource = preload("res://scripts/data/enemy_definition.gd")
const CHASE_LOST_SIGHT_DISTANCE_FACTOR := 1.25
const CHASE_LOST_SIGHT_DISTANCE_PADDING := 20.0
const CHASE_SCREEN_MARGIN := 48.0
const THREAT_INDICATOR_GRACE_TIME := 0.65

var enemy


func configure(enemy_owner) -> void:
	enemy = enemy_owner


func get_current_target():
	var live_player = enemy.runtime_controller.get_live_player()
	var target_mode := _get_target_mode_for_context()
	if enemy._is_chasing_player and live_player != null and _does_chase_override_target_mode(target_mode):
		return live_player

	if enemy._behavior_context != &"wave" and _should_idle_until_player_detected() and not enemy._is_chasing_player:
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


func update_player_chase_state() -> void:
	var live_player = enemy.runtime_controller.get_live_player()
	var was_alerted: bool = enemy._is_alerted_to_player
	var was_chasing: bool = enemy._is_chasing_player
	if live_player == null:
		enemy._is_chasing_player = false
		enemy._is_alerted_to_player = false
		if was_alerted or was_chasing:
			enemy.combat_controller.reset_attack_prep()
		return

	var distance_to_player: float = enemy.global_position.distance_to(live_player.global_position)
	var can_detect_player: bool = can_detect_player_for_chase(live_player)
	if enemy.runtime_controller.is_player_body_touching(live_player):
		alert_to_player(live_player)
		can_detect_player = true

	if enemy._is_alerted_to_player:
		var blind_pursuit_break_radius := _get_player_lost_sight_break_radius()
		var is_within_screen_chase_rect := _is_within_player_screen_chase_rect(live_player, CHASE_SCREEN_MARGIN)
		var screen_detect_keep_radius := get_player_screen_detect_keep_radius()
		var screen_blind_keep_radius := get_player_screen_blind_keep_radius()
		if can_detect_player:
			enemy._is_chasing_player = distance_to_player <= get_player_chase_break_radius() or (
				is_within_screen_chase_rect and distance_to_player <= screen_detect_keep_radius
			)
		elif distance_to_player <= get_player_detection_radius():
			enemy._is_chasing_player = true
		elif is_within_screen_chase_rect and distance_to_player <= screen_blind_keep_radius:
			enemy._is_chasing_player = true
		else:
			enemy._is_chasing_player = distance_to_player <= blind_pursuit_break_radius
		if not enemy._is_chasing_player:
			enemy._is_alerted_to_player = false
			enemy.combat_controller.reset_attack_prep()
		return

	if not _should_chase_player_when_nearby() or not can_detect_player:
		enemy._is_chasing_player = false
		if was_alerted or was_chasing:
			enemy._is_alerted_to_player = false
			enemy.combat_controller.reset_attack_prep()
		return

	if enemy._is_chasing_player:
		enemy._is_chasing_player = distance_to_player <= get_player_chase_break_radius()
		return

	if has_active_noise_investigation() and enemy._noise_investigation_detect_delay_remaining > 0.0:
		enemy._is_chasing_player = false
		return

	if distance_to_player <= get_player_detection_radius():
		alert_to_player(live_player)
		enemy._is_chasing_player = true


func has_active_noise_investigation() -> bool:
	return enemy._is_investigating_noise and enemy._noise_investigation_remaining > 0.0


func clear_noise_investigation() -> void:
	enemy._is_investigating_noise = false
	enemy._noise_investigation_position = Vector2.ZERO
	enemy._noise_investigation_remaining = 0.0
	enemy._noise_investigation_detect_delay_remaining = 0.0


func receive_noise_alert(player_ref, source_position: Vector2) -> void:
	if enemy._behavior_context != &"exploration" or enemy._is_exploration_suspended:
		return
	if enemy._is_alerted_to_player or enemy._is_chasing_player:
		return
	if player_ref != null and is_instance_valid(player_ref):
		enemy._player_ref = player_ref
	enemy._is_investigating_noise = true
	enemy._noise_investigation_position = source_position
	enemy._noise_investigation_remaining = 3.0
	enemy._noise_investigation_detect_delay_remaining = 0.45
	enemy._threat_indicator_grace_remaining = maxf(enemy._threat_indicator_grace_remaining, THREAT_INDICATOR_GRACE_TIME)
	enemy._update_facing_direction(source_position - enemy.global_position)


func alert_to_player_from_source(source: Variant) -> void:
	var live_player = enemy.runtime_controller.get_live_player()
	if live_player == null:
		return

	if source is Dictionary:
		var attacker = source.get("attacker")
		if attacker != null and is_instance_valid(attacker) and attacker.is_in_group("player"):
			enemy._player_ref = attacker
			alert_to_player(attacker)


func alert_to_player(player_ref, propagate: bool = true) -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return

	enemy._player_ref = player_ref
	clear_noise_investigation()
	var was_alerted: bool = enemy._is_alerted_to_player
	enemy._is_alerted_to_player = true
	enemy._is_chasing_player = true
	enemy._threat_indicator_grace_remaining = maxf(enemy._threat_indicator_grace_remaining, THREAT_INDICATOR_GRACE_TIME)
	if not was_alerted and propagate:
		_alert_nearby_enemies(player_ref)


func receive_ally_alert(player_ref) -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return
	alert_to_player(player_ref, false)


func get_noise_alert_weight() -> float:
	if enemy.definition == null:
		return 1.0
	return max(float(enemy.definition.noise_alert_weight), 0.0)


func get_player_detection_radius() -> float:
	if enemy.definition == null:
		return 88.0
	return enemy.definition.player_detection_radius


func get_player_chase_break_radius() -> float:
	if enemy.definition == null:
		return 128.0
	return enemy.definition.player_chase_break_radius


func get_player_screen_detect_keep_radius() -> float:
	var chase_break_radius := get_player_chase_break_radius()
	var detection_radius := get_player_detection_radius()
	return maxf(chase_break_radius, minf(chase_break_radius + 32.0, detection_radius + 56.0))


func get_player_screen_blind_keep_radius() -> float:
	var blind_pursuit_radius := _get_player_lost_sight_break_radius()
	var detection_radius := get_player_detection_radius()
	return maxf(blind_pursuit_radius, minf(blind_pursuit_radius + 20.0, detection_radius + 32.0))


func can_detect_player_for_chase(player_target) -> bool:
	if player_target == null or not is_instance_valid(player_target):
		return false

	if not _is_facing_target_for_detection(player_target):
		return false

	return has_clear_line_to_target(player_target, true)


func has_clear_line_to_target(target, ignore_other_enemies: bool = false) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	return has_clear_line_to_point(target, target.global_position, ignore_other_enemies)


func has_clear_line_to_point(target, target_point: Vector2, ignore_other_enemies: bool = false) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	var query := PhysicsRayQueryParameters2D.create(enemy.global_position, target_point)
	query.exclude = [enemy]
	if ignore_other_enemies:
		for other_enemy in enemy.runtime_controller.get_local_enemy_nodes():
			if other_enemy == enemy or other_enemy == target or not is_instance_valid(other_enemy):
				continue
			query.exclude.append(other_enemy)
	var hit: Dictionary = enemy.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true

	return hit.get("collider") == target


func _get_closest_intact_structure():
	var preferred_structures := _get_intact_preferred_structures()
	if not preferred_structures.is_empty():
		return _get_closest_structure_from_list(preferred_structures)

	return _get_closest_structure_from_list(_get_all_structure_targets())


func _get_intact_preferred_structures() -> Array:
	var preferred_structures: Array = []
	if enemy._preferred_socket_ids.is_empty():
		return preferred_structures

	for socket in enemy._wave_sockets:
		if not is_instance_valid(socket):
			continue
		if not enemy.combat_controller.is_structure_target(socket):
			continue
		if not enemy._preferred_socket_ids.has(String(socket.socket_id)):
			continue
		if socket.has_method("is_breached") and socket.is_breached():
			continue
		preferred_structures.append(socket)

	for placeable in enemy.runtime_controller.get_runtime_placeables():
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
	for socket in enemy._wave_sockets:
		if is_instance_valid(socket) and enemy.combat_controller.is_structure_target(socket) and not (socket.has_method("is_breached") and socket.is_breached()):
			structures.append(socket)
	for placeable in enemy.runtime_controller.get_runtime_placeables():
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

		var distance: float = enemy.global_position.distance_squared_to(structure.global_position)
		if distance < best_distance:
			best_distance = distance
			closest_structure = structure

	return closest_structure


func _get_target_mode_for_context() -> int:
	if enemy.definition == null:
		if enemy._behavior_context == &"wave":
			return EnemyDefinitionResource.WaveTargetMode.SOCKET_THEN_PLAYER
		return EnemyDefinitionResource.WaveTargetMode.PLAYER_ONLY

	if enemy._behavior_context == &"wave":
		return enemy.definition.wave_target_mode
	return enemy.definition.exploration_target_mode


func _does_chase_override_target_mode(target_mode: int) -> bool:
	if enemy.definition == null:
		return (
			target_mode == EnemyDefinitionResource.WaveTargetMode.PLAYER_THEN_SOCKET
			or target_mode == EnemyDefinitionResource.WaveTargetMode.PLAYER_ONLY
		)

	if enemy.definition.chase_overrides_target_mode:
		return true

	return (
		target_mode == EnemyDefinitionResource.WaveTargetMode.PLAYER_THEN_SOCKET
		or target_mode == EnemyDefinitionResource.WaveTargetMode.PLAYER_ONLY
	)


func _should_fallback_to_player_when_no_sockets() -> bool:
	if enemy.definition == null:
		return true
	return enemy.definition.fallback_to_player_when_no_sockets


func _should_chase_player_when_nearby() -> bool:
	if enemy.definition == null:
		return true
	return enemy.definition.chase_player_when_nearby


func _should_idle_until_player_detected() -> bool:
	if enemy.definition == null:
		return false
	return enemy.definition.idle_until_player_detected


func _should_alert_nearby_enemies() -> bool:
	if enemy.definition == null:
		return true
	return enemy.definition.alert_nearby_enemies


func _get_ally_alert_radius() -> float:
	if enemy.definition == null:
		return 84.0
	return enemy.definition.ally_alert_radius


func _get_player_lost_sight_break_radius() -> float:
	var detection_radius := get_player_detection_radius()
	var chase_break_radius := get_player_chase_break_radius()
	var blind_pursuit_radius := maxf(
		detection_radius * CHASE_LOST_SIGHT_DISTANCE_FACTOR,
		detection_radius + CHASE_LOST_SIGHT_DISTANCE_PADDING
	)
	return minf(chase_break_radius, blind_pursuit_radius)


func _is_within_player_screen_chase_rect(player_target, margin: float = 0.0) -> bool:
	if player_target == null or not is_instance_valid(player_target):
		return false

	var viewport: Viewport = enemy.get_viewport()
	if viewport == null:
		return false

	var canvas_to_world: Transform2D = viewport.get_canvas_transform().affine_inverse()
	var viewport_rect: Rect2 = viewport.get_visible_rect()
	var screen_world_top_left: Vector2 = canvas_to_world * viewport_rect.position
	var screen_world_bottom_right: Vector2 = canvas_to_world * viewport_rect.end
	var visible_world_size := (screen_world_bottom_right - screen_world_top_left).abs()
	var chase_rect := Rect2(
		player_target.global_position - (visible_world_size * 0.5) - Vector2.ONE * margin,
		visible_world_size + Vector2.ONE * margin * 2.0
	)
	return chase_rect.has_point(enemy.global_position)


func _get_detection_facing_dot_threshold() -> float:
	if enemy.definition == null:
		return 0.0
	return enemy.definition.detection_facing_dot_threshold


func _is_facing_target_for_detection(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	var to_target: Vector2 = enemy.combat_controller.get_target_point(target) - enemy.global_position
	if to_target.is_zero_approx():
		return true

	var target_direction: Vector2 = to_target.normalized()
	return enemy._facing_direction.dot(target_direction) >= _get_detection_facing_dot_threshold()


func _alert_nearby_enemies(player_ref) -> void:
	if not _should_alert_nearby_enemies():
		return

	var alert_radius := _get_ally_alert_radius()
	if alert_radius <= 0.0:
		return

	for other_enemy in enemy.runtime_controller.get_local_enemy_nodes():
		if other_enemy == enemy or not is_instance_valid(other_enemy):
			continue
		if not other_enemy.is_in_group("enemies"):
			continue
		if other_enemy.global_position.distance_to(enemy.global_position) > alert_radius:
			continue
		var other_targeting = other_enemy.get("targeting_controller")
		if other_targeting == null:
			continue
		other_targeting.receive_ally_alert(player_ref)
