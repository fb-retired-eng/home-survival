extends Node
class_name PlayerCombatController

const PlayerProjectileScene = preload("res://scenes/player/PlayerProjectile.tscn")
const DEFAULT_SPREAD_HITSCAN_CONE_DEGREES := 30.0
const STRUCTURE_ATTACK_BLOCKER_MASK := 2 | 4

var player


func configure(player_ref) -> void:
	player = player_ref


func attempt_attack() -> void:
	if player.attack_cooldown_remaining > 0.0 or player._attack_windup_pending or player._is_reloading_weapon():
		return

	var weapon: Resource = player._get_equipped_weapon()
	if weapon == null:
		return

	if player._uses_weapon_magazine(weapon):
		if player._get_weapon_magazine_ammo(weapon) <= 0:
			if player._get_bullet_reserve_amount() <= 0:
				player.message_requested.emit("Out of bullets")
			else:
				player._attempt_reload(true)
			return

		if player.current_energy < weapon.energy_cost:
			player.message_requested.emit("Too tired")
			return

		if not player.spend_energy(weapon.energy_cost):
			player.message_requested.emit("Too tired")
			return
		start_attack_sequence(weapon, false)
		return

	var hit_targets := get_attack_targets_for_weapon(weapon)
	if hit_targets.is_empty():
		start_attack_sequence(weapon, true)
		return

	if player.current_energy < weapon.energy_cost:
		player.message_requested.emit("Too tired")
		return

	if not player.spend_energy(weapon.energy_cost):
		player.message_requested.emit("Too tired")
		return
	start_attack_sequence(weapon, false)


func on_attack_windup_timer_timeout() -> void:
	if player.is_dead:
		cancel_attack_windup()
		return

	if player._attack_windup_weapon != null and bool(player._attack_windup_weapon.uses_projectile):
		player.firearm_windup_changed.emit(false)
	player._attack_windup_pending = false
	if player._attack_windup_visual_only:
		var windup_weapon: Resource = player._attack_windup_weapon
		var attack_result := get_visual_only_attack_result_for_weapon(windup_weapon)
		player._attack_windup_weapon = null
		player._attack_windup_visual_only = false
		play_attack_effect(windup_weapon, attack_result)
		player._flash_body(Color(1.0, 0.82, 0.54, 1.0))
		apply_miss_recovery(windup_weapon)
		return

	commit_attack(player._attack_windup_weapon)


