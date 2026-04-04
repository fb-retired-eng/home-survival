extends Node2D
class_name Game

const APP_SERVICES := preload("res://scripts/main/app_services.gd")
const BASE_PERIMETER_DEFINITION_SCRIPT := preload("res://scripts/data/base_perimeter_definition.gd")
const PERIMETER_SEGMENT_DEFINITION_SCRIPT := preload("res://scripts/data/perimeter_segment_definition.gd")
const STRUCTURE_PROFILE_SCRIPT := preload("res://scripts/data/structure_profile.gd")
const MAP_WORLD_MIN := Vector2(-1280.0, -720.0)
const MAP_WORLD_MAX := Vector2(3840.0, 2160.0)
const WORLD_ART_Z_INDEX := -20
const WORLD_ART_EXCLUDED_ROOTS := [
	&"ConstructionPlaceables",
	&"AmbientPickups",
	&"DefenseSockets",
	&"ExplorationEnemies",
	&"WaveEnemies",
]

signal return_to_menu_requested

@export var defense_socket_scene: PackedScene
@export var exploration_enemy_scene: PackedScene
@export var perimeter_definition: Resource
@export var default_daily_elite_enemy: Resource
@export var poi_definitions: Array[Resource] = []
@export var construction_placeable_scene: PackedScene
@export var resource_pickup_scene: PackedScene
@export var barricade_placeable_profile: Resource
@export var buildable_placeable_profiles: Array[Resource] = []
@export var legacy_perk_definitions: Array[Resource] = []
@export var sleep_heal_amount: int = 25
@export_range(1, 100, 1) var food_energy_per_unit: int = 25
@export_range(0, 4, 1) var daily_poi_refill_base_nodes: int = 1
@export_range(0.0, 1.0, 0.01) var daily_poi_refill_bonus_chance: float = 0.3
@export_range(0, 4, 1) var daily_poi_refill_bonus_nodes: int = 1
@export var enable_test_mode: bool = false
@export var test_mode_weapons: Array[Resource] = []
@export var test_mode_salvage: int = 72
@export var test_mode_parts: int = 30
@export var test_mode_bullets: int = 36
@export var test_mode_food: int = 10
@export var roaming_early_enemies: Array[Resource] = []
@export var roaming_mid_enemies: Array[Resource] = []
@export var roaming_late_enemies: Array[Resource] = []
@export var legacy_perk_id: String = "max_energy"

@onready var game_manager = $GameManager
@onready var player = $Player
@onready var hud = $HUD
@onready var wave_manager = $WaveManager
@onready var world_root: Node2D = $World
@onready var food_table: Area2D = $World/FoodTable
@onready var generator_point: Area2D = $World/GeneratorPoint
@onready var sleep_point: Area2D = $World/SleepPoint
@onready var spawn_markers_root: Node2D = $World/SpawnMarkers
@onready var defense_sockets: Node2D = $World/DefenseSockets
@onready var construction_grid = $World/ConstructionGrid
@onready var player_camera: Camera2D = $Player/Camera2D
@onready var exploration_spawn_points_root: Node2D = $World/ExplorationSpawnPoints
@onready var roaming_spawn_zones_root: Node2D = $World/RoamingSpawnZones
@onready var construction_placeables: Node2D = $World/ConstructionPlaceables
@onready var micro_loot_spawns_root: Node2D = $World/MicroLootSpawns
@onready var ambient_pickups_root: Node2D = $World/AmbientPickups
@onready var exploration_enemy_layer: Node2D = $World/ExplorationEnemies
@onready var wave_enemy_layer: Node2D = $World/WaveEnemies
@onready var construction_controller = $ConstructionController
@onready var poi_controller = $PoiController
@onready var exploration_controller = $ExplorationController
@onready var fog_controller = $FogController
@onready var power_manager = $PowerManager
@onready var mvp1_run_controller = $Mvp1RunController
@onready var run_phase_controller = $RunPhaseController
@onready var dog = $Dog

# Compatibility aliases for existing probes; exploration_controller owns these dictionaries.
var _defeated_exploration_spawn_ids: Dictionary = {}
var _exploration_spawn_counts: Dictionary = {}
var _defeated_exploration_enemy_counts: Dictionary = {}
var _current_exploration_target_counts: Dictionary = {}
var _is_resetting_run: bool = false
var _collected_micro_loot_ids: Dictionary = {}
var _active_heirloom_socket_ids: Dictionary = {}
var _pending_heirloom_socket_ids: Dictionary = {}
var _last_terminal_run_state: int = -1


