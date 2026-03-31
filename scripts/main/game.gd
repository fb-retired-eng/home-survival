extends Node2D
class_name Game

const BASE_PERIMETER_DEFINITION_SCRIPT := preload("res://scripts/data/base_perimeter_definition.gd")
const PERIMETER_SEGMENT_DEFINITION_SCRIPT := preload("res://scripts/data/perimeter_segment_definition.gd")
const STRUCTURE_PROFILE_SCRIPT := preload("res://scripts/data/structure_profile.gd")
const EXPLORATION_SPAWN_POINT_SCRIPT := preload("res://scripts/world/exploration_spawn_point.gd")
const ENEMY_DEFINITION_SCRIPT := preload("res://scripts/data/enemy_definition.gd")
const ROAMING_SPAWN_ZONE_SCRIPT := preload("res://scripts/world/roaming_spawn_zone.gd")

@export var defense_socket_scene: PackedScene
@export var exploration_enemy_scene: PackedScene
@export var perimeter_definition: Resource
@export var sleep_heal_amount: int = 25
@export_range(1, 100, 1) var food_energy_per_unit: int = 20
@export var enable_test_mode: bool = false
@export var test_mode_weapons: Array[Resource] = []
@export var test_mode_bullets: int = 18
@export var test_mode_food: int = 4
@export var roaming_early_enemies: Array[Resource] = []
@export var roaming_mid_enemies: Array[Resource] = []
@export var roaming_late_enemies: Array[Resource] = []

@onready var game_manager = $GameManager
@onready var player = $Player
@onready var hud = $HUD
@onready var wave_manager = $WaveManager
@onready var food_table: Area2D = $World/FoodTable
@onready var sleep_point: Area2D = $World/SleepPoint
@onready var spawn_markers_root: Node2D = $World/SpawnMarkers
@onready var defense_sockets: Node2D = $World/DefenseSockets
@onready var exploration_spawn_points_root: Node2D = $World/ExplorationSpawnPoints
@onready var roaming_spawn_zones_root: Node2D = $World/RoamingSpawnZones
@onready var exploration_enemy_layer: Node2D = $World/ExplorationEnemies
@onready var wave_enemy_layer: Node2D = $World/WaveEnemies

var _defeated_exploration_spawn_ids: Dictionary = {}
var _exploration_spawn_counts: Dictionary = {}
var _defeated_exploration_enemy_counts: Dictionary = {}
var _is_resetting_run: bool = false


func _ready() -> void:
	randomize()
	_build_defense_sockets()
	_validate_exploration_spawn_points()
	_validate_roaming_spawn_zones()
	player.set_interaction_gate(Callable(self, "_can_player_interact_with"))
	food_table.configure(Callable(self, "_can_player_eat"), Callable(self, "_get_food_table_label"))
	sleep_point.configure(Callable(self, "_can_player_sleep"), Callable(self, "_get_sleep_label"))
	hud.bind_player(player)
	_apply_test_mode_loadout()
	wave_manager.configure(_collect_spawn_markers(), wave_enemy_layer, player, defense_sockets)
	_sync_final_wave_with_definitions()
	game_manager.wave_changed.connect(_on_wave_changed)
	game_manager.run_reset.connect(_on_run_reset)
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_cleared.connect(_on_wave_cleared)
	food_table.table_requested.connect(_on_food_table_requested)
	sleep_point.sleep_requested.connect(_on_sleep_requested)
	_connect_defense_socket_signals()
	hud.set_interaction_prompt("")
	player.message_requested.connect(hud.set_status)
	player.player_died.connect(_on_player_died)
	game_manager.run_state_changed.connect(_on_run_state_changed)
	_on_wave_changed(game_manager.current_wave)
	_on_run_state_changed(game_manager.run_state)
	_refresh_base_status()


