extends Node
class_name ZombieCombatController

var zombie: Zombie


func configure(zombie_ref: Zombie) -> void:
	zombie = zombie_ref


func try_damage_target(target) -> bool:
	if not can_execute_attack(target):
		return false

	var damage_amount: int = zombie._get_damage_amount_for_target(target)
	if zombie._is_structure_target(target):
		target.take_damage(damage_amount, {
			"attacker": zombie,
			"damage_type": zombie.structure_damage_type,
		})
	else:
		target.take_damage(damage_amount, {
			"attacker": zombie,
			"damage_type": zombie.structure_damage_type,
			"knockback_force": zombie.player_knockback_force,
			"knockback_direction": zombie._facing_direction,
		})
	play_attack_flash()
	zombie._play_combat_sound(&"zombie_attack_hit", randf_range(0.96, 1.05), -1.5)
	return true


func can_execute_attack(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	if not target.has_method("take_damage"):
		return false

	if not zombie._is_target_in_damage_range(target):
		return false

	if zombie._is_structure_target(target):
		return true

	if not zombie._has_clear_attack_path(target):
		return false

	if not zombie._is_facing_target_for_attack(target):
		return false

	return true


func can_begin_attack_prep(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	if not target.has_method("take_damage"):
		return false

	if not zombie._is_target_in_damage_range(target):
		return false

	if zombie._is_structure_target(target):
		return true

	if not zombie._is_facing_target_for_attack(target):
		return false

	if target.is_in_group("player") and zombie._is_player_body_touching(target):
		return true

	return zombie._has_clear_attack_path(target)


func apply_attack_interrupt_from_source(source: Variant) -> void:
	if source == null or typeof(source) != TYPE_DICTIONARY:
		return
	if not bool(source.get("interrupt_attack_prep", false)):
		return
	if not zombie._attack_prep_armed:
		return
	reset_attack_prep()


func process_attack_prep(attack_target) -> bool:
	if zombie._damage_cooldown_remaining > 0.0:
		reset_attack_prep()
		return false

	if not can_begin_attack_prep(attack_target):
		if zombie._attack_prep_armed and zombie._attack_prep_lost_target_grace_remaining > 0.0:
			return zombie._attack_prep_remaining > 0.0
		reset_attack_prep()
		return false

	var target_id: int = attack_target.get_instance_id()
	if not zombie._attack_prep_armed or zombie._attack_prep_target_id != target_id:
		zombie._attack_prep_armed = true
		zombie._attack_prep_target_id = target_id
		zombie._attack_prep_remaining = zombie._get_attack_prep_time()
		zombie._play_combat_sound(&"zombie_attack_tell", randf_range(0.94, 1.03), -5.0)

	zombie._attack_prep_lost_target_grace_remaining = 0.08
	return zombie._attack_prep_remaining > 0.0


func reset_attack_prep() -> void:
	zombie._attack_prep_armed = false
	zombie._attack_prep_remaining = 0.0
	zombie._attack_prep_target_id = 0
	zombie._attack_prep_lost_target_grace_remaining = 0.0
	if zombie._damage_cooldown_remaining <= 0.0:
		zombie.attack_flash.visible = false
		zombie.attack_flash.scale = Vector2.ONE
		zombie.attack_flash.modulate = Color(
			zombie._get_attack_tell_color().r,
			zombie._get_attack_tell_color().g,
			zombie._get_attack_tell_color().b,
			zombie._get_attack_tell_start_alpha()
		)


func update_attack_prep_visual() -> void:
	if zombie._damage_cooldown_remaining > 0.0:
		return

	if not zombie._attack_prep_armed:
		zombie.attack_flash.visible = false
		zombie.attack_flash.scale = Vector2.ONE
		zombie.attack_flash.modulate = Color(
			zombie._get_attack_tell_color().r,
			zombie._get_attack_tell_color().g,
			zombie._get_attack_tell_color().b,
			zombie._get_attack_tell_start_alpha()
		)
		return

	var tell_lead_time: float = zombie._get_attack_tell_lead_time()
	if tell_lead_time <= 0.0 or zombie._attack_prep_remaining > tell_lead_time:
		zombie.attack_flash.visible = false
		return

	var progress: float = clamp(1.0 - (zombie._attack_prep_remaining / tell_lead_time), 0.0, 1.0)
	zombie.attack_flash.visible = true
	var tell_color: Color = zombie._get_attack_tell_color()
	var start_scale: Vector2 = zombie._get_attack_tell_start_scale()
	var ready_scale: Vector2 = zombie._get_attack_tell_ready_scale()
	zombie.attack_flash.scale = start_scale.lerp(ready_scale, progress)
	zombie.attack_flash.modulate = Color(
		tell_color.r,
		tell_color.g,
		tell_color.b,
		lerpf(zombie._get_attack_tell_start_alpha(), zombie._get_attack_tell_ready_alpha(), progress)
	)


func play_attack_flash() -> void:
	zombie.attack_flash.visible = true
	zombie.attack_flash.scale = zombie._get_attack_flash_start_scale()
	var strike_color: Color = zombie._get_attack_strike_color()
	zombie.attack_flash.modulate = Color(strike_color.r, strike_color.g, strike_color.b, 1.0)
	var tween := create_tween()
	tween.parallel().tween_property(zombie.attack_flash, "scale", zombie._get_attack_flash_peak_scale(), zombie._get_attack_flash_duration())
	tween.parallel().tween_property(zombie.attack_flash, "modulate:a", 0.0, zombie._get_attack_flash_duration())
	tween.finished.connect(func() -> void:
		zombie.attack_flash.visible = false
		zombie.attack_flash.scale = Vector2.ONE
		zombie.attack_flash.modulate = Color(
			zombie._get_attack_tell_color().r,
			zombie._get_attack_tell_color().g,
			zombie._get_attack_tell_color().b,
			zombie._get_attack_tell_start_alpha()
		)
	)
