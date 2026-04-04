extends Node
class_name PowerManager

signal power_status_changed(used_slots: int, max_slots: int)

const REFRESH_INTERVAL := 0.15
const RUNTIME_TICK_INTERVAL := 0.1

var hud
var player
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


func configure(config: Dictionary) -> void:
	hud = config.get("hud")
	player = config.get("player")
	construction_placeables = config.get("construction_placeables")
	exploration_enemy_layer = config.get("exploration_enemy_layer")
	wave_enemy_layer = config.get("wave_enemy_layer")
	generator_world_position = config.get("generator_world_position", generator_world_position)
	power_radius = float(config.get("power_radius", power_radius))
	max_load_slots = int(config.get("max_load_slots", max_load_slots))
	_base_load_slots = max(max_load_slots, 0)
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
				"in_radius": distance <= power_radius,
			})

	candidates.sort_custom(_sort_candidates)
	_used_load_slots = 0
	for candidate in candidates:
		var placeable = candidate.get("placeable")
		if placeable == null or not is_instance_valid(placeable):
			continue
		var in_radius: bool = bool(candidate.get("in_radius", false))
		var draw: int = int(candidate.get("draw", 0))
		var powered: bool = in_radius and _used_load_slots + draw <= max_load_slots
		placeable.set_powered(powered)
		if powered:
			_used_load_slots += draw

	if hud != null and is_instance_valid(hud) and hud.has_method("set_power_status"):
		hud.set_power_status(_used_load_slots, max_load_slots)
	power_status_changed.emit(_used_load_slots, max_load_slots)


func _process_powered_runtime() -> void:
	if construction_placeables == null or not is_instance_valid(construction_placeables):
		return
	_decay_turret_cooldowns(RUNTIME_TICK_INTERVAL)
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
				_process_floodlight_runtime(child, profile)
			_:
				continue


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


func _process_turret_runtime(placeable, profile: Resource) -> void:
	var instance_id: int = int(placeable.get_instance_id())
	if float(_turret_cooldowns_by_id.get(instance_id, 0.0)) > 0.0:
		return
	var target = _get_closest_enemy_in_range(placeable.global_position, float(profile.fire_range))
	if target == null:
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
	if placeable.has_method("_play_combat_sound"):
		placeable._play_combat_sound(&"player_gun_shot", randf_range(0.96, 1.02), -6.0)
	_turret_cooldowns_by_id[instance_id] = maxf(float(profile.fire_interval), 0.1)


func _process_floodlight_runtime(placeable, profile: Resource) -> void:
	var slow_factor: float = clampf(float(profile.slow_factor), 0.0, 1.0)
	if slow_factor <= 0.0:
		return
	for enemy in _get_enemies_in_range(placeable.global_position, float(profile.fire_range)):
		if enemy.has_method("apply_external_slow"):
			enemy.apply_external_slow(slow_factor, 0.35)


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


func _sort_candidates(a: Dictionary, b: Dictionary) -> bool:
	var a_in_radius: bool = bool(a.get("in_radius", false))
	var b_in_radius: bool = bool(b.get("in_radius", false))
	if a_in_radius != b_in_radius:
		return a_in_radius and not b_in_radius
	return float(a.get("distance", INF)) < float(b.get("distance", INF))