func _build_defense_sockets() -> void:
	for child in defense_sockets.get_children():
		child.queue_free()

	if defense_socket_scene == null:
		push_warning("Game is missing defense_socket_scene")
		return

	if perimeter_definition == null:
		push_warning("Game is missing perimeter_definition")
		return

	if perimeter_definition.get_script() != BASE_PERIMETER_DEFINITION_SCRIPT:
		push_warning("Game perimeter_definition is not a BasePerimeterDefinition resource")
		return

	var seen_socket_ids := {}
	for segment in perimeter_definition.segments:
		if not _is_valid_perimeter_segment(segment, seen_socket_ids):
			continue

		var socket = defense_socket_scene.instantiate()
		socket.position = segment.position
		socket.socket_id = segment.socket_id
		socket.socket_type = segment.socket_type
		socket.tier = segment.tier
		socket.current_hp = segment.current_hp
		socket.structure_profile = segment.structure_profile
		socket.socket_size = segment.socket_size
		socket.interaction_area_offset = segment.interaction_area_offset
		socket.interaction_area_size = segment.interaction_area_size
		defense_sockets.add_child(socket)


func _is_valid_perimeter_segment(segment: Resource, seen_socket_ids: Dictionary) -> bool:
	if segment == null:
		push_warning("Perimeter definition contains a null segment")
		return false

	if segment.get_script() != PERIMETER_SEGMENT_DEFINITION_SCRIPT:
		push_warning("Perimeter definition contains an invalid segment resource")
		return false

	var socket_id := String(segment.socket_id)
	if socket_id.is_empty():
		push_warning("Perimeter segment is missing socket_id")
		return false

	if seen_socket_ids.has(socket_id):
		push_warning("Perimeter definition contains a duplicate socket_id: %s" % socket_id)
		return false

	if segment.socket_type != "wall" and segment.socket_type != "door":
		push_warning("Perimeter segment %s has invalid socket_type %s" % [socket_id, segment.socket_type])
		return false

	if segment.socket_size.x <= 0.0 or segment.socket_size.y <= 0.0:
		push_warning("Perimeter segment %s has invalid socket_size" % socket_id)
		return false

	if segment.interaction_area_size.x <= 0.0 or segment.interaction_area_size.y <= 0.0:
		push_warning("Perimeter segment %s has invalid interaction_area_size" % socket_id)
		return false

	if segment.structure_profile == null or segment.structure_profile.get_script() != STRUCTURE_PROFILE_SCRIPT:
		push_warning("Perimeter segment %s is missing a valid structure_profile" % socket_id)
		return false

	var expected_profile_id := StringName(segment.socket_type)
	if not segment.structure_profile.is_valid_profile(expected_profile_id):
		push_warning("Perimeter segment %s has a structure_profile that does not match socket_type %s" % [socket_id, segment.socket_type])
		return false

	seen_socket_ids[socket_id] = true
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("restart_run"):
		return

	if game_manager.run_state != game_manager.RunState.WIN and game_manager.run_state != game_manager.RunState.LOSS:
		return

	get_viewport().set_input_as_handled()
	_is_resetting_run = true
	game_manager.reset_run()


func _on_player_died() -> void:
	game_manager.set_run_state(game_manager.RunState.LOSS)


func _on_run_state_changed(new_state: int) -> void:
	if new_state == game_manager.RunState.LOSS:
		wave_manager.reset()
		_clear_exploration_enemies()
		player.cancel_timed_action()
		hud.show_end_overlay("Run Failed", "You died.\nPress R to restart.", Color(0.94, 0.42, 0.38, 1.0))
		hud.set_phase("Phase: Loss")
		hud.set_status("You died")
		hud.set_interaction_prompt("Press R to restart")
		return

	if new_state == game_manager.RunState.WIN:
		wave_manager.reset()
		_clear_exploration_enemies()
		hud.show_end_overlay("Victory", "You survived all %d waves.\nPress R to restart." % game_manager.final_wave, Color(0.96, 0.84, 0.42, 1.0))
		hud.set_phase("Phase: Victory")
		hud.set_status("You survived all %d waves" % game_manager.final_wave)
		hud.set_interaction_prompt("Press R to restart")
		return

	hud.hide_end_overlay()

	if new_state == game_manager.RunState.ACTIVE_WAVE:
		_clear_roaming_exploration_enemies()
		_set_exploration_enemies_suspended(true)
		hud.set_phase("Phase: Night")
		hud.set_status("Night %d in progress. Hold the base." % game_manager.current_wave)
		player.refresh_interaction_prompt()
		return

	if new_state == game_manager.RunState.POST_WAVE:
		hud.set_phase("Phase: Post-Wave")
		hud.set_status("Night %d cleared. Sleep on the bed to start the next day." % game_manager.current_wave)
		player.refresh_interaction_prompt()
		return

	if new_state == game_manager.RunState.PRE_WAVE:
		if _is_resetting_run:
			return
		_enter_day_phase()


