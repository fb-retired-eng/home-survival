extends Node
class_name ExplorationController

const EXPLORATION_SPAWN_POINT_SCRIPT := preload("res://scripts/world/exploration_spawn_point.gd")
const MICRO_LOOT_SPAWN_SCRIPT := preload("res://scripts/world/micro_loot_spawn.gd")
const ENEMY_DEFINITION_SCRIPT := preload("res://scripts/data/enemy_definition.gd")
const ROAMING_SPAWN_ZONE_SCRIPT := preload("res://scripts/world/roaming_spawn_zone.gd")

signal autosave_requested

var game_manager
var player
var sleep_point
var exploration_spawn_points_root
var roaming_spawn_zones_root
var micro_loot_spawns_root
var ambient_pickups_root
var exploration_enemy_layer
var exploration_enemy_scene: PackedScene
var resource_pickup_scene: PackedScene
var poi_controller

var roaming_early_enemies: Array[Resource] = []
var roaming_mid_enemies: Array[Resource] = []
var roaming_late_enemies: Array[Resource] = []

var _defeated_exploration_spawn_ids: Dictionary = {}
var _exploration_spawn_counts: Dictionary = {}
var _defeated_exploration_enemy_counts: Dictionary = {}
var _current_exploration_target_counts: Dictionary = {}
var _collected_micro_loot_ids: Dictionary = {}


func configure(config: Dictionary) -> void:
	game_manager = config.get("game_manager")
	player = config.get("player")
	sleep_point = config.get("sleep_point")
	exploration_spawn_points_root = config.get("exploration_spawn_points_root")
	roaming_spawn_zones_root = config.get("roaming_spawn_zones_root")
	micro_loot_spawns_root = config.get("micro_loot_spawns_root")
	ambient_pickups_root = config.get("ambient_pickups_root")
	exploration_enemy_layer = config.get("exploration_enemy_layer")
	exploration_enemy_scene = config.get("exploration_enemy_scene")
	resource_pickup_scene = config.get("resource_pickup_scene")
	poi_controller = config.get("poi_controller")
	roaming_early_enemies = config.get("roaming_early_enemies", [])
	roaming_mid_enemies = config.get("roaming_mid_enemies", [])
	roaming_late_enemies = config.get("roaming_late_enemies", [])


func reset_for_new_run() -> void:
	clear_exploration_enemies()
	_defeated_exploration_spawn_ids.clear()
	_exploration_spawn_counts.clear()
	_defeated_exploration_enemy_counts.clear()
	_current_exploration_target_counts.clear()
	_collected_micro_loot_ids.clear()


func enter_day_phase() -> void:
	_current_exploration_target_counts.clear()
	sync_exploration_enemies()
	spawn_roaming_exploration_enemies()


func validate_exploration_spawn_points() -> void:
	if exploration_spawn_points_root == null:
		return

	var seen_spawn_ids := {}
	for child in exploration_spawn_points_root.get_children():
		if child == null or child.get_script() != EXPLORATION_SPAWN_POINT_SCRIPT:
			continue

		if not child.is_valid_spawn_point():
			push_warning("Invalid exploration spawn point: %s" % child.name)
			continue

		var spawn_id := String(child.spawn_id)
		if seen_spawn_ids.has(spawn_id):
			push_warning("Duplicate exploration spawn_id in scene: %s" % spawn_id)
			continue

		seen_spawn_ids[spawn_id] = true


func validate_roaming_spawn_zones() -> void:
	if roaming_spawn_zones_root == null:
		return

	var seen_zone_ids := {}
	for child in roaming_spawn_zones_root.get_children():
		if child == null or child.get_script() != ROAMING_SPAWN_ZONE_SCRIPT:
			continue
		if child.has_method("is_valid_spawn_zone") and not child.is_valid_spawn_zone():
			push_warning("Invalid roaming spawn zone: %s" % child.name)
			continue
		var zone_id := String(child.zone_id)
		if seen_zone_ids.has(zone_id):
			push_warning("Duplicate roaming spawn zone_id in scene: %s" % zone_id)
			continue
		seen_zone_ids[zone_id] = true


func validate_micro_loot_spawns() -> void:
	if micro_loot_spawns_root == null or not is_instance_valid(micro_loot_spawns_root):
		return
	var seen_spawn_ids := {}
	for child in micro_loot_spawns_root.get_children():
		if child == null or child.get_script() != MICRO_LOOT_SPAWN_SCRIPT:
			continue
		if not child.is_valid_spawn():
			push_warning("Invalid micro-loot spawn: %s" % child.name)
			continue
		var spawn_id := String(child.spawn_id)
		if seen_spawn_ids.has(spawn_id):
			push_warning("Duplicate micro-loot spawn_id: %s" % spawn_id)
			continue
		seen_spawn_ids[spawn_id] = true