func apply_weapon_visuals(weapon: Resource) -> void:
	if weapon == null:
		return
	player._ensure_weapon_runtime_state(weapon)

	var applied_attack_area_position: Vector2 = weapon.attack_area_offset
	var applied_attack_area_size: Vector2 = weapon.attack_area_size
	var indicator_position: Vector2 = weapon.attack_area_offset
	var indicator_polygon: PackedVector2Array
	if weapon.attack_mode == "hitscan":
		applied_attack_area_position = Vector2(weapon.attack_area_offset.x, -weapon.attack_range * 0.5)
		applied_attack_area_size = Vector2(weapon.attack_area_size.x, weapon.attack_range)
	elif weapon.attack_mode == "spread_hitscan":
		var half_angle_radians := deg_to_rad(maxf(weapon.attack_cone_degrees, DEFAULT_SPREAD_HITSCAN_CONE_DEGREES) * 0.5)
		var derived_width := maxf(tan(half_angle_radians) * weapon.attack_range * 2.0, weapon.attack_area_size.x)
		applied_attack_area_position = Vector2(weapon.attack_area_offset.x, -weapon.attack_range * 0.5)
		applied_attack_area_size = Vector2(derived_width, weapon.attack_range)

	if weapon.uses_projectile:
		indicator_position = get_muzzle_local_position()
		indicator_polygon = weapon.projectile_polygon if weapon.projectile_polygon.size() >= 3 else PackedVector2Array([
			Vector2(-3.0, -10.0),
			Vector2(3.0, -10.0),
			Vector2(4.0, 0.0),
			Vector2(0.0, 10.0),
			Vector2(-4.0, 0.0),
		])
	else:
		indicator_polygon = PackedVector2Array([
			Vector2(-applied_attack_area_size.x * 0.5, -applied_attack_area_size.y * 0.5),
			Vector2(applied_attack_area_size.x * 0.5, -applied_attack_area_size.y * 0.5),
			Vector2(applied_attack_area_size.x * 0.5, applied_attack_area_size.y * 0.5),
			Vector2(-applied_attack_area_size.x * 0.5, applied_attack_area_size.y * 0.5)
		])

	player.weapon_visual.position = weapon.held_visual_offset if weapon.held_visual_polygon.size() >= 3 else get_default_held_weapon_polygon_offset()
	player.weapon_visual.polygon = weapon.held_visual_polygon if weapon.held_visual_polygon.size() >= 3 else get_default_held_weapon_polygon()
	player.weapon_visual.color = weapon.held_visual_color if weapon.held_visual_polygon.size() >= 3 else player.DEFAULT_HELD_WEAPON_COLOR
	player.attack_area.position = applied_attack_area_position
	player.attack_indicator.position = indicator_position
	if player.attack_area_shape.shape is RectangleShape2D:
		var shape := player.attack_area_shape.shape as RectangleShape2D
		shape.size = applied_attack_area_size
		player.attack_indicator.polygon = indicator_polygon

	player._attack_flash_color = weapon.attack_flash_color
	player._attack_flash_start_scale = weapon.attack_flash_start_scale
	player._attack_indicator_windup_color = weapon.attack_indicator_windup_color
	player._attack_indicator_strike_color = weapon.attack_indicator_strike_color
	player._attack_indicator_windup_start_scale = weapon.attack_indicator_windup_start_scale
	player._attack_indicator_strike_peak_scale = weapon.attack_indicator_strike_peak_scale
	player._attack_indicator_lead_time = min(weapon.attack_indicator_lead_time, weapon.attack_windup)
	player._attack_indicator_windup_start_alpha = weapon.attack_indicator_windup_start_alpha
	player._attack_indicator_windup_end_alpha = weapon.attack_indicator_windup_end_alpha
	player._attack_indicator_strike_alpha = weapon.attack_indicator_strike_alpha
	player._attack_indicator_strike_fade_duration = weapon.attack_indicator_strike_fade_duration
	player.attack_indicator.color = weapon.attack_indicator_windup_color
	player.attack_indicator.modulate = Color(1.0, 1.0, 1.0, 1.0)
	player.attack_indicator.scale = Vector2.ONE
	player.attack_flash.color = weapon.attack_flash_color
	player.attack_flash.modulate = Color(weapon.attack_flash_color.r, weapon.attack_flash_color.g, weapon.attack_flash_color.b, 1.0)
	player._attack_flash_peak_scale = weapon.attack_flash_peak_scale
	player._attack_flash_duration = weapon.attack_flash_duration
	player._muzzle_flash_color = weapon.muzzle_flash_color
	player._muzzle_flash_scale = weapon.muzzle_flash_scale
	player._muzzle_flash_duration = weapon.muzzle_flash_duration
	player._tracer_color = weapon.tracer_color
	player._tracer_width = weapon.tracer_width
	player._tracer_duration = weapon.tracer_duration
	player._impact_hit_color = weapon.impact_hit_color
	player._impact_block_color = weapon.impact_block_color
	player._impact_flash_scale = weapon.impact_flash_scale
	player._impact_flash_duration = weapon.impact_flash_duration
	player.muzzle_flash.color = weapon.muzzle_flash_color
	player.muzzle_flash.modulate = Color(weapon.muzzle_flash_color.r, weapon.muzzle_flash_color.g, weapon.muzzle_flash_color.b, 1.0)
	player.shot_tracer.default_color = weapon.tracer_color
	player.shot_tracer.width = weapon.tracer_width
	player._emit_weapon_state()


