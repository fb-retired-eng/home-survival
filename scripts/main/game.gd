extends Node2D
class_name Game

const BASE_PERIMETER_DEFINITION_SCRIPT := preload("res://scripts/data/base_perimeter_definition.gd")
const PERIMETER_SEGMENT_DEFINITION_SCRIPT := preload("res://scripts/data/perimeter_segment_definition.gd")
const STRUCTURE_PROFILE_SCRIPT := preload("res://scripts/data/structure_profile.gd")
const EXPLORATION_SPAWN_POINT_SCRIPT := preload("res://scripts/world/exploration_spawn_point.gd")
const ENEMY_DEFINITION_SCRIPT := preload("res://scripts/data/enemy_definition.gd")
const ROAMING_SPAWN_ZONE_SCRIPT := preload("res://scripts/world/roaming_spawn_zone.gd")
const PLACEABLE_PROFILE_SCRIPT := preload("res://scripts/data/placeable_profile.gd")
const POSITIVE_POI_MODIFIERS: Array[StringName] = [&"bountiful_food", &"extra_parts"]
const NEGATIVE_POI_MODIFIERS: Array[StringName] = [&"disturbed", &"elite_present"]
const ELITE_MODIFIER_POIS := {
	&"poi_b": true,
	&"poi_d": true,
	&"poi_f": true,
}

@export var defense_socket_scene: PackedScene
@export var exploration_enemy_scene: PackedScene
@export var perimeter_definition: Resource
@export var default_daily_elite_enemy: Resource
@export var construction_placeable_scene: PackedScene
@export var barricade_placeable_profile: Resource
@export var buildable_placeable_profiles: Array[Resource] = []
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

@onready var game_manager = $GameManager
@onready var player = $Player
@onready var hud = $HUD
@onready var wave_manager = $WaveManager
@onready var food_table: Area2D = $World/FoodTable
@onready var sleep_point: Area2D = $World/SleepPoint
@onready var spawn_markers_root: Node2D = $World/SpawnMarkers
@onready var defense_sockets: Node2D = $World/DefenseSockets
@onready var construction_grid = $World/ConstructionGrid
@onready var exploration_spawn_points_root: Node2D = $World/ExplorationSpawnPoints
@onready var roaming_spawn_zones_root: Node2D = $World/RoamingSpawnZones
@onready var construction_placeables: Node2D = $World/ConstructionPlaceables
@onready var exploration_enemy_layer: Node2D = $World/ExplorationEnemies
@onready var wave_enemy_layer: Node2D = $World/WaveEnemies

var _defeated_exploration_spawn_ids: Dictionary = {}
var _exploration_spawn_counts: Dictionary = {}
var _defeated_exploration_enemy_counts: Dictionary = {}
var _current_exploration_target_counts: Dictionary = {}
var _is_resetting_run: bool = false
var _daily_poi_modifiers: Dictionary = {}
var _poi_visuals_by_id: Dictionary = {}
var _debug_forced_next_daily_poi_modifiers: Dictionary = {}
var _last_daily_refilled_pois: Array[StringName] = []
var _selected_buildable_profile_index: int = 0
var _selected_buildable_rotation: int = 0


func _ready() -> void:
	randomize()
	_build_defense_sockets()
	_register_fixed_grid_footprints()
	_validate_exploration_spawn_points()
	_validate_roaming_spawn_zones()
	_cache_poi_visuals()
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
	player.weapon_noise_emitted.connect(_on_player_weapon_noise_emitted)
	player.build_mode_toggled.connect(_on_player_build_mode_toggled)
	player.build_placement_requested.connect(_on_player_build_placement_requested)
	player.build_selection_prev_requested.connect(_on_player_build_selection_prev_requested)
	player.build_selection_next_requested.connect(_on_player_build_selection_next_requested)
	player.build_rotation_requested.connect(_on_player_build_rotation_requested)
	game_manager.run_state_changed.connect(_on_run_state_changed)
	_configure_scavenge_nodes()
	player.set_build_mode_allowed(true)
	_on_wave_changed(game_manager.current_wave)
	_on_run_state_changed(game_manager.run_state)
	_refresh_base_status()