func on_player_weapon_noise_emitted(source_position: Vector2, noise_radius: float, noise_alert_budget: float, _weapon_id: StringName) -> void:
	if game_manager.run_state != game_manager.RunState.PRE_WAVE:
		return
	if exploration_enemy_layer == null or noise_radius <= 0.0 or noise_alert_budget <= 0.0:
		return

	var candidates: Array = []
	for child in exploration_enemy_layer.get_children():
		if not is_instance_valid(child):
			continue
		if child.is_queued_for_deletion():
			continue
		if child.get("targeting_controller") == null:
			continue
		if not can_enemy_hear_weapon_noise(child, source_position, noise_radius):
			continue
		candidates.append(child)

	candidates.sort_custom(func(a, b):
		return source_position.distance_squared_to(a.global_position) < source_position.distance_squared_to(b.global_position)
	)

	var remaining_budget := noise_alert_budget
	for enemy in candidates:
		var alert_weight := 1.0
		var enemy_targeting = enemy.get("targeting_controller")
		if enemy_targeting != null and enemy_targeting.has_method("get_noise_alert_weight"):
			alert_weight = float(enemy_targeting.get_noise_alert_weight())
		if alert_weight <= 0.0:
			continue
		if remaining_budget < alert_weight:
			continue
		enemy_targeting.receive_noise_alert(player, source_position)
		remaining_budget -= alert_weight


func can_enemy_hear_weapon_noise(enemy, source_position: Vector2, noise_radius: float) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	var distance_to_source: float = enemy.global_position.distance_to(source_position)
	if distance_to_source > noise_radius:
		return false

	var close_hearing_radius := minf(noise_radius, 96.0)
	if distance_to_source <= close_hearing_radius:
		return true

	var ray_query := PhysicsRayQueryParameters2D.create(source_position, enemy.global_position)
	ray_query.exclude = [player, enemy]
	for other_enemy in get_tree().get_nodes_in_group("enemies"):
		if other_enemy == enemy or not is_instance_valid(other_enemy):
			continue
		ray_query.exclude.append(other_enemy)
	var hit: Dictionary = get_viewport().world_2d.direct_space_state.intersect_ray(ray_query)
	return hit.is_empty() or hit.get("collider") == enemy


func sync_exploration_enemies() -> void:
	if game_manager.run_state != game_manager.RunState.PRE_WAVE:
		return

	if exploration_enemy_scene == null or exploration_spawn_points_root == null or exploration_enemy_layer == null:
		return

	var existing_by_spawn_id := {}
	for existing_enemy in exploration_enemy_layer.get_children():
		if not is_instance_valid(existing_enemy):
			continue
		if existing_enemy.is_queued_for_deletion():
			continue

		var existing_spawn_id := String(existing_enemy.get_meta("spawn_id", ""))
		if existing_spawn_id.is_empty():
			continue

		if not existing_by_spawn_id.has(existing_spawn_id):
			existing_by_spawn_id[existing_spawn_id] = []
		existing_by_spawn_id[existing_spawn_id].append(existing_enemy)
		if existing_enemy.has_method("set_exploration_suspended"):
			existing_enemy.set_exploration_suspended(false)
			if existing_enemy.has_method("configure_exploration_context"):
				var stored_facing: Vector2 = existing_enemy.get_meta("spawn_facing", Vector2.ZERO)
				var stored_anchor: Vector2 = existing_enemy.get_meta("spawn_anchor", existing_enemy.global_position)
				existing_enemy.configure_exploration_context(player, stored_facing, false, stored_anchor, false)

	var seen_spawn_ids := {}
	for child in exploration_spawn_points_root.get_children():
		if child == null or child.get_script() != EXPLORATION_SPAWN_POINT_SCRIPT:
			continue

		if not child.is_valid_spawn_point():
			push_warning("Invalid exploration spawn point: %s" % child.name)
			continue

		var spawn_id := String(child.spawn_id)
		if seen_spawn_ids.has(spawn_id):
			push_warning("Duplicate exploration spawn_id skipped: %s" % spawn_id)
			continue
		seen_spawn_ids[spawn_id] = true
		if _defeated_exploration_spawn_ids.has(spawn_id):
			continue

		var target_count: int = get_adjusted_exploration_spawn_count(child)
		var defeated_count := int(_defeated_exploration_enemy_counts.get(spawn_id, 0))
		var existing_count: int = 0
		if existing_by_spawn_id.has(spawn_id):
			existing_count = Array(existing_by_spawn_id.get(spawn_id, [])).size()

		var missing_count: int = max(target_count - defeated_count - existing_count, 0)
		for _spawn_index in range(missing_count):
			var enemy = exploration_enemy_scene.instantiate()
			enemy.definition = child.enemy_definition
			exploration_enemy_layer.add_child(enemy)
			enemy.global_position = get_exploration_spawn_position(child)
			if enemy.has_method("configure_runtime_context"):
				enemy.configure_runtime_context(player, exploration_enemy_layer, _get_placeables_root())
			enemy.set_meta("spawn_id", spawn_id)
			var initial_facing: Vector2 = Vector2.ZERO
			if child.has_method("get_initial_facing_vector"):
				initial_facing = child.get_initial_facing_vector()
			var anchor_position: Vector2 = enemy.global_position
			if child.has_method("get_anchor_position"):
				anchor_position = child.get_anchor_position()
			enemy.set_meta("spawn_facing", initial_facing)
			enemy.set_meta("spawn_anchor", anchor_position)
			if enemy.has_method("configure_exploration_context"):
				enemy.configure_exploration_context(player, initial_facing, true, anchor_position, true)
			if enemy.has_signal("died"):
				enemy.died.connect(_on_exploration_enemy_died.bind(spawn_id))