func get_attack_result_for_weapon(weapon: Resource) -> Dictionary:
	if weapon == null:
		return {
			"targets": [],
			"end_point": player.global_position,
			"impact_kind": "none",
		}

	if weapon.attack_mode == "hitscan":
		return _get_hitscan_attack_result(weapon)
	if weapon.attack_mode == "spread_hitscan":
		return _get_spread_hitscan_attack_result(weapon)
	var melee_targets := _get_melee_attack_targets()
	return {
		"targets": melee_targets,
		"end_point": player.attack_pivot.to_global(weapon.attack_area_offset),
		"impact_kind": "enemy" if not melee_targets.is_empty() else "miss",
	}


func get_visual_only_attack_result_for_weapon(weapon: Resource) -> Dictionary:
	if weapon == null:
		return {
			"targets": [],
			"end_point": player.global_position,
			"impact_kind": "none",
		}

	if weapon.attack_mode == "hitscan" or weapon.attack_mode == "spread_hitscan":
		var ray_start: Vector2 = player.attack_pivot.to_global(get_muzzle_local_position())
		return {
			"targets": [],
			"end_point": ray_start + player.facing_direction * float(weapon.attack_range),
			"impact_kind": "miss",
		}

	return {
		"targets": [],
		"end_point": player.attack_pivot.to_global(weapon.attack_area_offset),
		"impact_kind": "miss",
	}


func get_attack_targets_for_weapon(weapon: Resource) -> Array:
	return Array(get_attack_result_for_weapon(weapon).get("targets", []))


func commit_attack(weapon_override: Resource = null) -> void:
	var weapon: Resource = weapon_override
	if weapon == null:
		weapon = player._get_equipped_weapon()
	if weapon == null:
		return

	var attack_result: Dictionary = get_attack_result_for_weapon(weapon)
	var hit_targets: Array = Array(attack_result.get("targets", []))
	var consumes_ammo: bool = player._uses_weapon_magazine(weapon)
	if consumes_ammo:
		player._consume_weapon_magazine_round(weapon)
	_emit_weapon_noise(weapon)
	if weapon.uses_projectile:
		play_projectile_attack_effect(weapon)
		player.attack_cooldown_remaining = weapon.attack_cooldown
		_spawn_projectile_attack(weapon, attack_result, build_attack_damage_map(weapon, hit_targets))
		player._flash_body(Color(1.0, 0.82, 0.54, 1.0))
		player._attack_windup_weapon = null
		player._attack_windup_visual_only = false
		return
	if hit_targets.is_empty():
		play_attack_effect(weapon, attack_result)
		player._flash_body(Color(1.0, 0.82, 0.54, 1.0))
		if consumes_ammo:
			player.attack_cooldown_remaining = weapon.attack_cooldown
		elif player._attack_windup_weapon != null:
			player.restore_energy(int(weapon.energy_cost))
			apply_miss_recovery(weapon)
		player.attack_windup_timer.stop()
		player._attack_windup_pending = false
		player._attack_windup_weapon = null
		player._attack_windup_visual_only = false
		return

	play_attack_effect(weapon, attack_result)
	player.attack_cooldown_remaining = weapon.attack_cooldown
	player._flash_body(Color(1.0, 0.82, 0.54, 1.0))

	var attack_damage_map := build_attack_damage_map(weapon, hit_targets)
	for body in hit_targets:
		if is_instance_valid(body):
			body.take_damage(int(attack_damage_map.get(body, weapon.damage)), {
				"attacker": player,
				"damage_type": weapon.damage_type,
				"knockback_force": weapon.knockback_force,
				"knockback_direction": player.facing_direction,
				"interrupt_attack_prep": bool(weapon.interrupt_attack_prep),
			})
	player._attack_windup_weapon = null
	player._attack_windup_visual_only = false