func _ready() -> void:
	randomize()
	_build_defense_sockets()
	player.set_interaction_gate(Callable(self, "_can_player_interact_with"))
	hud.bind_player(player)
	hud.bind_dog(dog)
	_apply_test_mode_loadout()
	wave_manager.configure(_collect_spawn_markers(), wave_enemy_layer, player, defense_sockets)
	_sync_final_wave_with_definitions()
	game_manager.wave_changed.connect(_on_wave_changed)
	game_manager.run_reset.connect(_on_run_reset)
	_connect_defense_socket_signals()
	hud.set_interaction_prompt("")
	player.message_requested.connect(hud.set_status)
	player.player_died.connect(_on_player_died)
	player.weapon_noise_emitted.connect(_on_player_weapon_noise_emitted)
	player.build_mode_toggled.connect(_on_player_build_mode_toggled)
	player.build_placement_requested.connect(Callable(construction_controller, "on_player_build_placement_requested"))
	player.build_selection_prev_requested.connect(Callable(construction_controller, "on_player_build_selection_prev_requested"))
	player.build_selection_next_requested.connect(Callable(construction_controller, "on_player_build_selection_next_requested"))
	player.build_rotation_requested.connect(Callable(construction_controller, "on_player_build_rotation_requested"))
	player.dog_command_requested.connect(_on_player_dog_command_requested)
	hud.pause_toggle_requested.connect(_on_pause_toggle_requested)
	hud.pause_resume_requested.connect(_on_pause_resume_requested)
	hud.pause_save_requested.connect(_on_pause_save_requested)
	hud.pause_save_quit_requested.connect(_on_pause_save_quit_requested)
	game_manager.run_state_changed.connect(_on_run_state_changed)
	construction_controller.configure({
		"game_manager": game_manager,
		"player": player,
		"hud": hud,
		"construction_grid": construction_grid,
		"construction_placeables": construction_placeables,
		"sleep_point": sleep_point,
		"food_table": food_table,
		"defense_sockets": defense_sockets,
		"construction_placeable_scene": construction_placeable_scene,
		"barricade_placeable_profile": barricade_placeable_profile,
		"buildable_placeable_profiles": buildable_placeable_profiles,
	})
	if not construction_controller.autosave_requested.is_connected(_request_autosave):
		construction_controller.autosave_requested.connect(_request_autosave)
	poi_controller.configure({
		"game_manager": game_manager,
		"player": player,
		"world_root": get_node("World"),
		"exploration_spawn_points_root": exploration_spawn_points_root,
		"exploration_enemy_scene": exploration_enemy_scene,
		"exploration_enemy_layer": exploration_enemy_layer,
		"default_daily_elite_enemy": default_daily_elite_enemy,
		"poi_definitions": poi_definitions,
		"get_local_scavenge_nodes_callback": Callable(self, "_get_local_scavenge_nodes"),
		"daily_poi_refill_base_nodes": daily_poi_refill_base_nodes,
		"daily_poi_refill_bonus_chance": daily_poi_refill_bonus_chance,
		"daily_poi_refill_bonus_nodes": daily_poi_refill_bonus_nodes,
	})
	if not poi_controller.autosave_requested.is_connected(_request_autosave):
		poi_controller.autosave_requested.connect(_request_autosave)
	exploration_controller.configure({
		"game_manager": game_manager,
		"player": player,
		"sleep_point": sleep_point,
		"exploration_spawn_points_root": exploration_spawn_points_root,
		"roaming_spawn_zones_root": roaming_spawn_zones_root,
		"micro_loot_spawns_root": micro_loot_spawns_root,
		"ambient_pickups_root": ambient_pickups_root,
		"exploration_enemy_layer": exploration_enemy_layer,
		"exploration_enemy_scene": exploration_enemy_scene,
		"resource_pickup_scene": resource_pickup_scene,
		"poi_controller": poi_controller,
		"roaming_early_enemies": roaming_early_enemies,
		"roaming_mid_enemies": roaming_mid_enemies,
		"roaming_late_enemies": roaming_late_enemies,
	})
	if not exploration_controller.autosave_requested.is_connected(_request_autosave):
		exploration_controller.autosave_requested.connect(_request_autosave)
	fog_controller.configure({
		"player": player,
		"hud": hud,
		"player_camera": player_camera,
		"fog_world_min": MAP_WORLD_MIN,
		"fog_world_max": MAP_WORLD_MAX,
	})
	dog.configure({
		"player": player,
		"poi_controller": poi_controller,
		"game_manager": game_manager,
		"home_world_position": Vector2(1280.0, 720.0),
	})
	power_manager.configure({
		"hud": hud,
		"player": player,
		"construction_placeables": construction_placeables,
		"exploration_enemy_layer": exploration_enemy_layer,
		"wave_enemy_layer": wave_enemy_layer,
		"generator_world_position": generator_point.global_position if generator_point != null and is_instance_valid(generator_point) else Vector2(1280.0, 720.0),
		"power_radius": 260.0,
		"max_load_slots": 3,
	})
	mvp1_run_controller.configure({
		"game_manager": game_manager,
		"player": player,
		"hud": hud,
		"generator_point": generator_point,
		"power_manager": power_manager,
		"dog": dog,
		"defense_sockets": defense_sockets,
		"legacy_perk_definitions": legacy_perk_definitions,
		"legacy_perk_id": legacy_perk_id,
	})
	run_phase_controller.configure({
		"game_manager": game_manager,
		"player": player,
		"hud": hud,
		"wave_manager": wave_manager,
		"exploration_controller": exploration_controller,
		"poi_controller": poi_controller,
		"construction_controller": construction_controller,
		"mvp1_run_controller": mvp1_run_controller,
		"food_energy_per_unit": food_energy_per_unit,
		"sleep_heal_amount": sleep_heal_amount,
	})
	food_table.configure(Callable(run_phase_controller, "can_player_eat"), Callable(run_phase_controller, "get_food_table_label"))
	generator_point.configure(Callable(run_phase_controller, "can_player_upgrade_generator"), Callable(run_phase_controller, "get_generator_label"))
	sleep_point.configure(Callable(run_phase_controller, "can_player_sleep"), Callable(run_phase_controller, "get_sleep_label"))
	wave_manager.wave_started.connect(Callable(run_phase_controller, "on_wave_started"))
	wave_manager.wave_cleared.connect(Callable(run_phase_controller, "on_wave_cleared"))
	food_table.table_requested.connect(Callable(run_phase_controller, "on_food_table_requested"))
	generator_point.upgrade_requested.connect(Callable(run_phase_controller, "on_generator_upgrade_requested"))
	sleep_point.sleep_requested.connect(Callable(run_phase_controller, "on_sleep_requested"))
	if not run_phase_controller.autosave_requested.is_connected(_request_autosave):
		run_phase_controller.autosave_requested.connect(_request_autosave)
	_sync_mvp1_state_aliases()
	mvp1_run_controller.apply_legacy_perk_baseline()
	legacy_perk_id = mvp1_run_controller.legacy_perk_id
	dog.message_requested.connect(hud.set_status)
	if not dog.autosave_requested.is_connected(_request_autosave):
		dog.autosave_requested.connect(_request_autosave)
	_configure_world_art_layers()
	_configure_camera_bounds()
	exploration_controller.validate_exploration_spawn_points()
	exploration_controller.validate_roaming_spawn_zones()
	exploration_controller.validate_micro_loot_spawns()
	_configure_scavenge_nodes()
	exploration_controller.spawn_micro_loot_pickups()
	_sync_exploration_state_aliases()
	_register_fixed_grid_footprints()
	player.set_build_mode_allowed(true)
	_on_wave_changed(game_manager.current_wave)
	_on_run_state_changed(game_manager.run_state)
	_refresh_base_status()


