extends Node
class_name GameEnemyPresentationController


var enemy: GameEnemy


func configure(enemy_ref: GameEnemy) -> void:
	enemy = enemy_ref


func sync_initial_pose() -> void:
	enemy._visual_body_rotation = enemy._facing_direction.angle() - PI / 2.0
	enemy.body_visual.rotation = enemy._visual_body_rotation
	enemy.facing_marker.rotation = enemy._visual_body_rotation + PI
	enemy.attack_flash.rotation = enemy.facing_marker.rotation


func apply_definition_visuals() -> void:
	if enemy.definition == null:
		return
	enemy.body_visual.color = enemy.definition.body_color
	enemy._base_color = enemy.definition.body_color
	enemy.body_shadow.polygon = enemy.definition.shadow_polygon
	enemy.body_visual.polygon = enemy.definition.body_polygon
	enemy.facing_marker.polygon = enemy.definition.facing_marker_polygon
	enemy.attack_tell.polygon = enemy.definition.attack_tell_polygon
	enemy.attack_flash.polygon = enemy.definition.attack_flash_polygon
	enemy._presentation_scale = enemy.definition.presentation_scale
	enemy._visual_bob_height = enemy.definition.visual_bob_height
	enemy._visual_breathe_scale = enemy.definition.visual_breathe_scale
	enemy._visual_turn_speed = enemy.definition.visual_turn_speed
	enemy._visual_move_stretch_x = enemy.definition.visual_move_stretch_x
	enemy._visual_move_stretch_y = enemy.definition.visual_move_stretch_y
	enemy._prep_pose_offset = enemy.definition.prep_pose_offset
	enemy._prep_pose_scale = enemy.definition.prep_pose_scale
	enemy._prep_pose_tilt_radians = deg_to_rad(enemy.definition.prep_pose_tilt_degrees)
	enemy._damage_feedback_distance = enemy.definition.damage_feedback_distance
	enemy._damage_feedback_scale = enemy.definition.damage_feedback_scale
	enemy._damage_feedback_duration = enemy.definition.damage_feedback_duration
	if enemy.definition.is_elite:
		enemy.elite_aura.visible = true
		var aura_color: Color = enemy.definition.body_color.lerp(Color(1.0, 0.84, 0.34, 1.0), 0.5)
		enemy.elite_aura.color = Color(aura_color.r, aura_color.g, aura_color.b, 0.46)
		enemy.facing_marker.color = Color(1.0, 0.9, 0.52, 1.0)
	else:
		enemy.elite_aura.visible = false
		enemy.elite_aura.color = enemy._base_elite_aura_color
		enemy.facing_marker.color = enemy._base_facing_marker_color


func refresh_health_bar() -> void:
	if enemy.health_bar_background == null or enemy.health_bar_fill == null:
		return
	var max_health_value: int = max(enemy.max_health, 1)
	var health_ratio: float = clamp(float(enemy.current_health) / float(max_health_value), 0.0, 1.0)
	enemy.health_bar_background.visible = max_health_value > 0
	enemy.health_bar_fill.visible = health_ratio > 0.0
	if not enemy.health_bar_fill.visible:
		return
	var fill_width: float = lerpf(0.0, enemy.HEALTH_BAR_FILL_HALF_WIDTH * 2.0, health_ratio)
	var left_x: float = -enemy.HEALTH_BAR_FILL_HALF_WIDTH
	var right_x: float = left_x + fill_width
	enemy.health_bar_fill.polygon = PackedVector2Array([
		Vector2(left_x, -enemy.HEALTH_BAR_FILL_HALF_HEIGHT),
		Vector2(right_x, -enemy.HEALTH_BAR_FILL_HALF_HEIGHT),
		Vector2(right_x, enemy.HEALTH_BAR_FILL_HALF_HEIGHT),
		Vector2(left_x, enemy.HEALTH_BAR_FILL_HALF_HEIGHT),
	])
	enemy.health_bar_fill.color = Color(
		lerpf(0.92, 0.3, health_ratio),
		lerpf(0.24, 0.92, health_ratio),
		0.28,
		0.96
	)
	update_health_bar_visibility(0.0)


