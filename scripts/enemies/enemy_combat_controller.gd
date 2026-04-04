extends Node
class_name GameEnemyCombatController

var enemy


func configure(enemy_ref) -> void:
	enemy = enemy_ref


func get_attack_target(primary_target):
	var live_player = enemy.runtime_controller.get_live_player()
	if should_attack_player_on_contact() and live_player != null and enemy.runtime_controller.is_player_body_touching(live_player):
		if primary_target == null or primary_target != live_player:
			return live_player

	if primary_target == null:
		return null

	if enemy._behavior_context == &"wave":
		if should_attack_obstructing_player() and enemy._player_obstructing_this_frame and live_player != null:
			return live_player

	return primary_target


func try_damage_target(target) -> bool:
	if not can_execute_attack(target):
		return false

	if uses_projectile_attack_on_target(target):
		play_attack_flash()
		return spawn_attack_projectile(target)

	var damage_amount: int = get_damage_amount_for_target(target)
	if is_structure_target(target):
		target.take_damage(damage_amount, {
			"attacker": enemy,
			"damage_type": enemy.structure_damage_type,
		})
	else:
		target.take_damage(damage_amount, {
			"attacker": enemy,
			"damage_type": enemy.structure_damage_type,
			"knockback_force": enemy.player_knockback_force,
			"knockback_direction": enemy._facing_direction,
		})
	play_attack_flash()
	enemy._play_combat_sound(&"enemy_attack_hit", randf_range(0.96, 1.05), -1.5)
	return true