func _physics_process(_delta: float) -> void:
	if construction_grid == null:
		pass
	elif construction_grid.is_build_mode_active() and player != null and is_instance_valid(player):
		construction_grid.set_preview_world_position(player.global_position)


func _configure_camera_bounds() -> void:
	if player_camera == null or not is_instance_valid(player_camera):
		return
	player_camera.limit_left = int(MAP_WORLD_MIN.x)
	player_camera.limit_top = int(MAP_WORLD_MIN.y)
	player_camera.limit_right = int(MAP_WORLD_MAX.x)
	player_camera.limit_bottom = int(MAP_WORLD_MAX.y)


func _configure_world_art_layers() -> void:
	if world_root == null or not is_instance_valid(world_root):
		return
	_apply_world_art_layer_recursive(world_root, false)


func _apply_world_art_layer_recursive(node: Node, under_excluded_root: bool) -> void:
	var next_under_excluded_root := under_excluded_root
	if node != world_root and node.name is StringName and WORLD_ART_EXCLUDED_ROOTS.has(node.name):
		next_under_excluded_root = true

	if node is Polygon2D and not next_under_excluded_root:
		var polygon := node as Polygon2D
		if polygon.name != "Marker":
			polygon.z_as_relative = false
			polygon.z_index = WORLD_ART_Z_INDEX

	for child in node.get_children():
		_apply_world_art_layer_recursive(child, next_under_excluded_root)