func flash_body(flash_color: Color) -> void:
	enemy.body_visual.color = flash_color
	var tween: Tween = create_tween()
	tween.tween_property(enemy.body_visual, "color", enemy._base_color, 0.12)


func play_damage_feedback(source: Variant) -> void:
	if enemy._damage_feedback_tween != null and is_instance_valid(enemy._damage_feedback_tween):
		enemy._damage_feedback_tween.kill()

	var knock_direction: Vector2 = get_damage_knock_direction(source)
	var intensity: float = get_damage_feedback_intensity(source)
	enemy.body_visual.position = knock_direction * (enemy._damage_feedback_distance * intensity)
	enemy.body_visual.scale = Vector2.ONE.lerp(enemy._damage_feedback_scale, minf(intensity, 1.6))
	enemy.facing_marker.position = knock_direction * (enemy._damage_feedback_distance * intensity)
	enemy.facing_marker.scale = Vector2.ONE.lerp(enemy._damage_feedback_scale, minf(intensity, 1.6))
	enemy._damage_feedback_rotation_offset = signf(knock_direction.x if not is_zero_approx(knock_direction.x) else 1.0) * deg_to_rad(4.0 * intensity)

	enemy._damage_feedback_tween = create_tween()
	enemy._damage_feedback_tween.parallel().tween_property(enemy.body_visual, "position", Vector2.ZERO, enemy._damage_feedback_duration)
	enemy._damage_feedback_tween.parallel().tween_property(enemy.body_visual, "scale", Vector2.ONE, enemy._damage_feedback_duration)
	enemy._damage_feedback_tween.parallel().tween_property(enemy.facing_marker, "position", Vector2.ZERO, enemy._damage_feedback_duration)
	enemy._damage_feedback_tween.parallel().tween_property(enemy.facing_marker, "scale", Vector2.ONE, enemy._damage_feedback_duration)
	enemy._damage_feedback_tween.parallel().tween_property(enemy, "_damage_feedback_rotation_offset", 0.0, enemy._damage_feedback_duration)


func update_render_order() -> void:
	enemy.z_as_relative = false
	enemy.z_index = enemy.GAMEPLAY_Z_BASE + int(round(enemy.global_position.y))


