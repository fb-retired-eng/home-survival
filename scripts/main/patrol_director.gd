extends Node
class_name PatrolDirector

const PATROL_ROUTE_POINT_SCRIPT := preload("res://scripts/world/patrol_route_point.gd")
const ENEMY_DEFINITION_SCRIPT := preload("res://scripts/data/enemy_definition.gd")

signal patrol_enemy_defeated()

var game_manager
var player
var patrol_routes_root
var exploration_enemy_layer
var exploration_enemy_scene: PackedScene
var placeables_root

var patrol_enemy_definitions: Array[Resource] = []

var _route_points_by_id: Dictionary = {}
var _patrol_states_by_enemy_id: Dictionary = {}
var _saved_patrol_spawn_states: Array[Dictionary] = []
var _day_patrols_spawned: bool = false
var _saved_day_patrols_spawned: bool = false
var _active_mutator = null


func configure(config: Dictionary) -> void:
	game_manager = config.get("game_manager")
	player = config.get("player")
	patrol_routes_root = config.get("patrol_routes_root")
	exploration_enemy_layer = config.get("exploration_enemy_layer")
	exploration_enemy_scene = config.get("exploration_enemy_scene")
	placeables_root = config.get("placeables_root")
	patrol_enemy_definitions = config.get("patrol_enemy_definitions", [])
	_cache_route_points()
	set_physics_process(true)


func set_active_mutator(mutator) -> void:
	_active_mutator = mutator


func reset_for_new_run() -> void:
	clear_patrols()
	_saved_patrol_spawn_states.clear()
	_day_patrols_spawned = false
	_saved_day_patrols_spawned = false


func enter_day_phase() -> void:
	clear_patrols()
	_day_patrols_spawned = true
	_spawn_day_patrols()


func get_save_state() -> Dictionary:
	var saved_patrols: Array[Dictionary] = []
	if exploration_enemy_layer != null and is_instance_valid(exploration_enemy_layer):
		for enemy in exploration_enemy_layer.get_children():
			if enemy == null or not is_instance_valid(enemy):
				continue
			if String(enemy.get_meta("spawn_kind", "")) != "patrol":
				continue
			var state: Dictionary = _patrol_states_by_enemy_id.get(int(enemy.get_instance_id()), {})
			saved_patrols.append({
				"enemy_id": String(enemy.definition.enemy_id if enemy.get("definition") != null else StringName()),
				"route_id": String(state.get("route_id", StringName())),
				"target_index": int(state.get("target_index", 0)),
				"position": {
					"x": enemy.global_position.x,
					"y": enemy.global_position.y,
				},
			})
	return {
		"day_patrols_spawned": _day_patrols_spawned,
		"patrols": saved_patrols,
	}


func apply_save_state(save_state: Dictionary) -> void:
	_saved_patrol_spawn_states.clear()
	_saved_day_patrols_spawned = bool(save_state.get("day_patrols_spawned", false))
	for raw_state in save_state.get("patrols", []):
		_saved_patrol_spawn_states.append(Dictionary(raw_state))


func restore_day_patrols() -> void:
	clear_patrols()
	_day_patrols_spawned = _saved_day_patrols_spawned
	if not _saved_day_patrols_spawned:
		return
	if _saved_patrol_spawn_states.is_empty():
		return
	for patrol_state in _saved_patrol_spawn_states:
		var definition: Resource = _get_patrol_enemy_definition(StringName(patrol_state.get("enemy_id", "")))
		var route_id := StringName(patrol_state.get("route_id", ""))
		if definition == null or route_id == StringName() or not _route_points_by_id.has(route_id):
			continue
		var enemy = exploration_enemy_scene.instantiate()
		enemy.definition = definition
		exploration_enemy_layer.add_child(enemy)
		var position_data: Dictionary = patrol_state.get("position", {})
		enemy.global_position = Vector2(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0)))
		if enemy.has_method("configure_runtime_context"):
			enemy.configure_runtime_context(player, exploration_enemy_layer, placeables_root)
		if _active_mutator != null and enemy.has_method("set_external_move_speed_multiplier"):
			enemy.set_external_move_speed_multiplier(1.0 + float(_active_mutator.enemy_speed_multiplier_bonus))
		if enemy.has_method("configure_exploration_context"):
			enemy.configure_exploration_context(player, Vector2.RIGHT, true, enemy.global_position, true)
		enemy.set_meta("spawn_kind", "patrol")
		enemy.set_meta("patrol_route_id", route_id)
		var target_index: int = int(patrol_state.get("target_index", 0))
		_patrol_states_by_enemy_id[int(enemy.get_instance_id())] = {
			"route_id": route_id,
			"target_index": target_index,
		}
		_assign_patrol_target(enemy, route_id, target_index)
		if enemy.has_signal("died"):
			enemy.died.connect(_on_patrol_enemy_died.bind(int(enemy.get_instance_id())))


func clear_patrols() -> void:
	_patrol_states_by_enemy_id.clear()
	if exploration_enemy_layer == null or not is_instance_valid(exploration_enemy_layer):
		return
	for enemy in exploration_enemy_layer.get_children():
		if enemy == null or not is_instance_valid(enemy):
			continue
		if String(enemy.get_meta("spawn_kind", "")) != "patrol":
			continue
		enemy.queue_free()


func get_patrol_defeat_count() -> int:
	var defeated := 0
	for patrol_state in _saved_patrol_spawn_states:
		if bool(patrol_state.get("defeated", false)):
			defeated += 1
	return defeated