func _sync_exploration_state_aliases() -> void:
	if exploration_controller == null or not is_instance_valid(exploration_controller):
		return
	_defeated_exploration_spawn_ids = exploration_controller._defeated_exploration_spawn_ids
	_exploration_spawn_counts = exploration_controller._exploration_spawn_counts
	_defeated_exploration_enemy_counts = exploration_controller._defeated_exploration_enemy_counts
	_current_exploration_target_counts = exploration_controller._current_exploration_target_counts
	_collected_micro_loot_ids = exploration_controller._collected_micro_loot_ids


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
	mvp1_run_controller.on_run_state_changed(new_state)
	_sync_mvp1_state_aliases()
	player.set_build_mode_allowed(new_state != game_manager.RunState.LOSS and new_state != game_manager.RunState.WIN)
	if new_state == game_manager.RunState.LOSS:
		wave_manager.reset()
		exploration_controller.clear_exploration_enemies()
		player.set_build_mode_active(false, false)
		player.cancel_timed_action()
		hud.show_end_overlay("Run Failed", "You died.\nPress R to restart.", Color(0.94, 0.42, 0.38, 1.0))
		hud.set_phase("Phase: Loss")
		hud.set_status("You died")
		hud.set_interaction_prompt("Press R to restart")
		return

	if new_state == game_manager.RunState.WIN:
		wave_manager.reset()
		exploration_controller.clear_exploration_enemies()
		player.set_build_mode_active(false, false)
		hud.show_end_overlay("Victory", "You survived all %d waves.\nPress R to restart." % game_manager.final_wave, Color(0.96, 0.84, 0.42, 1.0))
		hud.set_phase("Phase: Victory")
		hud.set_status("You survived all %d waves" % game_manager.final_wave)
		hud.set_interaction_prompt("Press R to restart")
		return

	hud.hide_end_overlay()

	if new_state == game_manager.RunState.ACTIVE_WAVE:
		exploration_controller.clear_roaming_exploration_enemies()
		exploration_controller.set_exploration_enemies_suspended(true)
		hud.set_phase("Phase: Night")
		if player.is_build_mode_active():
			construction_controller.refresh_build_mode_status()
		else:
			hud.set_status("Night %d in progress. Hold the base." % game_manager.current_wave)
		player.refresh_interaction_prompt()
		return

	if new_state == game_manager.RunState.POST_WAVE:
		hud.set_phase("Phase: Post-Wave")
		if player.is_build_mode_active():
			construction_controller.refresh_build_mode_status()
		else:
			hud.set_status("Night %d cleared. Sleep on the bed to start the next day." % game_manager.current_wave)
		player.refresh_interaction_prompt()
		_flush_pending_autosave()
		return

	if new_state == game_manager.RunState.PRE_WAVE:
		if _is_resetting_run:
			return
		_enter_day_phase()
		_flush_pending_autosave()


func _on_player_build_mode_toggled(active: bool) -> void:
	construction_controller.on_player_build_mode_toggled(active)
	if not active:
		_refresh_phase_status()


func _on_pause_toggle_requested() -> void:
	_set_pause_state(not get_tree().paused)


func _on_pause_resume_requested() -> void:
	_set_pause_state(false)


