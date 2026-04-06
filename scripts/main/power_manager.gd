extends Node
class_name PowerManager

signal power_status_changed(used_slots: int, max_slots: int)

const REFRESH_INTERVAL := 0.15
const RUNTIME_TICK_INTERVAL := 0.1

var hud
var player
var game_manager
var mvp2_run_controller = null
var construction_placeables: Node
var exploration_enemy_layer: Node
var wave_enemy_layer: Node
var generator_world_position: Vector2 = Vector2.ZERO
var power_radius: float = 260.0
var max_load_slots: int = 3
var max_upgrade_level: int = 3
var upgrade_battery_cost: int = 1

var _refresh_remaining: float = 0.0
var _used_load_slots: int = 0
var _base_load_slots: int = 3
var _runtime_tick_remaining: float = 0.0
var _turret_cooldowns_by_id: Dictionary = {}
var _turret_target_ids_by_id: Dictionary = {}
var _utility_cooldowns_by_id: Dictionary = {}
var _utility_safe_phase_used_by_id: Dictionary = {}


func configure(config: Dictionary) -> void:
	game_manager = config.get("game_manager")
	hud = config.get("hud")
	player = config.get("player")
	construction_placeables = config.get("construction_placeables")
	exploration_enemy_layer = config.get("exploration_enemy_layer")
	wave_enemy_layer = config.get("wave_enemy_layer")
	generator_world_position = config.get("generator_world_position", generator_world_position)
	power_radius = float(config.get("power_radius", power_radius))
	max_load_slots = int(config.get("max_load_slots", max_load_slots))
	_base_load_slots = max(max_load_slots, 0)
	if game_manager != null and is_instance_valid(game_manager) and not game_manager.run_state_changed.is_connected(_on_run_state_changed):
		game_manager.run_state_changed.connect(_on_run_state_changed)
	set_process(true)
	_refresh_power_state()


func _process(delta: float) -> void:
	_refresh_remaining = maxf(_refresh_remaining - delta, 0.0)
	_runtime_tick_remaining = maxf(_runtime_tick_remaining - delta, 0.0)
	if _refresh_remaining > 0.0:
		if _runtime_tick_remaining <= 0.0:
			_runtime_tick_remaining = RUNTIME_TICK_INTERVAL
			_process_powered_runtime()
		return
	_refresh_remaining = REFRESH_INTERVAL
	_refresh_power_state()
	if _runtime_tick_remaining <= 0.0:
		_runtime_tick_remaining = RUNTIME_TICK_INTERVAL
	_process_powered_runtime()


func reset_for_new_run() -> void:
	max_load_slots = _base_load_slots
	_used_load_slots = 0
	_refresh_remaining = 0.0
	_runtime_tick_remaining = 0.0
	_turret_cooldowns_by_id.clear()
	_turret_target_ids_by_id.clear()
	_utility_cooldowns_by_id.clear()
	_utility_safe_phase_used_by_id.clear()
	_refresh_power_state()


func get_save_state() -> Dictionary:
	return {
		"max_load_slots": max_load_slots,
	}


func apply_save_state(save_state: Dictionary) -> void:
	max_load_slots = max(int(save_state.get("max_load_slots", max_load_slots)), 0)
	_refresh_remaining = 0.0
	_runtime_tick_remaining = 0.0
	_turret_cooldowns_by_id.clear()
	_turret_target_ids_by_id.clear()
	_utility_cooldowns_by_id.clear()
	_utility_safe_phase_used_by_id.clear()
	_refresh_power_state()


func can_upgrade_generator(player) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if max_load_slots >= 3 + max_upgrade_level:
		return false
	return int(player.resources.get("battery", 0)) >= upgrade_battery_cost


func get_generator_interaction_label(player) -> String:
	if max_load_slots >= 3 + max_upgrade_level:
		return "Generator fully upgraded"
	if player == null or not is_instance_valid(player):
		return ""
	if int(player.resources.get("battery", 0)) < upgrade_battery_cost:
		return "Upgrade Generator (need %d Battery)" % upgrade_battery_cost
	return "Upgrade Generator (%d Battery)" % upgrade_battery_cost