func _physics_process(_delta: float) -> void:
	if game_manager == null or int(game_manager.run_state) != int(game_manager.RunState.PRE_WAVE):
		return
	if exploration_enemy_layer == null or not is_instance_valid(exploration_enemy_layer):
		return
	for enemy in exploration_enemy_layer.get_children():
		if enemy == null or not is_instance_valid(enemy):
			continue
		if String(enemy.get_meta("spawn_kind", "")) != "patrol":
			continue
		if bool(enemy.get("_is_chasing_player")) or bool(enemy.get("_is_alerted_to_player")):
			continue
		var targeting_controller = enemy.get("targeting_controller")
		if targeting_controller != null and is_instance_valid(targeting_controller) and targeting_controller.has_method("has_active_noise_investigation"):
			if bool(targeting_controller.has_active_noise_investigation()):
				continue
		var state: Dictionary = _patrol_states_by_enemy_id.get(int(enemy.get_instance_id()), {})
		var route_id := StringName(state.get("route_id", StringName()))
		if route_id == StringName() or not _route_points_by_id.has(route_id):
			continue
		var target_index: int = int(state.get("target_index", 0))
		var route_points: Array = _route_points_by_id[route_id]
		if route_points.is_empty():
			continue
		var target_point = route_points[clampi(target_index, 0, route_points.size() - 1)]
		var arrival_radius: float = float(target_point.arrival_radius)
		if enemy.global_position.distance_to(target_point.global_position) <= arrival_radius:
			target_index = posmod(target_index + 1, route_points.size())
			state["target_index"] = target_index
			_patrol_states_by_enemy_id[int(enemy.get_instance_id())] = state
		_assign_patrol_target(enemy, route_id, int(state.get("target_index", 0)))


func _spawn_day_patrols() -> void:
	if exploration_enemy_scene == null or exploration_enemy_layer == null or _route_points_by_id.is_empty():
		return
	var route_ids: Array = _route_points_by_id.keys()
	route_ids.sort()
	var spawn_count := mini(route_ids.size(), 2 + _get_patrol_count_bonus())
	for index in range(spawn_count):
		var route_id := StringName(route_ids[index])
		var route_points: Array = _route_points_by_id.get(route_id, [])
		if route_points.is_empty():
			continue
		var enemy_definition: Resource = _get_random_patrol_enemy_definition()
		if enemy_definition == null:
			continue
		var enemy = exploration_enemy_scene.instantiate()
		enemy.definition = enemy_definition
		exploration_enemy_layer.add_child(enemy)
		enemy.global_position = route_points[0].global_position
		if enemy.has_method("configure_runtime_context"):
			enemy.configure_runtime_context(player, exploration_enemy_layer, placeables_root)
		if _active_mutator != null and enemy.has_method("set_external_move_speed_multiplier"):
			enemy.set_external_move_speed_multiplier(1.0 + float(_active_mutator.enemy_speed_multiplier_bonus))
		if enemy.has_method("configure_exploration_context"):
			enemy.configure_exploration_context(player, Vector2.RIGHT, true, enemy.global_position, true)
		enemy.set_meta("spawn_kind", "patrol")
		enemy.set_meta("patrol_route_id", route_id)
		_patrol_states_by_enemy_id[int(enemy.get_instance_id())] = {
			"route_id": route_id,
			"target_index": 1 if route_points.size() > 1 else 0,
		}
		_assign_patrol_target(enemy, route_id, int(_patrol_states_by_enemy_id[int(enemy.get_instance_id())].get("target_index", 0)))
		if enemy.has_signal("died"):
			enemy.died.connect(_on_patrol_enemy_died.bind(int(enemy.get_instance_id())))


func _assign_patrol_target(enemy, route_id: StringName, target_index: int) -> void:
	var route_points: Array = _route_points_by_id.get(route_id, [])
	if route_points.is_empty():
		return
	var target_point = route_points[clampi(target_index, 0, route_points.size() - 1)]
	if enemy.has_method("set_patrol_target_position"):
		enemy.set_patrol_target_position(target_point.global_position)


func _cache_route_points() -> void:
	_route_points_by_id.clear()
	if patrol_routes_root == null or not is_instance_valid(patrol_routes_root):
		return
	for child in patrol_routes_root.get_children():
		if child == null or child.get_script() != PATROL_ROUTE_POINT_SCRIPT:
			continue
		if not child.is_valid_route_point():
			continue
		var route_id := StringName(child.patrol_id)
		if not _route_points_by_id.has(route_id):
			_route_points_by_id[route_id] = []
		_route_points_by_id[route_id].append(child)
	for route_id_variant in _route_points_by_id.keys():
		var route_id := StringName(route_id_variant)
		var route_points: Array = _route_points_by_id[route_id]
		route_points.sort_custom(func(a, b): return int(a.order_index) < int(b.order_index))


func _get_random_patrol_enemy_definition():
	var valid: Array[Resource] = []
	for enemy_definition in patrol_enemy_definitions:
		if enemy_definition == null or enemy_definition.get_script() != ENEMY_DEFINITION_SCRIPT:
			continue
		if not enemy_definition.is_valid_definition():
			continue
		valid.append(enemy_definition)
	if valid.is_empty():
		return null
	return valid[randi() % valid.size()]


func _get_patrol_enemy_definition(enemy_id: StringName):
	for enemy_definition in patrol_enemy_definitions:
		if enemy_definition == null or enemy_definition.get_script() != ENEMY_DEFINITION_SCRIPT:
			continue
		if StringName(enemy_definition.enemy_id) == enemy_id:
			return enemy_definition
	return null


func _get_patrol_count_bonus() -> int:
	if _active_mutator == null:
		return 0
	return int(_active_mutator.patrol_count_bonus)


func _on_patrol_enemy_died(enemy_instance_id: int, _enemy) -> void:
	_patrol_states_by_enemy_id.erase(enemy_instance_id)
	_saved_patrol_spawn_states.append({"defeated": true})
	patrol_enemy_defeated.emit()