func _on_wave_changed(new_wave: int) -> void:
	hud.set_wave(new_wave, game_manager.final_wave)
	player.refresh_interaction_prompt()
	_refresh_phase_status()


func _refresh_phase_status() -> void:
	if game_manager.run_state != game_manager.RunState.PRE_WAVE:
		return
	
	if game_manager.current_wave <= 0:
		hud.set_status("Day 1. Scavenge carefully, build up, and eat dinner at the table to start night 1.")
	elif game_manager.current_wave < game_manager.final_wave - 1:
		hud.set_status("Day %d. Explore, build, and eat dinner at the table to start night %d." % [game_manager.current_wave + 1, game_manager.current_wave + 1])
	else:
		hud.set_status("Final day. Make repairs, gather food, and eat dinner before the last night.")


func _can_player_interact_with(_interactable) -> bool:
	if game_manager.run_state == game_manager.RunState.PRE_WAVE:
		return true
	if game_manager.run_state == game_manager.RunState.POST_WAVE:
		return _interactable == sleep_point
	return false


func _can_player_eat(_player) -> bool:
	return game_manager.run_state == game_manager.RunState.PRE_WAVE and game_manager.can_start_next_wave()


func _get_food_table_label(_player) -> String:
	if game_manager.run_state != game_manager.RunState.PRE_WAVE:
		return ""

	var next_wave: int = game_manager.current_wave + 1
	if not game_manager.can_start_next_wave():
		return ""
	if _has_sleep_blocking_exploration_threat():
		return "Enemies too close for dinner"
	if not wave_manager.can_start_wave(next_wave):
		return "Night %d not configured" % next_wave

	var food_needed := _get_missing_food_units_for_full_energy()
	if food_needed <= 0:
		return "Eat dinner to start night %d" % next_wave

	var current_food := int(player.resources.get("food", 0))
	if current_food < food_needed:
		return "Need %d food for dinner" % food_needed

	return "Eat %d food and start night %d" % [food_needed, next_wave]


func _can_player_sleep(_player) -> bool:
	return game_manager.run_state == game_manager.RunState.POST_WAVE


func _get_sleep_label(_player) -> String:
	if game_manager.run_state != game_manager.RunState.POST_WAVE:
		return ""
	return "Sleep on bed until morning"


func _on_food_table_requested(_player) -> void:
	var next_wave: int = game_manager.current_wave + 1
	if game_manager.run_state != game_manager.RunState.PRE_WAVE or not game_manager.can_start_next_wave():
		return
	if _has_sleep_blocking_exploration_threat():
		hud.set_status("Enemies too close for dinner")
		player.refresh_interaction_prompt()
		return
	if not wave_manager.can_start_wave(next_wave):
		hud.set_status("Night %d is not configured" % next_wave)
		player.refresh_interaction_prompt()
		return

	var food_needed := _get_missing_food_units_for_full_energy()
	if food_needed > 0:
		if int(player.resources.get("food", 0)) < food_needed:
			hud.set_status("Need %d food for dinner" % food_needed)
			player.refresh_interaction_prompt()
			return
		if not player.spend_resource("food", food_needed):
			hud.set_status("Not enough food")
			player.refresh_interaction_prompt()
			return
		player.restore_full_energy()

	if not wave_manager.start_wave(next_wave):
		if food_needed > 0:
			player.add_resource("food", food_needed, false)
		hud.set_status("Night %d failed to start" % next_wave)
		player.refresh_interaction_prompt()
		return

	game_manager.set_wave(next_wave)
	game_manager.set_run_state(game_manager.RunState.ACTIVE_WAVE)