func spawn_roaming_exploration_enemies() -> void:
	if game_manager.run_state != game_manager.RunState.PRE_WAVE:
		return

	clear_roaming_exploration_enemies()
	if roaming_spawn_zones_root == null or exploration_enemy_scene == null or exploration_enemy_layer == null:
		return

	var enemy_pool := get_roaming_enemy_pool()
	if enemy_pool.is_empty():
		return

	var zones: Array = []
	for child in roaming_spawn_zones_root.get_children():
		if child == null or child.get_script() != ROAMING_SPAWN_ZONE_SCRIPT:
			continue
		if child.has_method("is_valid_spawn_zone") and not child.is_valid_spawn_zone():
			continue
		zones.append(child)

	if zones.is_empty():
		return

	var spawn_budget := get_roaming_spawn_budget()
	for _spawn_index in range(spawn_budget):
		var zone = choose_weighted_roaming_zone(zones)
		if zone == null:
			continue
		var enemy_definition: Resource = enemy_pool[randi() % enemy_pool.size()]
		if enemy_definition == null:
			continue
		var enemy = exploration_enemy_scene.instantiate()
		enemy.definition = enemy_definition
		exploration_enemy_layer.add_child(enemy)
		enemy.global_position = get_roaming_spawn_position(zone)
		if enemy.has_method("configure_runtime_context"):
			enemy.configure_runtime_context(player, exploration_enemy_layer, _get_placeables_root())
		enemy.set_meta("spawn_kind", "roaming")
		var initial_facing := Vector2.RIGHT.rotated(randf() * TAU)
		if enemy.has_method("configure_exploration_context"):
			enemy.configure_exploration_context(player, initial_facing, true, zone.global_position, true)


func clear_exploration_enemies() -> void:
	if exploration_enemy_layer == null:
		return
	for child in exploration_enemy_layer.get_children():
		child.queue_free()


func clear_roaming_exploration_enemies() -> void:
	if exploration_enemy_layer == null:
		return
	for child in exploration_enemy_layer.get_children():
		if not is_instance_valid(child):
			continue
		if String(child.get_meta("spawn_kind", "")) != "roaming":
			continue
		child.queue_free()


func set_exploration_enemies_suspended(suspended: bool) -> void:
	if exploration_enemy_layer == null:
		return
	for child in exploration_enemy_layer.get_children():
		if child.has_method("set_exploration_suspended"):
			child.set_exploration_suspended(suspended)


func has_sleep_blocking_exploration_threat() -> bool:
	if exploration_enemy_layer == null:
		return false
	for child in exploration_enemy_layer.get_children():
		if not is_instance_valid(child):
			continue
		if child.has_method("is_engaged_with_player") and child.is_engaged_with_player():
			return true
	return false