func cancel_attack_windup() -> void:
	if player._attack_windup_weapon != null and bool(player._attack_windup_weapon.uses_projectile):
		player.firearm_windup_changed.emit(false)
	player.attack_windup_timer.stop()
	player._attack_windup_pending = false
	player._attack_windup_weapon = null
	player._attack_windup_visual_only = false
	_hide_attack_indicator()


func start_attack_sequence(weapon: Resource, visual_only: bool) -> void:
	if weapon.attack_windup <= 0.0:
		if visual_only:
			play_attack_effect(weapon, get_visual_only_attack_result_for_weapon(weapon))
			player._flash_body(Color(1.0, 0.82, 0.54, 1.0))
			apply_miss_recovery(weapon)
			return
		commit_attack(weapon)
		return

	player._attack_windup_pending = true
	player._attack_windup_weapon = weapon
	player._attack_windup_visual_only = visual_only
	if not visual_only and bool(weapon.uses_projectile):
		player.firearm_windup_changed.emit(true)
	_show_attack_indicator_windup(weapon.attack_windup)
	player.attack_windup_timer.start(weapon.attack_windup)


func play_attack_effect(weapon: Resource, attack_result: Dictionary) -> void:
	if weapon != null:
		player._play_combat_sound(get_attack_sound_id_for_weapon(weapon), get_attack_sound_pitch_for_weapon(weapon), get_attack_sound_volume_for_weapon(weapon))
		player._play_combat_sound(get_attack_impact_sound_id(String(attack_result.get("impact_kind", "miss"))), randf_range(0.98, 1.04), get_attack_impact_volume(String(attack_result.get("impact_kind", "miss"))))
	if weapon != null and weapon.attack_mode == "hitscan":
		_play_hitscan_effect(
			attack_result.get("end_point", player.attack_pivot.global_position),
			String(attack_result.get("impact_kind", "miss"))
		)
		return
	_play_attack_flash()


func play_projectile_attack_effect(weapon: Resource) -> void:
	if weapon != null:
		player._play_combat_sound(get_attack_sound_id_for_weapon(weapon), get_attack_sound_pitch_for_weapon(weapon), get_attack_sound_volume_for_weapon(weapon))
	_play_muzzle_flash()
	_show_attack_indicator_strike()


func get_attack_sound_id_for_weapon(weapon: Resource) -> StringName:
	if weapon == null:
		return StringName()
	match StringName(weapon.weapon_id):
		&"kitchen_knife":
			return &"knife_swing"
		&"baseball_bat":
			return &"bat_swing"
		&"pistol":
			return &"pistol_shot"
		&"shotgun":
			return &"shotgun_shot"
		_:
			if weapon.attack_mode == "melee":
				return &"knife_swing"
			return &"pistol_shot"


func get_attack_sound_pitch_for_weapon(weapon: Resource) -> float:
	if weapon == null:
		return 1.0
	match StringName(weapon.weapon_id):
		&"kitchen_knife":
			return randf_range(1.02, 1.1)
		&"baseball_bat":
			return randf_range(0.9, 0.98)
		&"pistol":
			return randf_range(0.99, 1.03)
		&"shotgun":
			return randf_range(0.94, 0.99)
		_:
			return randf_range(0.98, 1.04)


func get_attack_sound_volume_for_weapon(weapon: Resource) -> float:
	if weapon == null:
		return 0.0
	match StringName(weapon.weapon_id):
		&"kitchen_knife":
			return -3.5
		&"baseball_bat":
			return -1.5
		&"pistol":
			return -1.5
		&"shotgun":
			return -0.5
		_:
			return -1.5


func get_attack_impact_sound_id(impact_kind: String) -> StringName:
	if impact_kind == "enemy":
		return &"attack_hit_enemy"
	return &"attack_miss"


