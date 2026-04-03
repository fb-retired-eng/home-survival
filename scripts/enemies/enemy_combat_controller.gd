extends Node
class_name GameEnemyCombatController

var enemy


func configure(enemy_ref) -> void:
	enemy = enemy_ref


func try_damage_target(target) -> bool:
	if not can_execute_attack(target):
		return false

	var damage_amount: int = enemy._get_damage_amount_for_target(target)
	if enemy._is_structure_target(target):
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

	if not enemy._is_target_in_damage_range(target):
		return false

	if enemy._is_structure_target(target):
		return true

	if not enemy._has_clear_attack_path(target):
		return false

	if not enemy._is_facing_target_for_attack(target):
		return false

	return true


func can_begin_attack_prep(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	if not target.has_method("take_damage"):
		return false

	if not enemy._is_target_in_damage_range(target):
		return false

	if enemy._is_structure_target(target):
		return true

	if not enemy._is_facing_target_for_attack(target):
		return false

	if target.is_in_group("player") and enemy._is_player_body_touching(target):
		return true

	return enemy._has_clear_attack_path(target)


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
		enemy._attack_prep_remaining = enemy._get_attack_prep_time()
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
			enemy._get_attack_tell_color().r,
			enemy._get_attack_tell_color().g,
			enemy._get_attack_tell_color().b,
			enemy._get_attack_tell_start_alpha()
		)
		enemy.attack_flash.visible = false
		enemy.attack_flash.scale = Vector2.ONE
		enemy.attack_flash.modulate = Color(
			enemy._get_attack_tell_color().r,
			enemy._get_attack_tell_color().g,
			enemy._get_attack_tell_color().b,
			enemy._get_attack_tell_start_alpha()
		)


func update_attack_prep_visual() -> void:
	if enemy._damage_cooldown_remaining > 0.0:
		return

	if not enemy._attack_prep_armed:
		enemy.attack_tell.visible = false
		enemy.attack_tell.position = Vector2.ZERO
		enemy.attack_tell.scale = Vector2.ONE
		enemy.attack_tell.modulate = Color(
			enemy._get_attack_tell_color().r,
			enemy._get_attack_tell_color().g,
			enemy._get_attack_tell_color().b,
			enemy._get_attack_tell_start_alpha()
		)
		enemy.attack_flash.visible = false
		enemy.attack_flash.scale = Vector2.ONE
		enemy.attack_flash.modulate = Color(
			enemy._get_attack_tell_color().r,
			enemy._get_attack_tell_color().g,
			enemy._get_attack_tell_color().b,
			enemy._get_attack_tell_start_alpha()
		)
		return

	var tell_lead_time: float = enemy._get_attack_tell_lead_time()
	if tell_lead_time <= 0.0 or enemy._attack_prep_remaining > tell_lead_time:
		enemy.attack_tell.visible = false
		enemy.attack_flash.visible = false
		return

	var progress: float = clamp(1.0 - (enemy._attack_prep_remaining / tell_lead_time), 0.0, 1.0)
	var pulse: float = 1.0 + sin(enemy._visual_time * enemy._get_attack_tell_pulse_speed()) * enemy._get_attack_tell_pulse_scale()
	var tell_color: Color = enemy._get_attack_tell_color()
	var start_scale: Vector2 = enemy._get_attack_tell_start_scale()
	var ready_scale: Vector2 = enemy._get_attack_tell_ready_scale()
	enemy.attack_tell.visible = true
	enemy.attack_tell.scale = start_scale.lerp(ready_scale, progress) * pulse
	enemy.attack_tell.modulate = Color(
		tell_color.r,
		tell_color.g,
		tell_color.b,
		lerpf(enemy._get_attack_tell_start_alpha(), enemy._get_attack_tell_ready_alpha(), progress)
	)
	enemy.attack_flash.visible = false


func play_attack_flash() -> void:
	enemy.attack_tell.visible = false
	enemy.attack_tell.position = Vector2.ZERO
	enemy.attack_tell.scale = Vector2.ONE
	enemy.attack_flash.visible = true
	enemy.attack_flash.scale = enemy._get_attack_flash_start_scale()
	var strike_color: Color = enemy._get_attack_strike_color()
	enemy.attack_flash.modulate = Color(strike_color.r, strike_color.g, strike_color.b, 1.0)
	var tween := create_tween()
	tween.parallel().tween_property(enemy.attack_flash, "scale", enemy._get_attack_flash_peak_scale(), enemy._get_attack_flash_duration())
	tween.parallel().tween_property(enemy.attack_flash, "modulate:a", 0.0, enemy._get_attack_flash_duration())
	tween.finished.connect(func() -> void:
		enemy.attack_flash.visible = false
		enemy.attack_flash.scale = Vector2.ONE
		enemy.attack_tell.position = Vector2.ZERO
		enemy.attack_flash.modulate = Color(
			enemy._get_attack_tell_color().r,
			enemy._get_attack_tell_color().g,
			enemy._get_attack_tell_color().b,
			enemy._get_attack_tell_start_alpha()
		)
	)