func get_save_state() -> Dictionary:
	var saved_defeated_spawns: Array[String] = []
	for spawn_id_variant in _defeated_exploration_spawn_ids.keys():
		saved_defeated_spawns.append(String(spawn_id_variant))

	var saved_collected_micro_loot: Array[String] = []
	for loot_id_variant in _collected_micro_loot_ids.keys():
		saved_collected_micro_loot.append(String(loot_id_variant))

	return {
		"defeated_exploration_spawn_ids": saved_defeated_spawns,
		"exploration_spawn_counts": _exploration_spawn_counts.duplicate(true),
		"defeated_exploration_enemy_counts": _defeated_exploration_enemy_counts.duplicate(true),
		"current_exploration_target_counts": _current_exploration_target_counts.duplicate(true),
		"collected_micro_loot_ids": saved_collected_micro_loot,
	}


func apply_game_state(game_state: Dictionary) -> void:
	_defeated_exploration_spawn_ids.clear()
	for raw_spawn_id in game_state.get("defeated_exploration_spawn_ids", []):
		_defeated_exploration_spawn_ids[String(raw_spawn_id)] = true

	_replace_int_dictionary(_exploration_spawn_counts, game_state.get("exploration_spawn_counts", {}))
	_replace_int_dictionary(_defeated_exploration_enemy_counts, game_state.get("defeated_exploration_enemy_counts", {}))
	_replace_int_dictionary(_current_exploration_target_counts, game_state.get("current_exploration_target_counts", {}))

	_collected_micro_loot_ids.clear()
	for raw_loot_id in game_state.get("collected_micro_loot_ids", []):
		_collected_micro_loot_ids[StringName(raw_loot_id)] = true


func spawn_micro_loot_pickups() -> void:
	if ambient_pickups_root == null or not is_instance_valid(ambient_pickups_root):
		return
	for child in ambient_pickups_root.get_children():
		if is_instance_valid(child):
			child.queue_free()
	if resource_pickup_scene == null or micro_loot_spawns_root == null or not is_instance_valid(micro_loot_spawns_root):
		return
	for child in micro_loot_spawns_root.get_children():
		if child == null or child.get_script() != MICRO_LOOT_SPAWN_SCRIPT:
			continue
		if not child.is_valid_spawn():
			continue
		if _collected_micro_loot_ids.has(StringName(child.spawn_id)):
			continue
		var pickup = resource_pickup_scene.instantiate()
		var resolved_spawn_data := {
			"resource_id": child.resource_id,
			"amount": int(child.amount),
		}
		if poi_controller != null:
			resolved_spawn_data = poi_controller.resolve_micro_loot_spawn_defaults(child)
		pickup.resource_id = String(resolved_spawn_data.get("resource_id", child.resource_id))
		pickup.amount = int(resolved_spawn_data.get("amount", int(child.amount)))
		pickup.global_position = child.global_position
		pickup.set_meta("micro_loot_spawn_id", StringName(child.spawn_id))
		if pickup.has_signal("collected"):
			pickup.collected.connect(_on_micro_loot_collected)
		ambient_pickups_root.add_child(pickup)


func get_adjusted_exploration_spawn_count(spawn_point) -> int:
	if poi_controller == null:
		return 1
	return poi_controller.get_adjusted_exploration_spawn_count(spawn_point, _current_exploration_target_counts, _exploration_spawn_counts)


func get_base_exploration_spawn_count(spawn_point) -> int:
	if poi_controller == null:
		return 1
	return poi_controller.get_or_roll_exploration_spawn_count(spawn_point, _exploration_spawn_counts)


func get_exploration_spawn_point_by_id(spawn_id: String):
	if exploration_spawn_points_root == null:
		return null
	for child in exploration_spawn_points_root.get_children():
		if child == null or child.get_script() != EXPLORATION_SPAWN_POINT_SCRIPT:
			continue
		if String(child.spawn_id) == spawn_id:
			return child
	return null


func get_roaming_enemy_pool() -> Array[Resource]:
	var pool: Array[Resource] = []
	if game_manager.current_wave <= 1:
		pool = roaming_early_enemies
	elif game_manager.current_wave <= 4:
		pool = roaming_mid_enemies
	else:
		pool = roaming_late_enemies

	var valid_pool: Array[Resource] = []
	for enemy_definition in pool:
		if enemy_definition == null or enemy_definition.get_script() != ENEMY_DEFINITION_SCRIPT:
			continue
		if not enemy_definition.is_valid_definition():
			continue
		valid_pool.append(enemy_definition)
	return valid_pool


func get_roaming_spawn_budget() -> int:
	if game_manager.current_wave <= 0:
		return 3
	if game_manager.current_wave <= 3:
		return 4
	if game_manager.current_wave <= 5:
		return 5
	return 6