func _physics_process(_delta: float) -> void:
	if construction_grid == null:
		return
	if not construction_grid.is_build_mode_active():
		return
	if player == null or not is_instance_valid(player):
		return
	construction_grid.set_preview_world_position(player.global_position)


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
	player.set_build_mode_allowed(new_state != game_manager.RunState.LOSS and new_state != game_manager.RunState.WIN)
	if new_state == game_manager.RunState.LOSS:
		wave_manager.reset()
		_clear_exploration_enemies()
		player.set_build_mode_active(false, false)
		player.cancel_timed_action()
		hud.show_end_overlay("Run Failed", "You died.\nPress R to restart.", Color(0.94, 0.42, 0.38, 1.0))
		hud.set_phase("Phase: Loss")
		hud.set_status("You died")
		hud.set_interaction_prompt("Press R to restart")
		return

	if new_state == game_manager.RunState.WIN:
		wave_manager.reset()
		_clear_exploration_enemies()
		player.set_build_mode_active(false, false)
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
		if player.is_build_mode_active():
			_refresh_build_mode_status()
		else:
			hud.set_status("Night %d in progress. Hold the base." % game_manager.current_wave)
		player.refresh_interaction_prompt()
		return

	if new_state == game_manager.RunState.POST_WAVE:
		hud.set_phase("Phase: Post-Wave")
		if player.is_build_mode_active():
			_refresh_build_mode_status()
		else:
			hud.set_status("Night %d cleared. Sleep on the bed to start the next day." % game_manager.current_wave)
		player.refresh_interaction_prompt()
		return

	if new_state == game_manager.RunState.PRE_WAVE:
		if _is_resetting_run:
			return
		_enter_day_phase()


func _on_player_build_mode_toggled(active: bool) -> void:
	if construction_grid == null:
		return
	construction_grid.set_build_mode_active(active)
	if active:
		_refresh_build_mode_preview()
		_refresh_build_mode_status()
		return
	_refresh_phase_status()


func _on_player_build_selection_prev_requested() -> void:
	_cycle_selected_buildable_profile(-1)


func _on_player_build_selection_next_requested() -> void:
	_cycle_selected_buildable_profile(1)


func _on_player_build_rotation_requested() -> void:
	_cycle_selected_buildable_rotation(1)


func _on_wave_changed(new_wave: int) -> void:
	hud.set_wave(new_wave, game_manager.final_wave)
	player.refresh_interaction_prompt()
	_refresh_phase_status()


func _refresh_phase_status() -> void:
	if player != null and is_instance_valid(player) and player.is_build_mode_active():
		_refresh_build_mode_status()
		return
	var base_status := ""
	match game_manager.run_state:
		game_manager.RunState.PRE_WAVE:
			if game_manager.current_wave <= 0:
				base_status = "Day 1. Scavenge carefully, build up, and eat dinner at the table to start night 1."
			elif game_manager.current_wave < game_manager.final_wave - 1:
				base_status = "Day %d. Explore, build, and eat dinner at the table to start night %d." % [game_manager.current_wave + 1, game_manager.current_wave + 1]
			else:
				base_status = "Final day. Make repairs, gather food, and eat dinner before the last night."
		game_manager.RunState.ACTIVE_WAVE:
			base_status = "Night %d in progress. Hold the base." % game_manager.current_wave
		game_manager.RunState.POST_WAVE:
			base_status = "Night %d cleared. Sleep on the bed to start the next day." % game_manager.current_wave
		_:
			return

	var modifier_summary := _get_daily_modifier_summary()
	if modifier_summary.is_empty():
		hud.set_status(base_status)
		return
	hud.set_status("%s %s" % [base_status, modifier_summary])


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
	_current_exploration_target_counts.clear()
	_daily_poi_modifiers.clear()
	_selected_buildable_profile_index = 0
	for pickup in get_tree().get_nodes_in_group("pickups"):
		pickup.queue_free()
	player.reset_for_new_run()
	_apply_test_mode_loadout()
	for socket in defense_sockets.get_children():
		if socket.has_method("reset_for_new_run"):
			socket.reset_for_new_run()
	for child in construction_placeables.get_children():
		if is_instance_valid(child):
			child.queue_free()
	_register_fixed_grid_footprints()
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
	if test_mode_salvage > 0:
		player.add_resource("salvage", test_mode_salvage, false)
	if test_mode_parts > 0:
		player.add_resource("parts", test_mode_parts, false)
	if test_mode_bullets > 0:
		player.add_resource("bullets", test_mode_bullets, false)
	if test_mode_food > 0:
		player.add_resource("food", test_mode_food, false)