func _on_pause_save_requested() -> void:
	var saved := _save_active_run()
	if hud != null and is_instance_valid(hud):
		hud.show_pause_menu("Game saved." if saved else "Saving is blocked during active waves.")


func _on_pause_save_quit_requested() -> void:
	var saved := _save_active_run()
	if not saved and hud != null and is_instance_valid(hud):
		hud.show_pause_menu("Active wave. Quitting without saving.")
	_set_pause_state(false)
	return_to_menu_requested.emit()


func _on_wave_changed(new_wave: int) -> void:
	hud.set_wave(new_wave, game_manager.final_wave)
	player.refresh_interaction_prompt()
	_refresh_phase_status()


func _refresh_phase_status() -> void:
	run_phase_controller.refresh_phase_status()


func _can_player_interact_with(_interactable) -> bool:
	if game_manager.run_state == game_manager.RunState.PRE_WAVE:
		return true
	if game_manager.run_state == game_manager.RunState.POST_WAVE:
		return _interactable == sleep_point
	return false


func _on_run_reset() -> void:
	_is_resetting_run = true
	mvp1_run_controller.reset_for_new_run()
	_sync_mvp1_state_aliases()
	wave_manager.reset()
	exploration_controller.reset_for_new_run()
	poi_controller.reset_for_new_run()
	_sync_exploration_state_aliases()
	construction_controller.reset_selection()
	if power_manager != null and is_instance_valid(power_manager):
		power_manager.reset_for_new_run()
	for pickup in _get_local_group_members(&"pickups"):
		pickup.queue_free()
	player.reset_for_new_run()
	if dog != null and is_instance_valid(dog):
		dog.reset_for_new_run()
	_apply_test_mode_loadout()
	for socket in defense_sockets.get_children():
		if socket.has_method("reset_for_new_run"):
			socket.reset_for_new_run()
	mvp1_run_controller.apply_heirloom_socket_state()
	for child in construction_placeables.get_children():
		if is_instance_valid(child):
			child.queue_free()
	for pickup in ambient_pickups_root.get_children():
		if is_instance_valid(pickup):
			pickup.queue_free()
	_register_fixed_grid_footprints()
	exploration_controller.spawn_micro_loot_pickups()
	for node in _get_local_scavenge_nodes():
		if node.has_method("reset_for_new_run"):
			node.reset_for_new_run()
	_enter_day_phase()
	_refresh_base_status()
	_is_resetting_run = false
	_request_autosave()


func _apply_test_mode_loadout() -> void:
	if not enable_test_mode:
		return

	for weapon in test_mode_weapons:
		player.obtain_weapon(weapon, true, false)
	if test_mode_salvage > 0:
		player.add_resource("salvage", test_mode_salvage, false)
	if test_mode_parts > 0:
		player.add_resource("parts", test_mode_parts, false)
	if test_mode_bullets > 0:
		player.add_resource("bullets", test_mode_bullets, false)
	if test_mode_food > 0:
		player.add_resource("food", test_mode_food, false)


func set_legacy_perk_id(perk_id: String) -> void:
	legacy_perk_id = perk_id
	if mvp1_run_controller != null and is_instance_valid(mvp1_run_controller):
		mvp1_run_controller.set_legacy_perk_id(perk_id)
		_sync_mvp1_state_aliases()


func get_selected_buildable_profile() -> PlaceableProfile:
	return construction_controller.get_selected_buildable_profile()


func get_selected_buildable_rotation() -> int:
	return construction_controller.get_selected_buildable_rotation()


func _refresh_build_mode_preview() -> void:
	construction_controller.refresh_build_mode_preview()


func _refresh_build_mode_status() -> void:
	construction_controller.refresh_build_mode_status()


func _register_fixed_grid_footprints() -> void:
	construction_controller.refresh_runtime_occupancy({
		"sleep_point": sleep_point,
		"food_table": food_table,
		"defense_sockets": defense_sockets,
	})


func _on_construction_placeable_state_changed(_placeable) -> void:
	_register_fixed_grid_footprints()
	_request_autosave()


func _get_area_shape_size(area: Area2D) -> Vector2:
	if area == null or not is_instance_valid(area):
		return Vector2.ZERO
	var shape_node := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return Vector2.ZERO
	var rectangle := shape_node.shape as RectangleShape2D
	if rectangle == null:
		return Vector2.ZERO
	return rectangle.size