func _on_sleep_requested(_player) -> void:
	if game_manager.run_state != game_manager.RunState.POST_WAVE:
		return

	player.heal(sleep_heal_amount)
	game_manager.set_run_state(game_manager.RunState.PRE_WAVE)


func _on_wave_started(wave_number: int) -> void:
	hud.set_phase("Phase: Night")
	hud.set_status("Night %d incoming. Hold the perimeter." % wave_number)


func _on_wave_cleared(_wave_number: int) -> void:
	game_manager.complete_active_wave()


func _on_run_reset() -> void:
	wave_manager.reset()
	_clear_exploration_enemies()
	_defeated_exploration_spawn_ids.clear()
	_exploration_spawn_counts.clear()
	_defeated_exploration_enemy_counts.clear()
	for pickup in get_tree().get_nodes_in_group("pickups"):
		pickup.queue_free()
	player.reset_for_new_run()
	_apply_test_mode_loadout()
	for socket in get_tree().get_nodes_in_group("defense_sockets"):
		if socket.has_method("reset_for_new_run"):
			socket.reset_for_new_run()
	for node in get_tree().get_nodes_in_group("scavenge_nodes"):
		if node.has_method("reset_for_new_run"):
			node.reset_for_new_run()
	_enter_day_phase()
	_refresh_base_status()
	_is_resetting_run = false


func _apply_test_mode_loadout() -> void:
	if not enable_test_mode:
		return

	for weapon in test_mode_weapons:
		player.obtain_weapon(weapon, true, false)
	if test_mode_bullets > 0:
		player.add_resource("bullets", test_mode_bullets, false)
	if test_mode_food > 0:
		player.add_resource("food", test_mode_food, false)


func _enter_day_phase() -> void:
	_sync_exploration_enemies()
	_spawn_roaming_exploration_enemies()
	hud.set_phase("Phase: Day")
	player.refresh_interaction_prompt()
	_refresh_phase_status()


func _sync_exploration_enemies() -> void:
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

		var target_count: int = _get_or_roll_exploration_spawn_count(child)
		var defeated_count := int(_defeated_exploration_enemy_counts.get(spawn_id, 0))
		var existing_count: int = 0
		if existing_by_spawn_id.has(spawn_id):
			existing_count = Array(existing_by_spawn_id.get(spawn_id, [])).size()

		var missing_count: int = max(target_count - defeated_count - existing_count, 0)
		for _spawn_index in range(missing_count):
			var enemy = exploration_enemy_scene.instantiate()
			enemy.definition = child.enemy_definition
			exploration_enemy_layer.add_child(enemy)
			enemy.global_position = _get_exploration_spawn_position(child)
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


func _spawn_roaming_exploration_enemies() -> void:
	if game_manager.run_state != game_manager.RunState.PRE_WAVE:
		return

	_clear_roaming_exploration_enemies()
	if roaming_spawn_zones_root == null or exploration_enemy_scene == null or exploration_enemy_layer == null:
		return

	var enemy_pool := _get_roaming_enemy_pool()
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

	var spawn_budget := _get_roaming_spawn_budget()
	for spawn_index in range(spawn_budget):
		var zone = _choose_weighted_roaming_zone(zones)
		if zone == null:
			continue
		var enemy_definition: Resource = enemy_pool[randi() % enemy_pool.size()]
		if enemy_definition == null:
			continue
		var enemy = exploration_enemy_scene.instantiate()
		enemy.definition = enemy_definition
		exploration_enemy_layer.add_child(enemy)
		enemy.global_position = _get_roaming_spawn_position(zone)
		enemy.set_meta("spawn_kind", "roaming")
		var initial_facing := Vector2.RIGHT.rotated(randf() * TAU)
		if enemy.has_method("configure_exploration_context"):
			enemy.configure_exploration_context(player, initial_facing, true, zone.global_position, true)


func _clear_exploration_enemies() -> void:
	if exploration_enemy_layer == null:
		return

	for child in exploration_enemy_layer.get_children():
		child.queue_free()