func _get_buildable_placeable_profiles() -> Array[PlaceableProfile]:
	var profiles: Array[PlaceableProfile] = []
	for raw_profile in buildable_placeable_profiles:
		var profile: PlaceableProfile = raw_profile as PlaceableProfile
		if profile == null or profile.get_script() != PLACEABLE_PROFILE_SCRIPT:
			continue
		profiles.append(profile)

	if profiles.is_empty():
		var fallback_profile: PlaceableProfile = barricade_placeable_profile as PlaceableProfile
		if fallback_profile != null and fallback_profile.get_script() == PLACEABLE_PROFILE_SCRIPT:
			profiles.append(fallback_profile)
	return profiles


func get_selected_buildable_profile() -> PlaceableProfile:
	var profiles := _get_buildable_placeable_profiles()
	if profiles.is_empty():
		return null
	_selected_buildable_profile_index = clampi(_selected_buildable_profile_index, 0, profiles.size() - 1)
	return profiles[_selected_buildable_profile_index]


func get_selected_buildable_rotation() -> int:
	return posmod(_selected_buildable_rotation, 4)


func _cycle_selected_buildable_profile(step: int) -> void:
	var profiles := _get_buildable_placeable_profiles()
	if profiles.is_empty():
		return
	if step == 0:
		return
	_selected_buildable_profile_index = posmod(_selected_buildable_profile_index + step, profiles.size())
	_selected_buildable_rotation = 0
	_refresh_build_mode_preview()
	_refresh_build_mode_status()
	player.refresh_interaction_prompt()


func _cycle_selected_buildable_rotation(step: int) -> void:
	var profile := get_selected_buildable_profile()
	if profile == null:
		return
	if step == 0:
		return
	_selected_buildable_rotation = posmod(_selected_buildable_rotation + step, 4)
	_refresh_build_mode_preview()
	_refresh_build_mode_status()
	player.refresh_interaction_prompt()


func _refresh_build_mode_preview() -> void:
	if construction_grid == null or not construction_grid.is_build_mode_active():
		return
	var profile := get_selected_buildable_profile()
	if profile == null:
		return
	construction_grid.set_preview_footprint_offsets(profile.get_rotated_footprint_offsets(_selected_buildable_rotation))
	construction_grid.set_preview_world_position(player.global_position)


func _refresh_build_mode_status() -> void:
	if game_manager.run_state == game_manager.RunState.LOSS or game_manager.run_state == game_manager.RunState.WIN:
		return
	var profile := get_selected_buildable_profile()
	if profile == null:
		hud.set_status("Build mode active")
		return
	var footprint := profile.get_rotated_footprint_dimensions(_selected_buildable_rotation)
	hud.set_status("Build: %s (%dx%d, rot %d) | E place | Q prev | Tab next | R rotate | C recycle" % [
		profile.display_name,
		footprint.x,
		footprint.y,
		get_selected_buildable_rotation()
	])


func _register_fixed_grid_footprints() -> void:
	if construction_grid == null:
		return

	construction_grid.clear_runtime_occupancy()
	construction_grid.clear_runtime_reserved_cells()
	_register_fixed_grid_rect(sleep_point, _get_area_shape_size(sleep_point), &"sleep_point")
	_register_fixed_grid_rect(food_table, _get_area_shape_size(food_table), &"food_table")

	for socket in defense_sockets.get_children():
		if socket == null or not is_instance_valid(socket):
			continue
		if socket.has_method("is_breached") and socket.is_breached():
			continue
		_register_fixed_grid_rect(socket, socket.socket_size, StringName(socket.socket_id))

	for placeable in construction_placeables.get_children():
		if placeable == null or not is_instance_valid(placeable):
			continue
		if not placeable.has_method("get_footprint_cells"):
			continue
		if placeable.has_method("is_breached") and placeable.is_breached():
			continue
		var footprint: PackedVector2Array = placeable.get_footprint_cells()
		if footprint.is_empty():
			continue
		var anchor_cell: Vector2i = construction_grid.get_cell_for_world_position(placeable.global_position)
		if placeable.has_method("get_footprint_anchor_cell"):
			anchor_cell = placeable.get_footprint_anchor_cell()
		construction_grid.register_occupied_footprint(
			anchor_cell,
			footprint,
			StringName(placeable.get_placeable_id())
		)


func _register_fixed_grid_rect(node: Node2D, rect_size: Vector2, occupant_id: StringName) -> void:
	if node == null or not is_instance_valid(node):
		return
	if rect_size.x <= 0.0 or rect_size.y <= 0.0:
		return
	construction_grid.register_occupied_cells(
		construction_grid.get_cells_for_world_rect(node.global_position, rect_size),
		occupant_id
	)