func _would_block_all_door_routes(footprint_cells: Array) -> bool:
	return construction_controller._would_block_all_door_routes(footprint_cells)


func _on_player_weapon_noise_emitted(source_position: Vector2, noise_radius: float, noise_alert_budget: float, _weapon_id: StringName) -> void:
	exploration_controller.on_player_weapon_noise_emitted(source_position, noise_radius, noise_alert_budget, _weapon_id)


func _enter_day_phase() -> void:
	poi_controller.roll_daily_poi_modifiers()
	poi_controller.apply_daily_poi_refills()
	poi_controller.refresh_poi_modifier_visuals()
	poi_controller.clear_stale_daily_modifier_enemies()
	exploration_controller.enter_day_phase()
	poi_controller.sync_daily_modifier_enemies()
	hud.set_phase("Phase: Day")
	player.refresh_interaction_prompt()
	_refresh_phase_status()
	_request_autosave()


func _configure_scavenge_nodes() -> void:
	poi_controller.configure_scavenge_nodes()

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
	for socket in _get_local_defense_sockets():
		if not socket.has_signal("state_changed"):
			continue
		if not socket.state_changed.is_connected(_on_defense_socket_state_changed):
			socket.state_changed.connect(_on_defense_socket_state_changed)


func _on_defense_socket_state_changed(_socket) -> void:
	mvp1_run_controller.on_defense_socket_state_changed(_socket)
	_sync_mvp1_state_aliases()
	_register_fixed_grid_footprints()
	_refresh_base_status()
	_request_autosave()


func _refresh_base_status() -> void:
	var sockets := _get_local_defense_sockets()
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


func get_save_state() -> Dictionary:
	var construction_selection: Dictionary = construction_controller.get_selection_save_state()
	var saved_daily_modifiers := {}
	var poi_state: Dictionary = poi_controller.get_save_state()
	saved_daily_modifiers = poi_state.get("daily_poi_modifiers", {})
	var saved_refilled_pois: Array[String] = poi_state.get("last_daily_refilled_pois", [])
	var exploration_state: Dictionary = exploration_controller.get_save_state()
	var mvp1_state: Dictionary = mvp1_run_controller.get_save_state_fragment()
	return {
		"game": {
			"wave": int(game_manager.current_wave),
			"run_state": int(game_manager.run_state),
			"phase": _get_run_state_label(game_manager.run_state),
			"selected_buildable_profile_id": String(construction_selection.get("selected_buildable_profile_id", "")),
			"selected_buildable_rotation": int(construction_selection.get("selected_buildable_rotation", 0)),
			"defeated_exploration_spawn_ids": exploration_state.get("defeated_exploration_spawn_ids", []),
			"exploration_spawn_counts": exploration_state.get("exploration_spawn_counts", {}).duplicate(true),
			"defeated_exploration_enemy_counts": exploration_state.get("defeated_exploration_enemy_counts", {}).duplicate(true),
			"current_exploration_target_counts": exploration_state.get("current_exploration_target_counts", {}).duplicate(true),
			"daily_poi_modifiers": saved_daily_modifiers,
			"last_daily_refilled_pois": saved_refilled_pois,
			"collected_micro_loot_ids": exploration_state.get("collected_micro_loot_ids", []),
		},
		"player": player.get_save_state() if player != null and is_instance_valid(player) else {},
		"dog": dog.get_save_state() if dog != null and is_instance_valid(dog) else {},
		"power": power_manager.get_save_state() if power_manager != null and is_instance_valid(power_manager) else {},
		"legacy_perk_id": mvp1_state.get("legacy_perk_id", legacy_perk_id),
		"heirlooms": mvp1_state.get("heirlooms", {}),
		"defense_sockets": _get_defense_socket_save_states(),
		"scavenge_nodes": _get_scavenge_node_save_states(),
		"placeables": construction_controller.get_construction_placeable_save_states(),
		"fog": fog_controller.get_save_state(),
	}