func can_execute_attack(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	if not target.has_method("take_damage"):
		return false

	if not is_target_in_damage_range(target):
		return false

	if is_structure_target(target):
		return true

	if not has_clear_attack_path(target):
		return false

	if not is_facing_target_for_attack(target):
		return false

	return true


func can_begin_attack_prep(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	if not target.has_method("take_damage"):
		return false

	if not is_target_in_damage_range(target):
		return false

	if is_structure_target(target):
		return true

	if not is_facing_target_for_attack(target):
		return false

	if target.is_in_group("player") and enemy.runtime_controller.is_player_body_touching(target):
		return true

	return has_clear_attack_path(target)


func apply_attack_interrupt_from_source(source: Variant) -> void:
	if source == null or typeof(source) != TYPE_DICTIONARY:
		return
	if not bool(source.get("interrupt_attack_prep", false)):
		return
	if not enemy._attack_prep_armed:
		return
	reset_attack_prep()


func process_attack_prep(attack_target) -> bool:
	if enemy._damage_cooldown_remaining > 0.0:
		reset_attack_prep()
		return false

	if not can_begin_attack_prep(attack_target):
		if enemy._attack_prep_armed and enemy._attack_prep_lost_target_grace_remaining > 0.0:
			return enemy._attack_prep_remaining > 0.0
		reset_attack_prep()
		return false

	var target_id: int = attack_target.get_instance_id()
	if not enemy._attack_prep_armed or enemy._attack_prep_target_id != target_id:
		enemy._attack_prep_armed = true
		enemy._attack_prep_target_id = target_id
		enemy._attack_prep_remaining = get_attack_prep_time()
		enemy._play_combat_sound(&"enemy_attack_tell", randf_range(0.94, 1.03), -5.0)

	enemy._attack_prep_lost_target_grace_remaining = 0.08
	return enemy._attack_prep_remaining > 0.0


func reset_attack_prep() -> void:
	enemy._attack_prep_armed = false
	enemy._attack_prep_remaining = 0.0
	enemy._attack_prep_target_id = 0
	enemy._attack_prep_lost_target_grace_remaining = 0.0
	if enemy._damage_cooldown_remaining <= 0.0:
		enemy.attack_tell.visible = false
		enemy.attack_tell.position = Vector2.ZERO
		enemy.attack_tell.scale = Vector2.ONE
		enemy.attack_tell.modulate = Color(
			enemy.presentation_controller.get_attack_tell_color().r,
			enemy.presentation_controller.get_attack_tell_color().g,
			enemy.presentation_controller.get_attack_tell_color().b,
			enemy.presentation_controller.get_attack_tell_start_alpha()
		)
		enemy.attack_flash.visible = false
		enemy.attack_flash.scale = Vector2.ONE
		enemy.attack_flash.modulate = Color(
			enemy.presentation_controller.get_attack_tell_color().r,
			enemy.presentation_controller.get_attack_tell_color().g,
			enemy.presentation_controller.get_attack_tell_color().b,
			enemy.presentation_controller.get_attack_tell_start_alpha()
		)


func update_attack_prep_visual() -> void:
	if enemy._damage_cooldown_remaining > 0.0:
		return

	if not enemy._attack_prep_armed:
		enemy.attack_tell.visible = false
		enemy.attack_tell.position = Vector2.ZERO
		enemy.attack_tell.scale = Vector2.ONE
		enemy.attack_tell.modulate = Color(
			enemy.presentation_controller.get_attack_tell_color().r,
			enemy.presentation_controller.get_attack_tell_color().g,
			enemy.presentation_controller.get_attack_tell_color().b,
			enemy.presentation_controller.get_attack_tell_start_alpha()
		)
		enemy.attack_flash.visible = false
		enemy.attack_flash.scale = Vector2.ONE
		enemy.attack_flash.modulate = Color(
			enemy.presentation_controller.get_attack_tell_color().r,
			enemy.presentation_controller.get_attack_tell_color().g,
			enemy.presentation_controller.get_attack_tell_color().b,
			enemy.presentation_controller.get_attack_tell_start_alpha()
		)
		return

	var tell_lead_time: float = enemy.presentation_controller.get_attack_tell_lead_time()
	if tell_lead_time <= 0.0 or enemy._attack_prep_remaining > tell_lead_time:
		enemy.attack_tell.visible = false
		enemy.attack_flash.visible = false
		return

	var progress: float = clamp(1.0 - (enemy._attack_prep_remaining / tell_lead_time), 0.0, 1.0)
	var pulse: float = 1.0 + sin(enemy._visual_time * enemy.presentation_controller.get_attack_tell_pulse_speed()) * enemy.presentation_controller.get_attack_tell_pulse_scale()
	var tell_color: Color = enemy.presentation_controller.get_attack_tell_color()
	var start_scale: Vector2 = enemy.presentation_controller.get_attack_tell_start_scale()
	var ready_scale: Vector2 = enemy.presentation_controller.get_attack_tell_ready_scale()
	enemy.attack_tell.visible = true
	enemy.attack_tell.scale = start_scale.lerp(ready_scale, progress) * pulse
	enemy.attack_tell.modulate = Color(
		tell_color.r,
		tell_color.g,
		tell_color.b,
		lerpf(enemy.presentation_controller.get_attack_tell_start_alpha(), enemy.presentation_controller.get_attack_tell_ready_alpha(), progress)
	)
	enemy.attack_flash.visible = false


func play_attack_flash() -> void:
	enemy.attack_tell.visible = false
	enemy.attack_tell.position = Vector2.ZERO
	enemy.attack_tell.scale = Vector2.ONE
	enemy.attack_flash.visible = true
	enemy.attack_flash.scale = enemy.presentation_controller.get_attack_flash_start_scale()
	var strike_color: Color = enemy.presentation_controller.get_attack_strike_color()
	enemy.attack_flash.modulate = Color(strike_color.r, strike_color.g, strike_color.b, 1.0)
	var tween := create_tween()
	tween.parallel().tween_property(enemy.attack_flash, "scale", enemy.presentation_controller.get_attack_flash_peak_scale(), enemy.presentation_controller.get_attack_flash_duration())
	tween.parallel().tween_property(enemy.attack_flash, "modulate:a", 0.0, enemy.presentation_controller.get_attack_flash_duration())
	tween.finished.connect(func() -> void:
		enemy.attack_flash.visible = false
		enemy.attack_flash.scale = Vector2.ONE
		enemy.attack_tell.position = Vector2.ZERO
		enemy.attack_flash.modulate = Color(
			enemy.presentation_controller.get_attack_tell_color().r,
			enemy.presentation_controller.get_attack_tell_color().g,
			enemy.presentation_controller.get_attack_tell_color().b,
			enemy.presentation_controller.get_attack_tell_start_alpha()
		)
	)


func get_attack_prep_time() -> float:
	if enemy.definition == null:
		return enemy.attack_prep_time
	return enemy.definition.attack_prep_time


func should_attack_obstructing_player() -> bool:
	if enemy.definition == null:
		return true
	return enemy.definition.attack_player_when_obstructing


func should_attack_player_on_contact() -> bool:
	if enemy.definition == null:
		return true
	return enemy.definition.attack_player_on_contact


func is_structure_target(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	return target.is_in_group("defense_sockets") or target.is_in_group("placeables")


func get_damage_amount_for_target(target) -> int:
	if target != null and target.is_in_group("player"):
		return enemy.player_damage
	return enemy.structure_damage


func is_target_in_damage_range(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	if is_structure_target(target):
		return enemy.global_position.distance_to(get_target_point(target)) <= get_structure_damage_range_estimate()

	if enemy.attack_range_override > 0.0:
		return enemy.global_position.distance_to(get_target_point(target)) <= enemy.attack_range_override

	if target is PhysicsBody2D:
		return enemy.damage_area.overlaps_body(target)

	if target is Area2D:
		return enemy.damage_area.overlaps_area(target)

	return false


func uses_projectile_attack_on_target(target) -> bool:
	if enemy.definition == null or not enemy.definition.uses_projectile_attack:
		return false
	if target == null or not is_instance_valid(target):
		return false
	if not target.is_in_group("player"):
		return false
	return not enemy.runtime_controller.is_player_body_touching(target)


func spawn_attack_projectile(target) -> bool:
	if not uses_projectile_attack_on_target(target):
		return false
	if enemy._enemy_layer_ref == null or not is_instance_valid(enemy._enemy_layer_ref):
		return false
	var projectile: Node = enemy.EnemyProjectileScene.instantiate()
	var destination: Vector2 = get_target_point(target)
	var facing_rotation: float = enemy._facing_direction.angle() + PI / 2.0
	var launch_offset: Vector2 = enemy.definition.projectile_launch_offset.rotated(facing_rotation)
	enemy._enemy_layer_ref.add_child(projectile)
	projectile.configure({
		"attacker": enemy,
		"target": target,
		"origin": enemy.global_position + launch_offset,
		"destination": destination,
		"damage": get_damage_amount_for_target(target),
		"damage_type": enemy.structure_damage_type,
		"knockback_force": enemy.player_knockback_force,
		"speed": enemy.definition.projectile_speed,
		"hit_radius": enemy.definition.projectile_hit_radius,
		"polygon": enemy.definition.projectile_polygon,
		"color": enemy.definition.projectile_color,
		"impact_color": enemy.definition.projectile_impact_color,
	})
	return true


func is_facing_target_for_attack(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	var to_target: Vector2 = target.global_position - enemy.global_position
	if to_target.is_zero_approx():
		return true

	var target_direction: Vector2 = to_target.normalized()
	return enemy._facing_direction.dot(target_direction) >= get_attack_facing_dot_threshold()


func get_attack_facing_dot_threshold() -> float:
	if enemy.definition == null:
		return 0.25
	return enemy.definition.attack_facing_dot_threshold


func has_clear_attack_path(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	if target.is_in_group("defense_sockets"):
		return has_clear_structure_attack_path(target)

	return enemy.targeting_controller.has_clear_line_to_point(target, get_target_point(target), false)


func get_target_point(target) -> Vector2:
	if target == null or not is_instance_valid(target):
		return enemy.global_position

	if target.has_method("get_attack_aim_point"):
		return target.get_attack_aim_point(enemy.global_position)

	return target.global_position


func has_clear_structure_attack_path(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	return true


func get_damage_range_estimate() -> float:
	if enemy.damage_area == null:
		return enemy.attack_range_override if enemy.attack_range_override > 0.0 else 18.0

	var area_shape: CollisionShape2D = enemy.damage_area.get_node_or_null("CollisionShape2D")
	if area_shape == null or area_shape.shape == null:
		return enemy.attack_range_override if enemy.attack_range_override > 0.0 else 18.0

	if area_shape.shape is CircleShape2D:
		return max(area_shape.shape.radius, enemy.attack_range_override)

	return enemy.attack_range_override if enemy.attack_range_override > 0.0 else 18.0


func get_structure_damage_range_estimate() -> float:
	if enemy.structure_attack_range_override > 0.0:
		return enemy.structure_attack_range_override
	return get_damage_range_estimate()