func _on_player_build_placement_requested() -> void:
	if game_manager.run_state == game_manager.RunState.LOSS or game_manager.run_state == game_manager.RunState.WIN:
		return
	if construction_grid == null or construction_placeables == null:
		return
	if construction_placeable_scene == null:
		hud.set_status("Placeable scene missing")
		return

	var profile := get_selected_buildable_profile()
	if profile == null:
		hud.set_status("Build profile missing")
		return
	var preview_cell: Vector2i = construction_grid.get_preview_cell()
	var footprint_offsets := profile.get_rotated_footprint_offsets(_selected_buildable_rotation)
	var footprint_cells: Array[Vector2i] = construction_grid.get_footprint_cells(preview_cell, footprint_offsets)
	if not construction_grid.is_footprint_valid_for_basic_placeable(preview_cell, footprint_offsets):
		hud.set_status(construction_grid.get_preview_reason())
		return
	if profile.blocks_movement and _would_block_all_door_routes(footprint_cells):
		hud.set_status("Would seal both doors")
		return
	if not player.has_resources(profile.build_cost):
		hud.set_status("Need %s" % _format_cost(profile.build_cost))
		return
	if not player.spend_resources(profile.build_cost):
		hud.set_status("Need %s" % _format_cost(profile.build_cost))
		return

	var placeable = construction_placeable_scene.instantiate()
	placeable.profile = profile
	placeable.footprint_anchor_cell = preview_cell
	placeable.placement_rotation_steps = get_selected_buildable_rotation()
	placeable.global_position = construction_grid.get_preview_world_position() + profile.get_rotated_footprint_center_offset(_selected_buildable_rotation) * construction_grid.cell_size
	var footprint_dimensions := profile.get_rotated_footprint_dimensions(_selected_buildable_rotation)
	placeable.scale = Vector2(maxf(float(footprint_dimensions.x), 1.0), maxf(float(footprint_dimensions.y), 1.0))
	placeable.state_changed.connect(_on_construction_placeable_state_changed)
	construction_placeables.add_child(placeable)
	if placeable.has_method("begin_player_collision_grace"):
		placeable.begin_player_collision_grace(player, construction_grid, footprint_cells, 1)
	_register_fixed_grid_footprints()
	_refresh_build_mode_preview()
	_refresh_build_mode_status()
	player.refresh_interaction_prompt()


func _on_construction_placeable_state_changed(_placeable) -> void:
	_register_fixed_grid_footprints()


func _format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in ["salvage", "parts", "medicine", "food", "bullets"]:
		var amount := int(cost.get(resource_id, 0))
		if amount <= 0:
			continue
		parts.append("%d %s" % [amount, resource_id.capitalize()])
	return ", ".join(parts)


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
	var west_zone: Array[Vector2i] = [Vector2i(-1, 2), Vector2i(-1, 3), Vector2i(-1, 4)]
	var east_zone: Array[Vector2i] = [Vector2i(9, 2), Vector2i(9, 3), Vector2i(9, 4)]
	var footprint_blocks_west := _cell_list_intersects(footprint_cells, west_zone)
	var footprint_blocks_east := _cell_list_intersects(footprint_cells, east_zone)
	if not footprint_blocks_west and not footprint_blocks_east:
		return false
	if footprint_blocks_west and _has_any_occupied_cell(east_zone):
		return true
	if footprint_blocks_east and _has_any_occupied_cell(west_zone):
		return true
	return false


func _cell_list_intersects(cells_a: Array, cells_b: Array) -> bool:
	for cell_a in cells_a:
		for cell_b in cells_b:
			if cell_a == cell_b:
				return true
	return false


func _has_any_occupied_cell(cells: Array) -> bool:
	for cell in cells:
		if construction_grid.is_cell_occupied(cell):
			return true
	return false


func _on_player_weapon_noise_emitted(source_position: Vector2, noise_radius: float, noise_alert_budget: float, _weapon_id: StringName) -> void:
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
		if not child.has_method("receive_noise_alert"):
			continue
		if not _can_enemy_hear_weapon_noise(child, source_position, noise_radius):
			continue
		candidates.append(child)

	candidates.sort_custom(func(a, b):
		return source_position.distance_squared_to(a.global_position) < source_position.distance_squared_to(b.global_position)
	)

	var remaining_budget := noise_alert_budget
	for enemy in candidates:
		var alert_weight := 1.0
		if enemy.has_method("get_noise_alert_weight"):
			alert_weight = float(enemy.get_noise_alert_weight())
		if alert_weight <= 0.0:
			continue
		if remaining_budget < alert_weight:
			continue
		enemy.receive_noise_alert(player, source_position)
		remaining_budget -= alert_weight