func choose_weighted_roaming_zone(zones: Array):
	if zones.is_empty():
		return null
	var total_weight := 0.0
	for zone in zones:
		total_weight += float(zone.spawn_weight)
	if total_weight <= 0.0:
		return zones[randi() % zones.size()]

	var roll := randf() * total_weight
	for zone in zones:
		roll -= float(zone.spawn_weight)
		if roll <= 0.0:
			return zone
	return zones.back()


func get_roaming_spawn_position(zone) -> Vector2:
	var base_position: Vector2 = zone.global_position
	var scatter_radius: float = float(zone.scatter_radius)
	if scatter_radius <= 0.0:
		return base_position

	var base_safe_radius := 260.0
	var best_position := base_position
	var best_score := -INF
	for _attempt in range(10):
		var angle := randf() * TAU
		var distance := randf() * scatter_radius
		var candidate := base_position + Vector2.RIGHT.rotated(angle) * distance
		var distance_from_base := candidate.distance_to(sleep_point.global_position)
		if distance_from_base < base_safe_radius:
			continue
		var nearest_distance := scatter_radius
		for child in exploration_enemy_layer.get_children():
			if not is_instance_valid(child):
				continue
			nearest_distance = min(nearest_distance, candidate.distance_to(child.global_position))
		if nearest_distance > best_score:
			best_score = nearest_distance
			best_position = candidate

	return best_position


func get_exploration_spawn_position(spawn_point) -> Vector2:
	var base_position: Vector2 = spawn_point.global_position
	var scatter_radius: float = float(spawn_point.scatter_radius)
	if scatter_radius <= 0.0:
		return base_position

	var best_position := base_position
	var best_distance := -INF
	for _attempt in range(8):
		var angle := randf() * TAU
		var distance := randf() * scatter_radius
		var candidate := base_position + Vector2.RIGHT.rotated(angle) * distance
		var nearest_distance := scatter_radius
		for child in exploration_enemy_layer.get_children():
			if not is_instance_valid(child):
				continue
			nearest_distance = min(nearest_distance, candidate.distance_to(child.global_position))
		if nearest_distance > best_distance:
			best_distance = nearest_distance
			best_position = candidate

	return best_position


func _on_exploration_enemy_died(enemy, spawn_id: String) -> void:
	var defeated_count := int(_defeated_exploration_enemy_counts.get(spawn_id, 0)) + 1
	_defeated_exploration_enemy_counts[spawn_id] = defeated_count
	var target_count := int(_current_exploration_target_counts.get(spawn_id, 0))
	if target_count <= 0:
		var spawn_point = get_exploration_spawn_point_by_id(spawn_id)
		if spawn_point != null:
			target_count = get_adjusted_exploration_spawn_count(spawn_point)
		else:
			target_count = int(_exploration_spawn_counts.get(spawn_id, 1))
	var remaining_live_count := _count_live_exploration_enemies_for_spawn_id(spawn_id, enemy)
	if defeated_count >= target_count and remaining_live_count <= 0:
		_defeated_exploration_spawn_ids[spawn_id] = true


func _count_live_exploration_enemies_for_spawn_id(spawn_id: String, excluded_enemy = null) -> int:
	if exploration_enemy_layer == null:
		return 0
	var count := 0
	for child in exploration_enemy_layer.get_children():
		if child == excluded_enemy:
			continue
		if not is_instance_valid(child):
			continue
		if child.is_queued_for_deletion():
			continue
		if String(child.get_meta("spawn_id", "")) != spawn_id:
			continue
		count += 1
	return count


func _on_micro_loot_collected(pickup, _collector) -> void:
	if pickup == null or not is_instance_valid(pickup):
		return
	var spawn_id := StringName(pickup.get_meta("micro_loot_spawn_id", StringName()))
	if spawn_id == StringName():
		return
	_collected_micro_loot_ids[spawn_id] = true
	autosave_requested.emit()


func _replace_int_dictionary(target: Dictionary, raw_dictionary: Dictionary) -> void:
	target.clear()
	for key in raw_dictionary.keys():
		target[String(key)] = int(raw_dictionary[key])


func _get_placeables_root() -> Node:
	if exploration_enemy_layer == null or not is_instance_valid(exploration_enemy_layer):
		return null
	var world_root: Node = exploration_enemy_layer.get_parent()
	if world_root == null or not is_instance_valid(world_root):
		return null
	return world_root.get_node_or_null("ConstructionPlaceables")