func get_attack_impact_volume(impact_kind: String) -> float:
	if impact_kind == "enemy":
		return -5.0
	return -8.0


func _get_melee_attack_targets() -> Array:
	return _get_enemy_targets_in_attack_shape()


func _get_enemy_targets_in_attack_shape() -> Array:
	var hit_targets: Array = []
	if player.attack_area_shape == null or player.attack_area_shape.shape == null:
		return hit_targets

	var shape_query := PhysicsShapeQueryParameters2D.new()
	shape_query.shape = player.attack_area_shape.shape
	shape_query.transform = player.attack_area.global_transform
	shape_query.collision_mask = player.attack_area.collision_mask
	shape_query.exclude = [player]

	for result in player.get_world_2d().direct_space_state.intersect_shape(shape_query):
		var body = result.get("collider")
		if body == null or body == player:
			continue
		if not body.is_in_group("enemies"):
			continue
		if not body.has_method("take_damage"):
			continue
		if _is_enemy_blocked_by_structure(body):
			continue
		hit_targets.append(body)
	return hit_targets


func _is_enemy_blocked_by_structure(enemy) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	var ray_query := PhysicsRayQueryParameters2D.create(player.attack_pivot.global_position, enemy.global_position)
	ray_query.exclude = [player]
	ray_query.collision_mask = STRUCTURE_ATTACK_BLOCKER_MASK
	var hit: Dictionary = player.get_world_2d().direct_space_state.intersect_ray(ray_query)
	return not hit.is_empty()


func _get_hitscan_attack_result(weapon: Resource) -> Dictionary:
	var candidates := _get_enemy_targets_in_attack_shape()

	var direct_space_state: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	var ray_start: Vector2 = player.attack_pivot.to_global(get_muzzle_local_position())
	var max_end: Vector2 = ray_start + player.facing_direction * float(weapon.attack_range)
	var miss_query := PhysicsRayQueryParameters2D.create(ray_start, max_end)
	miss_query.exclude = [player]
	var miss_hit: Dictionary = direct_space_state.intersect_ray(miss_query)
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
		ray_query.exclude = [player]
		var hit: Dictionary = direct_space_state.intersect_ray(ray_query)
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

	var direct_space_state: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	var ray_start: Vector2 = player.attack_pivot.to_global(get_muzzle_local_position())
	var max_end: Vector2 = ray_start + player.facing_direction * float(weapon.attack_range)
	var miss_query := PhysicsRayQueryParameters2D.create(ray_start, max_end)
	miss_query.exclude = [player]
	var miss_hit: Dictionary = direct_space_state.intersect_ray(miss_query)
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
		var angle_to_candidate: float = rad_to_deg(absf(player.facing_direction.angle_to(to_candidate.normalized())))
		var angle_padding_degrees := rad_to_deg(atan2(12.0, maxf(to_candidate.length(), 1.0)))
		if angle_to_candidate > max_angle_degrees + angle_padding_degrees:
			continue

		var ray_query := PhysicsRayQueryParameters2D.create(ray_start, candidate.global_position)
		ray_query.exclude = [player]
		var hit: Dictionary = direct_space_state.intersect_ray(ray_query)
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


func _emit_weapon_noise(weapon: Resource) -> void:
	if weapon == null:
		return
	if float(weapon.noise_radius) <= 0.0 or float(weapon.noise_alert_budget) <= 0.0:
		return
	player.weapon_noise_emitted.emit(player.global_position, float(weapon.noise_radius), float(weapon.noise_alert_budget), weapon.weapon_id)