func _can_enemy_hear_weapon_noise(enemy, source_position: Vector2, noise_radius: float) -> bool:
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
	var hit := get_world_2d().direct_space_state.intersect_ray(ray_query)
	return hit.is_empty() or hit.get("collider") == enemy


func _enter_day_phase() -> void:
	_roll_daily_poi_modifiers()
	_apply_daily_poi_refills()
	_current_exploration_target_counts.clear()
	_refresh_poi_modifier_visuals()
	_clear_stale_daily_modifier_enemies()
	_sync_exploration_enemies()
	_sync_daily_modifier_enemies()
	_spawn_roaming_exploration_enemies()
	hud.set_phase("Phase: Day")
	player.refresh_interaction_prompt()
	_refresh_phase_status()


func _configure_scavenge_nodes() -> void:
	for node in get_tree().get_nodes_in_group("scavenge_nodes"):
		if node.has_method("configure_reward_modifier"):
			node.configure_reward_modifier(Callable(self, "_apply_daily_poi_reward_modifier"))


func _apply_daily_poi_reward_modifier(node, rewards: Dictionary) -> Dictionary:
	var modified_rewards: Dictionary = rewards.duplicate(true)
	if node == null:
		return modified_rewards

	var poi_id := StringName(node.poi_id)
	var modifier_id := _get_daily_poi_modifier(poi_id)
	match modifier_id:
		&"bountiful_food":
			modified_rewards["food"] = int(modified_rewards.get("food", 0)) + 1
		&"extra_parts":
			modified_rewards["parts"] = int(modified_rewards.get("parts", 0)) + 1

	return modified_rewards


func _roll_daily_poi_modifiers() -> void:
	_daily_poi_modifiers.clear()

	if _poi_visuals_by_id.is_empty():
		return

	if not _debug_forced_next_daily_poi_modifiers.is_empty():
		_daily_poi_modifiers = _debug_forced_next_daily_poi_modifiers.duplicate(true)
		_debug_forced_next_daily_poi_modifiers.clear()
		return

	var used_pois := {}
	_assign_random_daily_modifier(POSITIVE_POI_MODIFIERS, used_pois)
	_assign_random_daily_modifier(NEGATIVE_POI_MODIFIERS, used_pois)


func _assign_random_daily_modifier(candidate_modifiers: Array[StringName], used_pois: Dictionary) -> void:
	var available_assignments: Array[Dictionary] = []
	for modifier_id in candidate_modifiers:
		var eligible_pois := _get_modifier_eligible_poi_ids(modifier_id, used_pois)
		if eligible_pois.is_empty():
			continue
		available_assignments.append({
			"modifier": modifier_id,
			"pois": eligible_pois,
		})

	if available_assignments.is_empty():
		return

	var assignment: Dictionary = available_assignments[randi() % available_assignments.size()]
	var modifier_id := StringName(assignment.get("modifier", StringName()))
	var eligible_pois: Array[StringName] = assignment.get("pois", [])
	if eligible_pois.is_empty():
		return
	var poi_id: StringName = eligible_pois[randi() % eligible_pois.size()]
	_daily_poi_modifiers[poi_id] = modifier_id
	used_pois[poi_id] = true


func _get_modifier_eligible_poi_ids(modifier_id: StringName, excluded_pois: Dictionary) -> Array[StringName]:
	var eligible: Array[StringName] = []
	for poi_id_variant in _poi_visuals_by_id.keys():
		var poi_id := StringName(poi_id_variant)
		if excluded_pois.has(poi_id):
			continue
		if _is_poi_depleted(poi_id):
			continue
		if modifier_id == &"elite_present" and not _is_poi_eligible_for_elite_modifier(poi_id):
			continue
		eligible.append(poi_id)
	return eligible


func _is_poi_depleted(poi_id: StringName) -> bool:
	var total_nodes := 0
	var depleted_nodes := 0
	for node in get_tree().get_nodes_in_group("scavenge_nodes"):
		if StringName(node.poi_id) != poi_id:
			continue
		total_nodes += 1
		if bool(node.is_depleted):
			depleted_nodes += 1
	return total_nodes > 0 and total_nodes == depleted_nodes