func _clear_roaming_exploration_enemies() -> void:
	if exploration_enemy_layer == null:
		return

	for child in exploration_enemy_layer.get_children():
		if not is_instance_valid(child):
			continue
		if String(child.get_meta("spawn_kind", "")) != "roaming":
			continue
		child.queue_free()


func _set_exploration_enemies_suspended(suspended: bool) -> void:
	if exploration_enemy_layer == null:
		return

	for child in exploration_enemy_layer.get_children():
		if child.has_method("set_exploration_suspended"):
			child.set_exploration_suspended(suspended)


func _has_sleep_blocking_exploration_threat() -> bool:
	if exploration_enemy_layer == null:
		return false

	for child in exploration_enemy_layer.get_children():
		if not is_instance_valid(child):
			continue
		if child.has_method("is_engaged_with_player") and child.is_engaged_with_player():
			return true

	return false


func _get_missing_food_units_for_full_energy() -> int:
	var missing_energy: int = maxi(int(player.max_energy) - int(player.current_energy), 0)
	if missing_energy <= 0:
		return 0
	return int(ceili(float(missing_energy) / float(max(food_energy_per_unit, 1))))


func _on_exploration_enemy_died(_enemy, spawn_id: String) -> void:
	var defeated_count := int(_defeated_exploration_enemy_counts.get(spawn_id, 0)) + 1
	_defeated_exploration_enemy_counts[spawn_id] = defeated_count
	var target_count := int(_exploration_spawn_counts.get(spawn_id, 1))
	if defeated_count >= target_count:
		_defeated_exploration_spawn_ids[spawn_id] = true


func _get_or_roll_exploration_spawn_count(spawn_point) -> int:
	var spawn_id := String(spawn_point.spawn_id)
	if _exploration_spawn_counts.has(spawn_id):
		return int(_exploration_spawn_counts[spawn_id])

	var rolled_count := randi_range(int(spawn_point.min_count), int(spawn_point.max_count))
	_exploration_spawn_counts[spawn_id] = rolled_count
	return rolled_count


func _get_exploration_spawn_position(spawn_point) -> Vector2:
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


func _validate_exploration_spawn_points() -> void:
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


func _validate_roaming_spawn_zones() -> void:
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


func _get_roaming_enemy_pool() -> Array[Resource]:
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


func _get_roaming_spawn_budget() -> int:
	if game_manager.current_wave <= 0:
		return 2
	if game_manager.current_wave <= 3:
		return 3
	if game_manager.current_wave <= 5:
		return 4
	return 5


func _choose_weighted_roaming_zone(zones: Array):
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


func _get_roaming_spawn_position(zone) -> Vector2:
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


func _collect_spawn_markers() -> Dictionary:
	var markers := {}

	for child in spawn_markers_root.get_children():
		markers[String(child.name).to_lower()] = child

	return markers


func _sync_final_wave_with_definitions() -> void:
	var defined_final_wave: int = wave_manager.get_highest_defined_wave()
	if defined_final_wave > 0:
		game_manager.final_wave = defined_final_wave


func _connect_defense_socket_signals() -> void:
	for socket in get_tree().get_nodes_in_group("defense_sockets"):
		if not socket.has_signal("state_changed"):
			continue
		if not socket.state_changed.is_connected(_on_defense_socket_state_changed):
			socket.state_changed.connect(_on_defense_socket_state_changed)


func _on_defense_socket_state_changed(_socket) -> void:
	_refresh_base_status()


func _refresh_base_status() -> void:
	var sockets := get_tree().get_nodes_in_group("defense_sockets")
	if sockets.is_empty():
		hud.set_base_status(0, 0, 0)
		return

	var intact_count := 0
	var breached_count := 0
	var total_hp := 0
	var total_max_hp := 0

	for socket in sockets:
		if not is_instance_valid(socket):
			continue

		total_hp += int(socket.current_hp)
		total_max_hp += int(socket.max_hp)
		if socket.has_method("is_breached") and socket.is_breached():
			breached_count += 1
		else:
			intact_count += 1

	var hp_percent := 0
	if total_max_hp > 0:
		hp_percent = int(round((float(total_hp) / float(total_max_hp)) * 100.0))

	hud.set_base_status(intact_count, breached_count, hp_percent)