func _show_attack_indicator_windup(duration: float) -> void:
	_stop_attack_indicator_tween()
	player.attack_indicator.color = player._attack_indicator_windup_color
	player.attack_indicator.scale = player._attack_indicator_windup_start_scale
	player.attack_indicator.modulate = Color(1.0, 1.0, 1.0, player._attack_indicator_windup_start_alpha)
	player.attack_indicator.visible = false
	if duration <= 0.0:
		return
	var tell_duration: float = min(player._attack_indicator_lead_time, duration)
	if tell_duration <= 0.0:
		return
	var tell_delay: float = max(duration - tell_duration, 0.0)
	player._attack_indicator_tween = create_tween()
	if tell_delay > 0.0:
		player._attack_indicator_tween.tween_interval(tell_delay)
	player._attack_indicator_tween.tween_callback(func() -> void:
		player.attack_indicator.visible = true
		player.attack_indicator.color = player._attack_indicator_windup_color
		player.attack_indicator.scale = player._attack_indicator_windup_start_scale
		player.attack_indicator.modulate = Color(1.0, 1.0, 1.0, player._attack_indicator_windup_start_alpha)
	)
	player._attack_indicator_tween.parallel().tween_property(player.attack_indicator, "scale", Vector2.ONE, max(tell_duration, 0.05))
	player._attack_indicator_tween.parallel().tween_property(player.attack_indicator, "modulate:a", player._attack_indicator_windup_end_alpha, max(tell_duration, 0.05))


func _show_attack_indicator_strike() -> void:
	_stop_attack_indicator_tween()
	player.attack_indicator.visible = true
	player.attack_indicator.color = player._attack_indicator_strike_color
	player.attack_indicator.scale = player._attack_indicator_strike_peak_scale
	player.attack_indicator.modulate = Color(1.0, 1.0, 1.0, player._attack_indicator_strike_alpha)
	player._attack_indicator_tween = create_tween()
	player._attack_indicator_tween.parallel().tween_property(player.attack_indicator, "scale", Vector2.ONE, player._attack_indicator_strike_fade_duration)
	player._attack_indicator_tween.parallel().tween_property(player.attack_indicator, "modulate:a", 0.0, player._attack_indicator_strike_fade_duration)
	player._attack_indicator_tween.finished.connect(func() -> void:
		_hide_attack_indicator()
	)


func _hide_attack_indicator() -> void:
	_stop_attack_indicator_tween()
	player.attack_indicator.visible = false
	player.attack_indicator.color = player._attack_indicator_windup_color
	player.attack_indicator.scale = Vector2.ONE
	player.attack_indicator.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _stop_attack_indicator_tween() -> void:
	if player._attack_indicator_tween != null and is_instance_valid(player._attack_indicator_tween):
		player._attack_indicator_tween.kill()
	player._attack_indicator_tween = null


func get_default_held_weapon_polygon() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-2, -10),
		Vector2(2, -10),
		Vector2(2, 8),
		Vector2(-2, 8),
	])


func get_default_held_weapon_polygon_offset() -> Vector2:
	return player.DEFAULT_HELD_WEAPON_OFFSET


func get_muzzle_local_position() -> Vector2:
	return player.weapon_visual.position + Vector2(0.0, -10.0)


func build_attack_damage_map(weapon: Resource, hit_targets: Array) -> Dictionary:
	var damage_map := {}
	if weapon == null:
		return damage_map

	var target_count := hit_targets.size()
	var apply_isolated_bonus := target_count == 1 and int(weapon.isolated_bonus_damage) > 0
	var apply_cluster_bonus := target_count >= 2 and int(weapon.cluster_bonus_damage) > 0
	var muzzle_position: Vector2 = player.attack_pivot.to_global(get_muzzle_local_position())
	var apply_close_range_bonus := int(weapon.close_range_bonus_damage) > 0 and float(weapon.close_range_bonus_distance) > 0.0

	for target in hit_targets:
		var damage_amount := int(weapon.damage)
		if apply_isolated_bonus:
			damage_amount += int(weapon.isolated_bonus_damage)
		if apply_cluster_bonus:
			damage_amount += int(weapon.cluster_bonus_damage)
		if apply_close_range_bonus and target != null and is_instance_valid(target):
			if muzzle_position.distance_to(target.global_position) <= float(weapon.close_range_bonus_distance):
				damage_amount += int(weapon.close_range_bonus_damage)
		damage_map[target] = damage_amount
	return damage_map