func _is_poi_eligible_for_elite_modifier(poi_id: StringName) -> bool:
	if not ELITE_MODIFIER_POIS.has(poi_id):
		return false
	var guard_spawn = _get_poi_guard_spawn_point(poi_id)
	if guard_spawn == null:
		return false
	var enemy_definition: Resource = guard_spawn.enemy_definition
	if enemy_definition == null or enemy_definition.get_script() != ENEMY_DEFINITION_SCRIPT:
		return false
	return not bool(enemy_definition.is_elite)


func _cache_poi_visuals() -> void:
	_poi_visuals_by_id.clear()
	var world_node := get_node_or_null("World")
	if world_node == null:
		return

	for child in world_node.get_children():
		var poi_id := _get_poi_id_from_name(String(child.name))
		if poi_id == StringName():
			continue
		var label: Label = child.get_node_or_null("Label")
		var marker: Polygon2D = child.get_node_or_null("Marker")
		if label == null or marker == null:
			continue
		label.offset_left = -56.0
		label.offset_right = 84.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_poi_visuals_by_id[poi_id] = {
			"root": child,
			"label": label,
			"marker": marker,
			"base_text": label.text,
			"base_marker_color": marker.color,
			"base_marker_scale": marker.scale,
			"base_label_color": label.get_theme_color("font_color"),
		}


func _refresh_poi_modifier_visuals() -> void:
	for poi_id_variant in _poi_visuals_by_id.keys():
		var poi_id := StringName(poi_id_variant)
		var visual_data: Dictionary = _poi_visuals_by_id[poi_id]
		var label: Label = visual_data.get("label")
		var marker: Polygon2D = visual_data.get("marker")
		var base_text := String(visual_data.get("base_text", ""))
		var base_marker_color: Color = visual_data.get("base_marker_color", Color.WHITE)
		var base_marker_scale: Vector2 = visual_data.get("base_marker_scale", Vector2.ONE)
		var base_label_color: Color = visual_data.get("base_label_color", Color.WHITE)
		var modifier_id := _get_daily_poi_modifier(poi_id)
		if modifier_id == StringName():
			label.text = base_text
			label.add_theme_color_override("font_color", base_label_color)
			marker.color = base_marker_color
			marker.scale = base_marker_scale
			continue
		label.text = "%s %s" % [base_text, _get_modifier_label_text(modifier_id)]
		var modifier_tint := _get_modifier_tint(modifier_id)
		label.add_theme_color_override("font_color", modifier_tint)
		marker.color = base_marker_color.lerp(modifier_tint, 0.48)
		marker.scale = base_marker_scale * _get_modifier_marker_scale(modifier_id)


func _get_poi_id_from_name(node_name: String) -> StringName:
	var lower_name := node_name.to_lower()
	if not lower_name.begins_with("poi_") or lower_name.length() < 5:
		return StringName()
	return StringName("poi_%s" % lower_name.substr(4, 1))


func _get_modifier_label_text(modifier_id: StringName) -> String:
	match modifier_id:
		&"bountiful_food":
			return "[FOOD]"
		&"extra_parts":
			return "[PARTS]"
		&"disturbed":
			return "[HOT]"
		&"elite_present":
			return "[ELITE]"
	return ""


func _get_modifier_tint(modifier_id: StringName) -> Color:
	match modifier_id:
		&"bountiful_food":
			return Color(0.58, 0.96, 0.46, 1.0)
		&"extra_parts":
			return Color(0.66, 0.9, 1.0, 1.0)
		&"disturbed":
			return Color(1.0, 0.62, 0.24, 1.0)
		&"elite_present":
			return Color(1.0, 0.86, 0.32, 1.0)
	return Color.WHITE


func _get_modifier_marker_scale(modifier_id: StringName) -> Vector2:
	match modifier_id:
		&"bountiful_food":
			return Vector2(1.08, 1.08)
		&"extra_parts":
			return Vector2(1.08, 1.08)
		&"disturbed":
			return Vector2(1.14, 1.14)
		&"elite_present":
			return Vector2(1.22, 1.22)
	return Vector2.ONE