func apply_save_state(save_state: Dictionary) -> void:
	if save_state.is_empty():
		return

	_is_resetting_run = true
	wave_manager.reset()
	exploration_controller.reset_for_new_run()
	poi_controller.reset_for_new_run()
	_sync_exploration_state_aliases()
	construction_controller.reset_selection()

	var game_state: Dictionary = save_state.get("game", {})
	var player_state: Dictionary = save_state.get("player", {})
	var saved_wave := maxi(int(game_state.get("wave", 0)), 0)
	var saved_run_state := int(game_state.get("run_state", game_manager.RunState.PRE_WAVE))
	game_manager.set_wave(saved_wave)
	game_manager.set_run_state(saved_run_state)

	construction_controller.restore_selection_from_state(game_state)
	_restore_daily_run_state(game_state)
	mvp1_run_controller.apply_save_state_fragment(save_state)
	_sync_mvp1_state_aliases()
	legacy_perk_id = mvp1_run_controller.legacy_perk_id

	if player != null and is_instance_valid(player):
		player.apply_save_state(player_state, Callable(self, "_get_weapon_definition_by_id"))
	if dog != null and is_instance_valid(dog):
		dog.apply_save_state(save_state.get("dog", {}))
	if power_manager != null and is_instance_valid(power_manager):
		power_manager.apply_save_state(save_state.get("power", {}))

	_apply_defense_socket_save_states(save_state.get("defense_sockets", []))
	mvp1_run_controller.apply_heirloom_socket_state()
	_sync_mvp1_state_aliases()
	_apply_scavenge_node_save_states(save_state.get("scavenge_nodes", []))
	exploration_controller.spawn_micro_loot_pickups()
	construction_controller.apply_construction_placeable_save_states(save_state.get("placeables", []))
	fog_controller.apply_save_state(save_state.get("fog", {}))

	_register_fixed_grid_footprints()
	_configure_scavenge_nodes()
	poi_controller.refresh_player_poi_discovery_from_current_position()
	poi_controller.refresh_poi_modifier_visuals()
	exploration_controller.sync_exploration_enemies()
	poi_controller.sync_daily_modifier_enemies()
	_refresh_base_status()
	_refresh_phase_status()
	if player != null and is_instance_valid(player):
		player.refresh_interaction_prompt()
	_refresh_build_mode_preview()
	_refresh_build_mode_status()
	_is_resetting_run = false


func _request_autosave() -> void:
	if _is_resetting_run:
		return
	var save_store: Node = _get_save_store()
	if save_store == null:
		return
	save_store.call("request_autosave", self)


func _flush_pending_autosave() -> void:
	if _is_resetting_run:
		return
	var save_store: Node = _get_save_store()
	if save_store == null:
		return
	save_store.call("flush_pending_autosave", self)


func _get_save_store() -> Node:
	return APP_SERVICES.get_save_store(get_tree())


func _save_active_run() -> bool:
	if game_manager != null and game_manager.run_state == game_manager.RunState.ACTIVE_WAVE:
		return false
	var save_store: Node = _get_save_store()
	if save_store == null:
		return false
	return bool(save_store.call("save_active_game", self))


func _set_pause_state(paused: bool) -> void:
	get_tree().paused = paused
	if hud != null and is_instance_valid(hud):
		if paused:
			var active_wave: bool = game_manager != null and game_manager.run_state == game_manager.RunState.ACTIVE_WAVE
			hud.set_pause_actions(active_wave)
			var status_text := "Paused. Save before quitting or resume when ready."
			if active_wave:
				status_text = "Paused. Active wave: saving is blocked, but you can quit without saving."
			hud.show_pause_menu(status_text)
		else:
			hud.hide_pause_menu()
	if player != null and is_instance_valid(player):
		player.refresh_interaction_prompt()


func _on_player_dog_command_requested() -> void:
	mvp1_run_controller.on_player_dog_command_requested()


func _get_defense_socket_save_states() -> Array[Dictionary]:
	var save_states: Array[Dictionary] = []
	for socket in _get_local_defense_sockets():
		if socket == null or not is_instance_valid(socket):
			continue
		if not socket.has_method("get_save_state"):
			continue
		save_states.append(socket.get_save_state())
	return save_states


func _apply_defense_socket_save_states(save_states: Array) -> void:
	var socket_by_id := _get_defense_socket_by_id()
	for raw_state in save_states:
		var state: Dictionary = raw_state
		var socket_id := StringName(state.get("socket_id", ""))
		if socket_id == StringName() or not socket_by_id.has(socket_id):
			continue
		var socket = socket_by_id[socket_id]
		if socket != null and is_instance_valid(socket) and socket.has_method("apply_save_state"):
			socket.apply_save_state(state)