func upgrade_generator(player) -> bool:
	if not can_upgrade_generator(player):
		return false
	if not player.spend_resource("battery", upgrade_battery_cost):
		return false
	max_load_slots += 1
	_refresh_remaining = 0.0
	_refresh_power_state()
	return true


func _refresh_power_state() -> void:
	var candidates: Array[Dictionary] = []
	if construction_placeables != null and is_instance_valid(construction_placeables):
		for child in construction_placeables.get_children():
			if child == null or not is_instance_valid(child):
				continue
			if not child.has_method("requires_power") or not bool(child.requires_power()):
				if child.has_method("set_powered"):
					child.set_powered(false)
				continue
			var draw: int = int(child.get_power_draw())
			if draw <= 0:
				if child.has_method("set_powered"):
					child.set_powered(false)
				continue
			var distance: float = child.global_position.distance_to(generator_world_position)
			candidates.append({
				"placeable": child,
				"draw": draw,
				"distance": distance,
			})

	_used_load_slots = 0
	var power_sources: Array[Dictionary] = [{
		"position": generator_world_position,
		"radius": power_radius,
	}]
	for candidate in candidates:
		var placeable = candidate.get("placeable")
		if placeable == null or not is_instance_valid(placeable):
			continue
		placeable.set_powered(false)

	var unresolved: Array[Dictionary] = candidates.duplicate()
	var progressed := true
	while progressed and not unresolved.is_empty():
		progressed = false
		unresolved.sort_custom(func(a, b):
			return _get_best_power_source_distance(a.get("placeable"), power_sources) < _get_best_power_source_distance(b.get("placeable"), power_sources)
		)
		var still_unresolved: Array[Dictionary] = []
		for candidate in unresolved:
			var placeable = candidate.get("placeable")
			if placeable == null or not is_instance_valid(placeable):
				continue
			var draw: int = int(candidate.get("draw", 0))
			var source_distance: float = _get_best_power_source_distance(placeable, power_sources)
			var source_radius: float = _get_best_power_source_radius(placeable, power_sources)
			var powered: bool = source_distance <= source_radius and _used_load_slots + draw <= max_load_slots
			placeable.set_powered(powered)
			if powered:
				_used_load_slots += draw
				progressed = true
				if _is_power_relay(placeable):
					power_sources.append({
						"position": placeable.global_position,
						"radius": _get_power_relay_radius(placeable),
					})
			else:
				still_unresolved.append(candidate)
		unresolved = still_unresolved

	if hud != null and is_instance_valid(hud) and hud.has_method("set_power_status"):
		hud.set_power_status(_used_load_slots, max_load_slots)
	power_status_changed.emit(_used_load_slots, max_load_slots)


func _process_powered_runtime() -> void:
	if construction_placeables == null or not is_instance_valid(construction_placeables):
		return
	_prune_stale_turret_targets()
	_decay_turret_cooldowns(RUNTIME_TICK_INTERVAL)
	_decay_utility_cooldowns(RUNTIME_TICK_INTERVAL)
	for child in construction_placeables.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if not child.has_method("is_powered") or not bool(child.is_powered()):
			continue
		var profile: Resource = child.get("profile")
		if profile == null:
			continue
		match String(profile.category):
			"turret":
				_process_turret_runtime(child, profile)
			"utility":
				_process_utility_runtime(child, profile)
			_:
				continue