func process_visuals(delta: float) -> void:
	if enemy.visual_root == null or enemy.body_shadow == null:
		return

	var movement_ratio: float = clampf(enemy.velocity.length() / maxf(enemy.move_speed, 1.0), 0.0, 1.0)
	enemy._visual_movement_ratio = move_toward(enemy._visual_movement_ratio, movement_ratio, delta * 6.0)
	enemy._visual_time += delta * lerpf(1.8, 7.2, enemy._visual_movement_ratio)
	var breathe: float = sin(enemy._visual_time * 1.9) * enemy._visual_breathe_scale
	var bob_target: float = sin(enemy._visual_time * 7.6) * enemy._visual_bob_height * enemy._visual_movement_ratio
	enemy._visual_bob_offset_y = lerpf(enemy._visual_bob_offset_y, bob_target, minf(delta * 8.0, 1.0))
	var prep_progress := 0.0
	if enemy._attack_prep_armed:
		var prep_time: float = maxf(enemy.combat_controller.get_attack_prep_time(), 0.001)
		prep_progress = clampf(1.0 - (enemy._attack_prep_remaining / prep_time), 0.0, 1.0)
	enemy.visual_root.position = Vector2(0.0, enemy._visual_bob_offset_y) + (enemy._prep_pose_offset * prep_progress)
	var locomotion_scale := Vector2(
		1.0 + enemy._visual_move_stretch_x * enemy._visual_movement_ratio + maxf(breathe, 0.0),
		1.0 - enemy._visual_move_stretch_y * enemy._visual_movement_ratio - minf(breathe, 0.0)
	)
	var prep_scale := Vector2.ONE.lerp(enemy._prep_pose_scale, prep_progress)
	enemy.visual_root.scale = Vector2(
		enemy._presentation_scale.x * locomotion_scale.x * prep_scale.x,
		enemy._presentation_scale.y * locomotion_scale.y * prep_scale.y
	)
	var target_body_rotation: float = (enemy._facing_direction.angle() - PI / 2.0) + (enemy._prep_pose_tilt_radians * prep_progress) + enemy._damage_feedback_rotation_offset
	enemy._visual_body_rotation = lerp_angle(enemy._visual_body_rotation, target_body_rotation, minf(delta * enemy._visual_turn_speed, 1.0))
	enemy.body_visual.rotation = enemy._visual_body_rotation
	enemy.facing_marker.rotation = enemy._visual_body_rotation + PI
	enemy.attack_tell.rotation = enemy.facing_marker.rotation
	enemy.attack_flash.rotation = enemy.facing_marker.rotation
	enemy.attack_tell.position = get_attack_tell_offset() * prep_progress

	enemy.body_shadow.scale = Vector2(1.0 - 0.09 * enemy._visual_movement_ratio, 1.0 + 0.06 * enemy._visual_movement_ratio)
	enemy.body_shadow.modulate = Color(1.0, 1.0, 1.0, 0.18 + 0.05 * enemy._visual_movement_ratio)

	if enemy.elite_aura.visible:
		var aura_pulse: float = 1.0 + 0.05 * sin(enemy._visual_time * 3.2)
		enemy.elite_aura.scale = Vector2.ONE * aura_pulse

	update_state_indicator()
	update_health_bar_visibility(delta)


func update_state_indicator() -> void:
	if enemy.state_indicator == null:
		return
	if enemy._attack_prep_armed:
		enemy.state_indicator.visible = true
		enemy.state_indicator.color = Color(1.0, 0.9, 0.72, 0.96)
		enemy.state_indicator.scale = Vector2.ONE * (1.02 + 0.12 * sin(enemy._visual_time * 8.0))
		return
	if enemy._is_alerted_to_player or enemy._is_chasing_player:
		enemy.state_indicator.visible = true
		enemy.state_indicator.color = Color(1.0, 0.52, 0.42, 0.86)
		enemy.state_indicator.scale = Vector2.ONE * (0.98 + 0.09 * sin(enemy._visual_time * 5.4))
		return
	var has_noise_investigation: bool = enemy.targeting_controller.has_active_noise_investigation()
	if has_noise_investigation or enemy._threat_indicator_grace_remaining > 0.0:
		enemy.state_indicator.visible = true
		enemy.state_indicator.color = Color(0.58, 0.84, 1.0, 0.72 if has_noise_investigation else 0.42)
		enemy.state_indicator.scale = Vector2.ONE * (0.92 + 0.05 * sin(enemy._visual_time * 4.2))
		return
	enemy.state_indicator.visible = false


func update_health_bar_visibility(delta: float) -> void:
	if enemy.health_bar_background == null or enemy.health_bar_fill == null:
		return
	var should_show := false
	if enemy.definition != null and enemy.definition.is_elite:
		should_show = true
	elif enemy.current_health < enemy.max_health:
		should_show = true
	elif enemy._is_alerted_to_player or enemy._is_chasing_player or enemy.targeting_controller.has_active_noise_investigation() or enemy._attack_prep_armed:
		should_show = true
	var target_alpha: float = 1.0 if should_show else 0.0
	var step: float = 1.0 if delta <= 0.0 else delta * 5.0
	enemy._health_bar_alpha = move_toward(enemy._health_bar_alpha, target_alpha, step)
	enemy.health_bar_background.visible = enemy._health_bar_alpha > 0.01
	enemy.health_bar_fill.visible = enemy.current_health > 0 and enemy._health_bar_alpha > 0.01
	enemy.health_bar_background.modulate.a = 0.88 * enemy._health_bar_alpha
	enemy.health_bar_fill.modulate.a = 0.96 * enemy._health_bar_alpha