func _get_defense_socket_by_id() -> Dictionary:
	var sockets := {}
	for socket in _get_local_defense_sockets():
		if socket == null or not is_instance_valid(socket):
			continue
		sockets[StringName(socket.socket_id)] = socket
	return sockets


func _get_scavenge_node_save_states() -> Array[Dictionary]:
	var save_states: Array[Dictionary] = []
	for node in _get_local_scavenge_nodes():
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_method("get_save_state"):
			continue
		save_states.append(node.get_save_state())
	return save_states


func _apply_scavenge_node_save_states(save_states: Array) -> void:
	var node_by_id := _get_scavenge_node_by_id()
	for raw_state in save_states:
		var state: Dictionary = raw_state
		var node_id := StringName(state.get("node_id", ""))
		if node_id == StringName() or not node_by_id.has(node_id):
			continue
		var node = node_by_id[node_id]
		if node != null and is_instance_valid(node) and node.has_method("apply_save_state"):
			node.apply_save_state(state)


func _get_scavenge_node_by_id() -> Dictionary:
	var nodes := {}
	for node in _get_local_scavenge_nodes():
		if node == null or not is_instance_valid(node):
			continue
		nodes[StringName(node.node_id)] = node
	return nodes


func _get_local_defense_sockets() -> Array:
	var sockets: Array = []
	if defense_sockets == null or not is_instance_valid(defense_sockets):
		return sockets
	for socket in defense_sockets.get_children():
		if socket == null or not is_instance_valid(socket):
			continue
		sockets.append(socket)
	return sockets


func _get_local_scavenge_nodes() -> Array:
	return _get_local_group_members(&"scavenge_nodes")


func _get_local_group_members(group_name: StringName) -> Array:
	var members: Array = []
	_collect_local_group_members(self, group_name, members)
	return members


func _collect_local_group_members(node: Node, group_name: StringName, members: Array) -> void:
	if node == null or not is_instance_valid(node):
		return
	for child in node.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if child.is_in_group(String(group_name)):
			members.append(child)
		_collect_local_group_members(child, group_name, members)


func _restore_daily_run_state(game_state: Dictionary) -> void:
	exploration_controller.apply_game_state(game_state)
	_sync_exploration_state_aliases()
	poi_controller.apply_game_state(game_state)


func _sync_mvp1_state_aliases() -> void:
	if mvp1_run_controller == null or not is_instance_valid(mvp1_run_controller):
		return
	legacy_perk_id = mvp1_run_controller.legacy_perk_id
	_active_heirloom_socket_ids = mvp1_run_controller.get_active_heirloom_socket_ids()
	_pending_heirloom_socket_ids = mvp1_run_controller.get_pending_heirloom_socket_ids()
	_last_terminal_run_state = mvp1_run_controller.get_last_terminal_run_state()


func _get_run_state_label(run_state: int) -> String:
	match run_state:
		game_manager.RunState.PRE_WAVE:
			return "Day"
		game_manager.RunState.ACTIVE_WAVE:
			return "Night"
		game_manager.RunState.POST_WAVE:
			return "Post-Wave"
		game_manager.RunState.WIN:
			return "Victory"
		game_manager.RunState.LOSS:
			return "Loss"
	return "Unknown"


func _duplicate_stringname_dictionary(raw_dictionary: Dictionary) -> Dictionary:
	var result := {}
	for key in raw_dictionary.keys():
		result[StringName(String(key))] = StringName(raw_dictionary[key])
	return result


func _get_weapon_definition_by_id(weapon_id: StringName) -> Resource:
	if weapon_id == StringName():
		return null

	var weapon_dir := DirAccess.open("res://data/weapons")
	if weapon_dir == null:
		return null

	for file_name in weapon_dir.get_files():
		if not file_name.ends_with(".tres") and not file_name.ends_with(".res"):
			continue
		var weapon_path := "res://data/weapons/%s" % file_name
		var weapon := load(weapon_path)
		if weapon == null or not weapon.has_method("is_valid_definition"):
			continue
		if not weapon.is_valid_definition():
			continue
		if StringName(weapon.weapon_id) == weapon_id:
			return weapon

	return null