func _prune_stale_turret_targets() -> void:
	var live_turret_ids: Dictionary = {}
	var live_utility_ids: Dictionary = {}
	if construction_placeables != null and is_instance_valid(construction_placeables):
		for child in construction_placeables.get_children():
			if child == null or not is_instance_valid(child):
				continue
			if not child.has_method("requires_power") or not bool(child.requires_power()):
				continue
			var profile: Resource = child.get("profile")
			if profile == null:
				continue
			if String(profile.category) == "turret":
				live_turret_ids[int(child.get_instance_id())] = true
			elif String(profile.category) == "utility":
				live_utility_ids[int(child.get_instance_id())] = true

	for turret_id_variant in _turret_target_ids_by_id.keys():
		var turret_id: int = int(turret_id_variant)
		if not bool(live_turret_ids.get(turret_id, false)):
			_turret_target_ids_by_id.erase(turret_id)
			_turret_cooldowns_by_id.erase(turret_id)

	for utility_id_variant in _utility_cooldowns_by_id.keys():
		var utility_id: int = int(utility_id_variant)
		if not bool(live_utility_ids.get(utility_id, false)):
			_utility_cooldowns_by_id.erase(utility_id)
			_utility_safe_phase_used_by_id.erase(utility_id)


func _decay_turret_cooldowns(delta: float) -> void:
	var stale_ids: Array[int] = []
	for instance_id_variant in _turret_cooldowns_by_id.keys():
		var instance_id: int = int(instance_id_variant)
		var remaining: float = maxf(float(_turret_cooldowns_by_id.get(instance_id, 0.0)) - delta, 0.0)
		if remaining <= 0.0:
			stale_ids.append(instance_id)
		else:
			_turret_cooldowns_by_id[instance_id] = remaining
	for stale_id in stale_ids:
		_turret_cooldowns_by_id.erase(stale_id)


func _decay_utility_cooldowns(delta: float) -> void:
	var stale_ids: Array[int] = []
	for instance_id_variant in _utility_cooldowns_by_id.keys():
		var instance_id: int = int(instance_id_variant)
		var remaining: float = maxf(float(_utility_cooldowns_by_id.get(instance_id, 0.0)) - delta, 0.0)
		if remaining <= 0.0:
			stale_ids.append(instance_id)
		else:
			_utility_cooldowns_by_id[instance_id] = remaining
	for stale_id in stale_ids:
		_utility_cooldowns_by_id.erase(stale_id)