func apply_miss_recovery(weapon: Resource) -> void:
	if weapon == null:
		return
	player.attack_cooldown_remaining = max(player.attack_cooldown_remaining, float(weapon.miss_recovery_time))


func _play_attack_flash() -> void:
	player.attack_flash.visible = true
	player.attack_flash.scale = player._attack_flash_start_scale
	player.attack_flash.modulate = Color(player._attack_flash_color.r, player._attack_flash_color.g, player._attack_flash_color.b, 1.0)
	var tween := create_tween()
	tween.parallel().tween_property(player.attack_flash, "scale", player._attack_flash_peak_scale, player._attack_flash_duration)
	tween.parallel().tween_property(player.attack_flash, "modulate:a", 0.0, player._attack_flash_duration)
	tween.finished.connect(func() -> void:
		player.attack_flash.visible = false
		player.attack_flash.scale = Vector2.ONE
		player.attack_flash.modulate = Color(player._attack_flash_color.r, player._attack_flash_color.g, player._attack_flash_color.b, 1.0)
	)
	_show_attack_indicator_strike()


func _play_hitscan_effect(end_point: Vector2, impact_kind: String) -> void:
	_show_attack_indicator_strike()
	_play_muzzle_flash()
	_play_shot_tracer(end_point)
	_play_shot_impact(end_point, impact_kind)


func _play_muzzle_flash() -> void:
	player.muzzle_flash.visible = true
	player.muzzle_flash.position = get_muzzle_local_position()
	player.muzzle_flash.scale = player._muzzle_flash_scale * 0.72
	player.muzzle_flash.modulate = Color(player._muzzle_flash_color.r, player._muzzle_flash_color.g, player._muzzle_flash_color.b, 1.0)
	var tween := create_tween()
	tween.parallel().tween_property(player.muzzle_flash, "scale", player._muzzle_flash_scale, player._muzzle_flash_duration)
	tween.parallel().tween_property(player.muzzle_flash, "modulate:a", 0.0, player._muzzle_flash_duration)
	tween.finished.connect(func() -> void:
		player.muzzle_flash.visible = false
		player.muzzle_flash.scale = Vector2.ONE
		player.muzzle_flash.modulate = Color(player._muzzle_flash_color.r, player._muzzle_flash_color.g, player._muzzle_flash_color.b, 1.0)
	)


func _play_shot_tracer(end_point: Vector2) -> void:
	var muzzle_global: Vector2 = player.attack_pivot.to_global(get_muzzle_local_position())
	player.shot_tracer.visible = true
	player.shot_tracer.width = player._tracer_width
	player.shot_tracer.default_color = player._tracer_color
	player.shot_tracer.points = PackedVector2Array([
		player.to_local(muzzle_global),
		player.to_local(end_point),
	])
	player.shot_tracer.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var tween := create_tween()
	tween.tween_property(player.shot_tracer, "modulate:a", 0.0, player._tracer_duration)
	tween.finished.connect(func() -> void:
		player.shot_tracer.visible = false
		player.shot_tracer.points = PackedVector2Array()
		player.shot_tracer.modulate = Color(1.0, 1.0, 1.0, 1.0)
	)