func _get_daily_modifier_summary() -> String:
	var clauses: Array[String] = []
	for poi_id_variant in _daily_poi_modifiers.keys():
		var poi_id := StringName(poi_id_variant)
		var modifier_id := StringName(_daily_poi_modifiers[poi_id])
		var poi_name := _get_poi_display_name(poi_id)
		match modifier_id:
			&"bountiful_food":
				clauses.append("%s has extra food." % poi_name)
			&"extra_parts":
				clauses.append("%s has extra parts." % poi_name)
			&"disturbed":
				clauses.append("%s is disturbed." % poi_name)
			&"elite_present":
				clauses.append("%s has an elite guard." % poi_name)
	if not _last_daily_refilled_pois.is_empty():
		var restocked_names: Array[String] = []
		for poi_id in _last_daily_refilled_pois:
			restocked_names.append(_get_poi_display_name(poi_id))
		clauses.append("%s restocked." % ", ".join(restocked_names))
	return " ".join(clauses)


func _get_poi_display_name(poi_id: StringName) -> String:
	if not _poi_visuals_by_id.has(poi_id):
		return String(poi_id)
	return String(_poi_visuals_by_id[poi_id].get("base_text", String(poi_id)))


func _get_daily_poi_modifier(poi_id: StringName) -> StringName:
	return StringName(_daily_poi_modifiers.get(poi_id, StringName()))


func _apply_daily_poi_refills() -> void:
	_last_daily_refilled_pois.clear()
	var refill_budget: int = max(daily_poi_refill_base_nodes, 0)
	if daily_poi_refill_bonus_nodes > 0 and randf() <= daily_poi_refill_bonus_chance:
		refill_budget += daily_poi_refill_bonus_nodes
	if refill_budget <= 0:
		return

	var candidates: Array = []
	for node in get_tree().get_nodes_in_group("scavenge_nodes"):
		if node == null or not node.has_method("is_eligible_for_daily_refill"):
			continue
		if not bool(node.is_eligible_for_daily_refill()):
			continue
		candidates.append(node)

	while refill_budget > 0 and not candidates.is_empty():
		var index := randi() % candidates.size()
		var node = candidates[index]
		candidates.remove_at(index)
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_method("apply_daily_refill"):
			continue
		if not bool(node.apply_daily_refill()):
			continue
		refill_budget -= 1
		var poi_id := StringName(node.poi_id)
		if poi_id != StringName() and not _last_daily_refilled_pois.has(poi_id):
			_last_daily_refilled_pois.append(poi_id)


func _get_adjusted_exploration_spawn_count(spawn_point) -> int:
	var spawn_id := String(spawn_point.spawn_id)
	var target_count := _get_or_roll_exploration_spawn_count(spawn_point)
	var poi_id := _get_poi_id_for_exploration_spawn(spawn_point)
	if poi_id == StringName():
		_current_exploration_target_counts[spawn_id] = target_count
		return target_count
	if _get_daily_poi_modifier(poi_id) == &"disturbed":
		target_count += 1
	_current_exploration_target_counts[spawn_id] = target_count
	return target_count


func _get_poi_id_for_exploration_spawn(spawn_point) -> StringName:
	if spawn_point == null:
		return StringName()
	return _get_poi_id_from_name(String(spawn_point.name))


func _sync_daily_modifier_enemies() -> void:
	if game_manager.run_state != game_manager.RunState.PRE_WAVE:
		return
	for poi_id_variant in _daily_poi_modifiers.keys():
		var poi_id := StringName(poi_id_variant)
		if _get_daily_poi_modifier(poi_id) != &"elite_present":
			continue
		if _has_active_daily_modifier_elite(poi_id):
			continue
		var guard_spawn = _get_poi_guard_spawn_point(poi_id)
		if guard_spawn == null:
			continue
		_spawn_daily_modifier_elite(poi_id, guard_spawn)


func _clear_stale_daily_modifier_enemies() -> void:
	if exploration_enemy_layer == null:
		return
	for child in exploration_enemy_layer.get_children():
		if not is_instance_valid(child):
			continue
		if child.is_queued_for_deletion():
			continue
		if String(child.get_meta("spawn_kind", "")) != "daily_modifier_elite":
			continue
		var poi_id := StringName(child.get_meta("daily_modifier_poi_id", StringName()))
		if _get_daily_poi_modifier(poi_id) == &"elite_present":
			continue
		child.queue_free()


func _has_active_daily_modifier_elite(poi_id: StringName) -> bool:
	for child in exploration_enemy_layer.get_children():
		if not is_instance_valid(child):
			continue
		if child.is_queued_for_deletion():
			continue
		if StringName(child.get_meta("daily_modifier_poi_id", StringName())) == poi_id:
			return true
	return false