func _is_damageable_target_alive(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not target.has_method("take_damage"):
		return false
	var current_health_variant = target.get("current_health")
	if current_health_variant == null:
		return true
	return int(current_health_variant) > 0


func _resolve_turret_target(placeable, max_range: float):
	var turret_instance_id: int = int(placeable.get_instance_id())
	var preferred_target_id: int = int(_turret_target_ids_by_id.get(turret_instance_id, 0))
	if preferred_target_id != 0:
		var preferred_target = instance_from_id(preferred_target_id)
		if _is_damageable_target_alive(preferred_target):
			if preferred_target.global_position.distance_to(placeable.global_position) <= max_range:
				return preferred_target
		_turret_target_ids_by_id.erase(turret_instance_id)

	var resolved_target = _get_closest_enemy_in_range(placeable.global_position, max_range)
	if resolved_target != null and is_instance_valid(resolved_target):
		_turret_target_ids_by_id[turret_instance_id] = int(resolved_target.get_instance_id())
	return resolved_target


func _process_turret_runtime(placeable, profile: Resource) -> void:
	var instance_id: int = int(placeable.get_instance_id())
	if float(_turret_cooldowns_by_id.get(instance_id, 0.0)) > 0.0:
		return
	var target = _resolve_turret_target(placeable, float(profile.fire_range))
	if target == null:
		_turret_target_ids_by_id.erase(instance_id)
		return
	var damage: int = max(int(profile.attack_damage), 0)
	if damage <= 0:
		return
	var bullet_cost: int = int(profile.bullet_cost_per_shot)
	if bullet_cost > 0:
		if player == null or not is_instance_valid(player) or not player.spend_resource("bullets", bullet_cost):
			return
	target.take_damage(damage, {
		"attacker": placeable,
		"damage_type": &"turret",
		"knockback_force": 90.0,
	})
	if not _is_damageable_target_alive(target):
		_turret_target_ids_by_id.erase(instance_id)
	if placeable.has_method("_play_combat_sound"):
		placeable._play_combat_sound(&"player_gun_shot", randf_range(0.96, 1.02), -6.0)
	_turret_cooldowns_by_id[instance_id] = maxf(float(profile.fire_interval), 0.1)


func _process_utility_runtime(placeable, profile: Resource) -> void:
	match String(profile.placeable_id):
		"floodlight":
			_process_floodlight_runtime(placeable, profile)
		"power_relay":
			return
		"alarm_beacon":
			_process_alarm_beacon_runtime(placeable, profile)
		"repair_station":
			_process_repair_station_runtime(placeable, profile)
		"ammo_locker":
			_process_ammo_locker_runtime(placeable, profile)
		_:
			return


func _process_floodlight_runtime(placeable, profile: Resource) -> void:
	var slow_factor: float = clampf(float(profile.slow_factor), 0.0, 1.0)
	if mvp2_run_controller != null:
		slow_factor = clampf(slow_factor - float(mvp2_run_controller.get_mutator_floodlight_slow_bonus()), 0.0, 1.0)
	if slow_factor <= 0.0:
		return
	for enemy in _get_enemies_in_range(placeable.global_position, float(profile.fire_range)):
		if enemy.has_method("apply_external_slow"):
			enemy.apply_external_slow(slow_factor, 0.35)


func _process_alarm_beacon_runtime(placeable, profile: Resource) -> void:
	if not _is_active_wave():
		return
	var instance_id: int = int(placeable.get_instance_id())
	if float(_utility_cooldowns_by_id.get(instance_id, 0.0)) > 0.0:
		return
	var alerted := false
	for enemy in _get_enemies_in_range(placeable.global_position, float(profile.lure_radius)):
		var targeting_controller = enemy.get("targeting_controller")
		if targeting_controller == null or not is_instance_valid(targeting_controller):
			continue
		if not targeting_controller.has_method("receive_noise_alert"):
			continue
		targeting_controller.receive_noise_alert(player, placeable.global_position)
		alerted = true
	if alerted and placeable.has_method("_play_combat_sound"):
		placeable._play_combat_sound(&"player_gun_shot", randf_range(1.18, 1.28), -12.0)
	_utility_cooldowns_by_id[instance_id] = maxf(float(profile.fire_interval), 0.25)


func _process_repair_station_runtime(placeable, profile: Resource) -> void:
	if not _is_safe_build_phase():
		return
	var instance_id: int = int(placeable.get_instance_id())
	if bool(_utility_safe_phase_used_by_id.get(instance_id, false)):
		return
	if float(_utility_cooldowns_by_id.get(instance_id, 0.0)) > 0.0:
		return
	var repaired := false
	var repair_amount: int = max(int(profile.effect_amount), 0)
	if repair_amount <= 0:
		return
	for other in _get_placeables_in_range(placeable.global_position, float(profile.fire_range)):
		if other == placeable:
			continue
		var other_profile: Resource = other.get("profile")
		if other_profile == null:
			continue
		var max_hp: int = int(other_profile.max_hp)
		var current_hp: int = int(other.get("current_hp"))
		if current_hp <= 0 or current_hp >= max_hp:
			continue
		other.current_hp = min(current_hp + repair_amount, max_hp)
		if other.has_signal("state_changed"):
			other.emit_signal("state_changed", other)
		repaired = true
	if repaired and placeable.has_method("_play_combat_sound"):
		placeable._play_combat_sound(&"build_repair", randf_range(1.02, 1.08), -14.0)
	if repaired:
		_utility_safe_phase_used_by_id[instance_id] = true
	_utility_cooldowns_by_id[instance_id] = maxf(float(profile.fire_interval), 0.25)


func _process_ammo_locker_runtime(placeable, profile: Resource) -> void:
	if not _is_safe_build_phase():
		return
	if player == null or not is_instance_valid(player):
		return
	if player.global_position.distance_to(placeable.global_position) > float(profile.fire_range):
		return
	var instance_id: int = int(placeable.get_instance_id())
	if bool(_utility_safe_phase_used_by_id.get(instance_id, false)):
		return
	if float(_utility_cooldowns_by_id.get(instance_id, 0.0)) > 0.0:
		return
	var ammo_grant: int = max(int(profile.effect_amount), 0)
	if ammo_grant <= 0:
		return
	player.add_resource("bullets", ammo_grant, false)
	if placeable.has_method("_play_combat_sound"):
		placeable._play_combat_sound(&"build_place", randf_range(1.08, 1.14), -16.0)
	_utility_safe_phase_used_by_id[instance_id] = true
	_utility_cooldowns_by_id[instance_id] = maxf(float(profile.fire_interval), 0.25)


func _get_closest_enemy_in_range(origin: Vector2, max_range: float):
	var best_enemy = null
	var best_distance := INF
	for enemy in _get_enemies_in_range(origin, max_range):
		var distance: float = enemy.global_position.distance_squared_to(origin)
		if distance < best_distance:
			best_distance = distance
			best_enemy = enemy
	return best_enemy


func _get_enemies_in_range(origin: Vector2, max_range: float) -> Array:
	var targets: Array = []
	if max_range <= 0.0:
		return targets
	var max_distance_sq: float = max_range * max_range
	for layer in [exploration_enemy_layer, wave_enemy_layer]:
		if layer == null or not is_instance_valid(layer):
			continue
		for child in layer.get_children():
			if child == null or not is_instance_valid(child) or not child.has_method("take_damage"):
				continue
			if child.global_position.distance_squared_to(origin) > max_distance_sq:
				continue
			targets.append(child)
	return targets


func _get_placeables_in_range(origin: Vector2, max_range: float) -> Array:
	var targets: Array = []
	if construction_placeables == null or not is_instance_valid(construction_placeables) or max_range <= 0.0:
		return targets
	var max_distance_sq: float = max_range * max_range
	for child in construction_placeables.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if child.global_position.distance_squared_to(origin) > max_distance_sq:
			continue
		targets.append(child)
	return targets


func _is_active_wave() -> bool:
	return game_manager != null and is_instance_valid(game_manager) and game_manager.run_state == game_manager.RunState.ACTIVE_WAVE


func _is_safe_build_phase() -> bool:
	if game_manager == null or not is_instance_valid(game_manager):
		return true
	return game_manager.run_state == game_manager.RunState.PRE_WAVE or game_manager.run_state == game_manager.RunState.POST_WAVE


func _on_run_state_changed(_new_state: int) -> void:
	_utility_safe_phase_used_by_id.clear()


func _sort_candidates(a: Dictionary, b: Dictionary) -> bool:
	var a_in_radius: bool = bool(a.get("in_radius", false))
	var b_in_radius: bool = bool(b.get("in_radius", false))
	if a_in_radius != b_in_radius:
		return a_in_radius and not b_in_radius
	return float(a.get("distance", INF)) < float(b.get("distance", INF))


func _get_best_power_source_distance(placeable, power_sources: Array[Dictionary]) -> float:
	var best_distance := INF
	for source in power_sources:
		best_distance = minf(best_distance, placeable.global_position.distance_to(Vector2(source.get("position", Vector2.ZERO))))
	return best_distance


func _get_best_power_source_radius(placeable, power_sources: Array[Dictionary]) -> float:
	var best_radius := 0.0
	var best_distance := INF
	for source in power_sources:
		var distance: float = placeable.global_position.distance_to(Vector2(source.get("position", Vector2.ZERO)))
		if distance < best_distance:
			best_distance = distance
			best_radius = float(source.get("radius", 0.0))
	return best_radius


func _is_power_relay(placeable) -> bool:
	return placeable != null and is_instance_valid(placeable) and StringName(placeable.get_placeable_id()) == &"power_relay"


func _get_power_relay_radius(placeable) -> float:
	var profile: Resource = placeable.get("profile")
	if profile == null:
		return 0.0
	return float(profile.fire_range)