func _play_shot_impact(end_point: Vector2, impact_kind: String) -> void:
	if player.shot_impact == null:
		return
	if player._shot_impact_tween != null and is_instance_valid(player._shot_impact_tween):
		player._shot_impact_tween.kill()

	var impact_color: Color = player._impact_hit_color if impact_kind == "enemy" else player._impact_block_color
	player.shot_impact.position = player.to_local(end_point)
	player.shot_impact.visible = true
	player.shot_impact.scale = Vector2.ONE * (player._impact_flash_scale * 0.7)
	player.shot_impact.color = impact_color
	player.shot_impact.modulate = Color(impact_color.r, impact_color.g, impact_color.b, 1.0)

	player._shot_impact_tween = create_tween()
	player._shot_impact_tween.parallel().tween_property(player.shot_impact, "scale", Vector2.ONE * player._impact_flash_scale, player._impact_flash_duration)
	player._shot_impact_tween.parallel().tween_property(player.shot_impact, "modulate:a", 0.0, player._impact_flash_duration)
	player._shot_impact_tween.finished.connect(func() -> void:
		player.shot_impact.visible = false
		player.shot_impact.scale = Vector2.ONE
		player.shot_impact.modulate = Color(1.0, 1.0, 1.0, 1.0)
	)


func _spawn_projectile_attack(weapon: Resource, attack_result: Dictionary, damage_map: Dictionary) -> void:
	if weapon == null:
		return
	var projectile_parent: Node = player.get_parent()
	if projectile_parent == null or not is_instance_valid(projectile_parent):
		return
	var muzzle_global: Vector2 = player.attack_pivot.to_global(get_muzzle_local_position())
	var resolved_end_point: Vector2 = attack_result.get("end_point", muzzle_global + player.facing_direction * float(weapon.attack_range))
	var hit_targets: Array = Array(attack_result.get("targets", []))
	if hit_targets.is_empty():
		var structure_hit: Dictionary = _get_structure_block_hit(player.attack_pivot.global_position, resolved_end_point)
		if not structure_hit.is_empty():
			var block_point: Vector2 = structure_hit.get("position", resolved_end_point)
			player._play_combat_sound(
				get_attack_impact_sound_id("structure"),
				randf_range(0.98, 1.04),
				get_attack_impact_volume("structure")
			)
			player._play_shot_impact(block_point, "structure")
			return
		var miss_direction: Vector2 = resolved_end_point - muzzle_global
		if miss_direction.is_zero_approx():
			miss_direction = player.facing_direction
		_spawn_player_projectile(
			projectile_parent,
			weapon,
			muzzle_global,
			miss_direction.normalized(),
			int(weapon.damage),
			minf(muzzle_global.distance_to(resolved_end_point), float(weapon.attack_range))
		)
		return
	for target in hit_targets:
		if target == null or not is_instance_valid(target):
			continue
		var target_direction: Vector2 = (target.global_position - muzzle_global).normalized()
		if target_direction.is_zero_approx():
			target_direction = player.facing_direction
		_spawn_player_projectile(
			projectile_parent,
			weapon,
			muzzle_global,
			target_direction,
			int(damage_map.get(target, weapon.damage)),
			minf(muzzle_global.distance_to(target.global_position), float(weapon.attack_range))
		)


func _spawn_player_projectile(projectile_parent: Node, weapon: Resource, origin: Vector2, direction: Vector2, damage: int, travel_range: float) -> void:
	var projectile = PlayerProjectileScene.instantiate()
	projectile_parent.add_child(projectile)
	projectile.configure({
		"attacker": player,
		"origin": origin,
		"direction": direction,
		"range": maxf(travel_range, 1.0),
		"speed": float(weapon.projectile_speed),
		"hit_radius": float(weapon.projectile_hit_radius),
		"damage": damage,
		"damage_type": weapon.damage_type,
		"knockback_force": float(weapon.knockback_force),
		"polygon": weapon.projectile_polygon,
		"color": weapon.projectile_color,
		"impact_color": weapon.projectile_impact_color,
	})


func _get_structure_block_hit(from_position: Vector2, to_position: Vector2) -> Dictionary:
	var ray_query := PhysicsRayQueryParameters2D.create(from_position, to_position)
	ray_query.exclude = [player]
	ray_query.collision_mask = STRUCTURE_ATTACK_BLOCKER_MASK
	return player.get_world_2d().direct_space_state.intersect_ray(ray_query)
