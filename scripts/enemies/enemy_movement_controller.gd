extends Node
class_name GameEnemyMovementController


var enemy: GameEnemy


func configure(enemy_ref: GameEnemy) -> void:
	enemy = enemy_ref


func is_under_knockback() -> bool:
	return enemy._knockback_velocity.length_squared() > 0.01


func decay_knockback(delta: float) -> void:
	if enemy._knockback_velocity.is_zero_approx():
		enemy._knockback_velocity = Vector2.ZERO
		return

	var decayed_speed := move_toward(enemy._knockback_velocity.length(), 0.0, enemy.knockback_decay * delta)
	if decayed_speed <= 0.01:
		enemy._knockback_velocity = Vector2.ZERO
		return

	enemy._knockback_velocity = enemy._knockback_velocity.normalized() * decayed_speed


func compute_move_velocity(primary_target) -> Vector2:
	if primary_target == null or not is_instance_valid(primary_target):
		return Vector2.ZERO

	var target_offset: Vector2 = enemy.combat_controller.get_target_point(primary_target) - enemy.global_position
	if target_offset.is_zero_approx():
		return Vector2.ZERO

	var move_direction := target_offset.normalized()
	var separation := get_enemy_separation_vector()
	if not separation.is_zero_approx():
		move_direction += separation * get_separation_weight()

	var dog_avoidance := get_dog_avoidance_vector()
	if not dog_avoidance.is_zero_approx():
		move_direction += dog_avoidance * get_dog_avoidance_weight()

	var sidestep := get_enemy_block_sidestep(primary_target, target_offset)
	if not sidestep.is_zero_approx():
		move_direction += sidestep * get_sidestep_weight()

	if move_direction.is_zero_approx():
		return Vector2.ZERO

	return move_direction.normalized() * enemy.move_speed * enemy._slow_effect_multiplier


func is_player_obstructing(primary_target) -> bool:
	var live_player = enemy.runtime_controller.get_live_player()
	if not enemy.combat_controller.should_attack_obstructing_player() or live_player == null:
		return false

	if primary_target == live_player:
		return true

	if not enemy.combat_controller.is_target_in_damage_range(live_player):
		return false

	for collision_index in enemy.get_slide_collision_count():
		var collision: KinematicCollision2D = enemy.get_slide_collision(collision_index)
		if collision == null:
			continue
		if collision.get_collider() == live_player:
			return true

	return is_player_between_target(primary_target)


func is_player_between_target(primary_target) -> bool:
	if primary_target == null or not is_instance_valid(primary_target):
		return false

	var live_player = enemy.runtime_controller.get_live_player()
	if live_player == null:
		return false

	var target_vector: Vector2 = enemy.combat_controller.get_target_point(primary_target) - enemy.global_position
	var player_vector: Vector2 = live_player.global_position - enemy.global_position
	var target_length := target_vector.length()
	if target_length <= 0.001:
		return false

	var target_direction := target_vector / target_length
	var projection := player_vector.dot(target_direction)
	if projection < 0.0 or projection > target_length:
		return false

	var closest_point: Vector2 = enemy.global_position + target_direction * projection
	if closest_point.distance_to(live_player.global_position) > get_obstruction_width():
		return false

	return enemy.targeting_controller.has_clear_line_to_target(live_player, true)


func get_obstruction_width() -> float:
	if enemy.definition == null:
		return 18.0
	return enemy.definition.obstruction_width


func get_separation_radius() -> float:
	if enemy.definition == null:
		return 30.0
	return enemy.definition.separation_radius


func get_separation_weight() -> float:
	if enemy.definition == null:
		return 1.0
	return enemy.definition.separation_weight


func get_sidestep_weight() -> float:
	if enemy.definition == null:
		return 0.9
	return enemy.definition.sidestep_weight


func get_dog_avoidance_weight() -> float:
	return 1.2


func get_enemy_separation_vector() -> Vector2:
	var radius := get_separation_radius()
	if radius <= 0.0:
		return Vector2.ZERO

	var push := Vector2.ZERO
	for other_enemy in enemy.runtime_controller.get_local_enemy_nodes():
		if other_enemy == enemy or not is_instance_valid(other_enemy):
			continue
		if not (other_enemy is Node2D):
			continue
		if not other_enemy.visible:
			continue

		var offset: Vector2 = enemy.global_position - other_enemy.global_position
		var distance := offset.length()
		if distance <= 0.001 or distance >= radius:
			continue

		push += offset.normalized() * ((radius - distance) / radius)

	if push.is_zero_approx():
		return Vector2.ZERO

	return push.normalized()


func get_dog_avoidance_vector() -> Vector2:
	var scene_tree := enemy.get_tree()
	if scene_tree == null:
		return Vector2.ZERO
	var radius := 28.0
	var push := Vector2.ZERO
	for dog in scene_tree.get_nodes_in_group("dog_companion"):
		if dog == null or not is_instance_valid(dog):
			continue
		if not (dog is Node2D):
			continue
		if not dog.visible:
			continue
		var offset: Vector2 = enemy.global_position - dog.global_position
		var distance := offset.length()
		if distance <= 0.001 or distance >= radius:
			continue
		push += offset.normalized() * ((radius - distance) / radius)
	if push.is_zero_approx():
		return Vector2.ZERO
	return push.normalized()


func get_enemy_block_sidestep(primary_target, target_offset: Vector2) -> Vector2:
	if primary_target == null or not is_instance_valid(primary_target):
		return Vector2.ZERO

	var blocker = get_enemy_blocking_path(primary_target)
	if blocker == null:
		return Vector2.ZERO

	var forward := target_offset.normalized()
	var blocker_offset: Vector2 = blocker.global_position - enemy.global_position
	var cross := 0.0
	if not blocker_offset.is_zero_approx():
		cross = forward.cross(blocker_offset.normalized())

	var side_sign := 1.0 if int(enemy.get_instance_id()) % 2 == 0 else -1.0
	if abs(cross) > 0.01:
		side_sign = -sign(cross)

	return forward.orthogonal() * side_sign


func get_enemy_blocking_path(primary_target):
	if primary_target == null or not is_instance_valid(primary_target):
		return null

	var target_point: Vector2 = enemy.combat_controller.get_target_point(primary_target)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(enemy.global_position, target_point)
	query.exclude = [enemy, primary_target]
	var hit: Dictionary = enemy.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null

	var collider = hit.get("collider")
	if collider != null and is_instance_valid(collider) and collider.is_in_group("enemies"):
		if not (collider is Node2D):
			return null
		if collider.global_position.distance_to(target_point) > enemy.combat_controller.get_damage_range_estimate() * 1.25:
			return null
		return collider

	return null