func _spawn_daily_modifier_elite(poi_id: StringName, guard_spawn) -> void:
	var elite_definition := _resolve_daily_modifier_elite_definition(guard_spawn)
	if exploration_enemy_scene == null or elite_definition == null:
		return
	var enemy = exploration_enemy_scene.instantiate()
	enemy.definition = elite_definition
	exploration_enemy_layer.add_child(enemy)
	enemy.global_position = _get_exploration_spawn_position(guard_spawn)
	enemy.set_meta("spawn_kind", "daily_modifier_elite")
	enemy.set_meta("daily_modifier_poi_id", poi_id)
	var initial_facing := Vector2.ZERO
	if guard_spawn.has_method("get_initial_facing_vector"):
		initial_facing = guard_spawn.get_initial_facing_vector()
	var anchor_position: Vector2 = enemy.global_position
	if guard_spawn.has_method("get_anchor_position"):
		anchor_position = guard_spawn.get_anchor_position()
	if enemy.has_method("configure_exploration_context"):
		enemy.configure_exploration_context(player, initial_facing, true, anchor_position, true)


func _resolve_daily_modifier_elite_definition(guard_spawn) -> Resource:
	if guard_spawn != null and guard_spawn.daily_elite_definition != null:
		var candidate: Resource = guard_spawn.daily_elite_definition
		if candidate.get_script() == ENEMY_DEFINITION_SCRIPT and candidate.is_valid_definition() and bool(candidate.is_elite):
			return candidate
	if default_daily_elite_enemy != null:
		if default_daily_elite_enemy.get_script() == ENEMY_DEFINITION_SCRIPT and default_daily_elite_enemy.is_valid_definition() and bool(default_daily_elite_enemy.is_elite):
			return default_daily_elite_enemy
	return null


func _get_poi_guard_spawn_point(poi_id: StringName):
	if exploration_spawn_points_root == null:
		return null
	for child in exploration_spawn_points_root.get_children():
		if child == null or child.get_script() != EXPLORATION_SPAWN_POINT_SCRIPT:
			continue
		if _get_poi_id_for_exploration_spawn(child) == poi_id:
			return child
	return null


func debug_get_daily_poi_modifiers() -> Dictionary:
	return _daily_poi_modifiers.duplicate(true)


func debug_set_daily_poi_modifiers(modifiers: Dictionary) -> void:
	_daily_poi_modifiers = modifiers.duplicate(true)
	_refresh_poi_modifier_visuals()


func debug_queue_forced_next_daily_poi_modifiers(modifiers: Dictionary) -> void:
	_debug_forced_next_daily_poi_modifiers = modifiers.duplicate(true)


func debug_get_poi_label_text(poi_id: StringName) -> String:
	if not _poi_visuals_by_id.has(poi_id):
		return ""
	var visual_data: Dictionary = _poi_visuals_by_id[poi_id]
	var label: Label = visual_data.get("label")
	return label.text if label != null else ""


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

		var target_count: int = _get_adjusted_exploration_spawn_count(child)
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


func _on_exploration_enemy_died(enemy, spawn_id: String) -> void:
	var defeated_count := int(_defeated_exploration_enemy_counts.get(spawn_id, 0)) + 1
	_defeated_exploration_enemy_counts[spawn_id] = defeated_count
	var target_count := int(_current_exploration_target_counts.get(spawn_id, 0))
	if target_count <= 0:
		var spawn_point = _get_exploration_spawn_point_by_id(spawn_id)
		if spawn_point != null:
			target_count = _get_adjusted_exploration_spawn_count(spawn_point)
		else:
			target_count = int(_exploration_spawn_counts.get(spawn_id, 1))
	var remaining_live_count := _count_live_exploration_enemies_for_spawn_id(spawn_id, enemy)
	if defeated_count >= target_count and remaining_live_count <= 0:
		_defeated_exploration_spawn_ids[spawn_id] = true


func _get_exploration_spawn_point_by_id(spawn_id: String):
	if exploration_spawn_points_root == null:
		return null
	for child in exploration_spawn_points_root.get_children():
		if child == null or child.get_script() != EXPLORATION_SPAWN_POINT_SCRIPT:
			continue
		if String(child.spawn_id) == spawn_id:
			return child
	return null


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
	_register_fixed_grid_footprints()
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