func get_visual_turn_speed() -> float:
	return enemy._visual_turn_speed


func get_attack_tell_color() -> Color:
	if enemy.definition == null:
		return Color(1.0, 0.82, 0.42, 0.72)
	return enemy.definition.attack_tell_color


func get_attack_tell_start_scale() -> Vector2:
	if enemy.definition == null:
		return Vector2(0.62, 0.62)
	return enemy.definition.attack_tell_start_scale


func get_attack_tell_ready_scale() -> Vector2:
	if enemy.definition == null:
		return Vector2(0.98, 0.98)
	return enemy.definition.attack_tell_ready_scale


func get_attack_tell_start_alpha() -> float:
	if enemy.definition == null:
		return 0.18
	return enemy.definition.attack_tell_start_alpha


func get_attack_tell_ready_alpha() -> float:
	if enemy.definition == null:
		return 0.72
	return enemy.definition.attack_tell_ready_alpha


func get_attack_tell_pulse_speed() -> float:
	if enemy.definition == null:
		return 6.0
	return enemy.definition.attack_tell_pulse_speed


func get_attack_tell_pulse_scale() -> float:
	if enemy.definition == null:
		return 0.08
	return enemy.definition.attack_tell_pulse_scale


func get_attack_tell_offset() -> Vector2:
	if enemy.definition == null:
		return Vector2.ZERO
	return enemy.definition.attack_tell_offset


func get_attack_tell_lead_time() -> float:
	var prep_time: float = enemy.combat_controller.get_attack_prep_time()
	if enemy.definition == null:
		return min(0.3, prep_time)
	return min(enemy.definition.attack_tell_lead_time, prep_time)


func get_attack_flash_peak_scale() -> Vector2:
	if enemy.definition == null:
		return Vector2(1.08, 1.08)
	return enemy.definition.attack_flash_peak_scale


func get_attack_flash_start_scale() -> Vector2:
	if enemy.definition == null:
		return Vector2(0.78, 0.78)
	return enemy.definition.attack_flash_start_scale


func get_attack_strike_color() -> Color:
	if enemy.definition == null:
		return Color(1.0, 0.98, 0.86, 0.98)
	return enemy.definition.attack_strike_color


func get_attack_flash_duration() -> float:
	if enemy.definition == null:
		return 0.08
	return enemy.definition.attack_flash_duration


func get_damage_feedback_intensity(source: Variant) -> float:
	if not (source is Dictionary):
		return 1.0
	var damage_amount := float(source.get("damage_amount", 0))
	var knockback_force := float(source.get("knockback_force", 0.0))
	var damage_type := StringName(source.get("damage_type", &"impact"))
	var intensity := 0.85
	intensity += clampf(damage_amount / 36.0, 0.0, 0.7)
	intensity += clampf(knockback_force / 700.0, 0.0, 0.5)
	if damage_type == &"ballistic":
		intensity += 0.08
	return clampf(intensity, 0.8, 1.8)


func get_damage_knock_direction(source: Variant) -> Vector2:
	var attacker_position := enemy.global_position
	if source is Dictionary:
		var attacker = source.get("attacker")
		if attacker != null and is_instance_valid(attacker) and attacker is Node2D:
			attacker_position = attacker.global_position
	elif source != null and is_instance_valid(source) and source is Node2D:
		attacker_position = source.global_position

	var knock_direction := enemy.global_position - attacker_position
	if knock_direction.is_zero_approx():
		return Vector2(0.0, 1.0)
	return knock_direction.normalized()
