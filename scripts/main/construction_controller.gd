extends Node
class_name ConstructionController

const PLACEABLE_PROFILE_SCRIPT := preload("res://scripts/data/placeable_profile.gd")

signal autosave_requested

var game_manager
var player
var hud
var construction_grid
var construction_placeables
var sleep_point
var food_table
var defense_sockets
var construction_placeable_scene: PackedScene
var barricade_placeable_profile: PlaceableProfile
var buildable_placeable_profiles: Array[PlaceableProfile] = []

var _selected_buildable_profile_index: int = 0
var _selected_buildable_rotation: int = 0


func configure(config: Dictionary) -> void:
	game_manager = config.get("game_manager")
	player = config.get("player")
	hud = config.get("hud")
	construction_grid = config.get("construction_grid")
	construction_placeables = config.get("construction_placeables")
	sleep_point = config.get("sleep_point")
	food_table = config.get("food_table")
	defense_sockets = config.get("defense_sockets")
	construction_placeable_scene = config.get("construction_placeable_scene")
	barricade_placeable_profile = config.get("barricade_placeable_profile") as PlaceableProfile
	buildable_placeable_profiles.clear()
	for raw_profile in config.get("buildable_placeable_profiles", []):
		var profile: PlaceableProfile = raw_profile as PlaceableProfile
		if profile == null or profile.get_script() != PLACEABLE_PROFILE_SCRIPT:
			continue
		buildable_placeable_profiles.append(profile)


func on_player_build_mode_toggled(active: bool) -> void:
	if construction_grid == null:
		return
	construction_grid.set_build_mode_active(active)
	if active:
		refresh_build_mode_preview()
		refresh_build_mode_status()


func on_player_build_selection_prev_requested() -> void:
	_cycle_selected_buildable_profile(-1)


func on_player_build_selection_next_requested() -> void:
	_cycle_selected_buildable_profile(1)


func on_player_build_rotation_requested() -> void:
	_cycle_selected_buildable_rotation(1)


func on_player_build_placement_requested() -> void:
	if game_manager == null:
		return
	if game_manager.run_state == game_manager.RunState.LOSS or game_manager.run_state == game_manager.RunState.WIN:
		return
	if construction_grid == null or construction_placeables == null:
		return
	if construction_placeable_scene == null:
		if hud != null:
			hud.set_status("Placeable scene missing")
		return

	var profile := get_selected_buildable_profile()
	if profile == null:
		if hud != null:
			hud.set_status("Build profile missing")
		return

	var preview_cell: Vector2i = construction_grid.get_preview_cell()
	var footprint_offsets := profile.get_rotated_footprint_offsets(_selected_buildable_rotation)
	var footprint_cells: Array[Vector2i] = construction_grid.get_footprint_cells(preview_cell, footprint_offsets)
	if not construction_grid.is_footprint_valid_for_basic_placeable(preview_cell, footprint_offsets):
		if hud != null:
			hud.set_status(construction_grid.get_preview_reason())
		return
	if profile.blocks_movement and _would_block_all_door_routes(footprint_cells):
		if hud != null:
			hud.set_status("Would seal both doors")
		return
	if player == null or not player.has_resources(profile.build_cost):
		if hud != null:
			hud.set_status("Need %s" % _format_cost(profile.build_cost))
		return
	if not player.spend_resources(profile.build_cost):
		if hud != null:
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
	refresh_runtime_occupancy({}, {}, null)
	refresh_build_mode_preview()
	refresh_build_mode_status()
	if player != null:
		player.refresh_interaction_prompt()
	autosave_requested.emit()


func refresh_runtime_occupancy(context: Dictionary = {}, reserve_cells: Dictionary = {}, extra_nodes = null) -> void:
	if construction_grid == null:
		return
	construction_grid.clear_runtime_occupancy()
	construction_grid.clear_runtime_reserved_cells()

	var occupancy_sleep_point = context.get("sleep_point", sleep_point)
	var occupancy_food_table = context.get("food_table", food_table)
	var occupancy_defense_sockets = context.get("defense_sockets", defense_sockets)

	_register_fixed_grid_rect(occupancy_sleep_point, _get_area_shape_size(occupancy_sleep_point), &"sleep_point")
	_register_fixed_grid_rect(occupancy_food_table, _get_area_shape_size(occupancy_food_table), &"food_table")

	if occupancy_defense_sockets != null and is_instance_valid(occupancy_defense_sockets):
		for socket in occupancy_defense_sockets.get_children():
			if socket == null or not is_instance_valid(socket):
				continue
			if socket.has_method("is_breached") and socket.is_breached():
				continue
			_register_fixed_grid_rect(socket, socket.socket_size, StringName(socket.socket_id))

	if construction_placeables != null and is_instance_valid(construction_placeables):
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
			construction_grid.register_occupied_footprint(anchor_cell, footprint, StringName(placeable.get_placeable_id()))


func get_selected_buildable_profile() -> PlaceableProfile:
	var profiles := _get_buildable_placeable_profiles()
	if profiles.is_empty():
		return null
	_selected_buildable_profile_index = clampi(_selected_buildable_profile_index, 0, profiles.size() - 1)
	return profiles[_selected_buildable_profile_index]


func get_selected_buildable_rotation() -> int:
	return posmod(_selected_buildable_rotation, 4)


func refresh_build_mode_preview() -> void:
	if construction_grid == null or not construction_grid.is_build_mode_active():
		return
	var profile := get_selected_buildable_profile()
	if profile == null or player == null:
		return
	construction_grid.set_preview_footprint_offsets(profile.get_rotated_footprint_offsets(_selected_buildable_rotation))
	construction_grid.set_preview_world_position(player.global_position)


func refresh_build_mode_status() -> void:
	if game_manager == null or hud == null:
		return
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


func get_selection_save_state() -> Dictionary:
	var selected_profile := get_selected_buildable_profile()
	return {
		"selected_buildable_profile_id": String(selected_profile.placeable_id) if selected_profile != null else "",
		"selected_buildable_rotation": get_selected_buildable_rotation(),
	}


func restore_selection_from_state(game_state: Dictionary) -> void:
	var saved_profile_id := StringName(game_state.get("selected_buildable_profile_id", ""))
	var saved_rotation := int(game_state.get("selected_buildable_rotation", 0))
	if saved_profile_id != StringName():
		var profiles := _get_buildable_placeable_profiles()
		for index in range(profiles.size()):
			var profile := profiles[index]
			if profile != null and StringName(profile.placeable_id) == saved_profile_id:
				_selected_buildable_profile_index = index
				break
	_selected_buildable_rotation = posmod(saved_rotation, 4)


func reset_selection() -> void:
	_selected_buildable_profile_index = 0
	_selected_buildable_rotation = 0


func get_construction_placeable_save_states() -> Array[Dictionary]:
	var save_states: Array[Dictionary] = []
	if construction_placeables == null or not is_instance_valid(construction_placeables):
		return save_states
	for placeable in construction_placeables.get_children():
		if placeable == null or not is_instance_valid(placeable):
			continue
		if not placeable.has_method("get_save_state"):
			continue
		save_states.append(placeable.get_save_state())
	return save_states


func apply_construction_placeable_save_states(save_states: Array) -> void:
	if construction_placeables == null or not is_instance_valid(construction_placeables):
		return
	for child in construction_placeables.get_children():
		if is_instance_valid(child):
			child.free()
	if construction_placeable_scene == null:
		return
	for raw_state in save_states:
		var state: Dictionary = raw_state
		var profile := lookup_placeable_profile(StringName(state.get("placeable_id", "")))
		if profile == null:
			continue
		var placeable = construction_placeable_scene.instantiate()
		placeable.profile = profile
		placeable.placement_rotation_steps = int(state.get("rotation_steps", 0))
		var anchor_data: Dictionary = state.get("anchor_cell", {})
		placeable.footprint_anchor_cell = Vector2i(int(anchor_data.get("x", 0)), int(anchor_data.get("y", 0)))
		var position_data: Dictionary = state.get("position", {})
		if position_data.is_empty():
			placeable.global_position = construction_grid.get_world_position_for_cell(placeable.footprint_anchor_cell)
		else:
			placeable.global_position = Vector2(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0)))
		placeable.state_changed.connect(_on_construction_placeable_state_changed)
		construction_placeables.add_child(placeable)
		if placeable.has_method("apply_save_state"):
			placeable.apply_save_state(state)


func lookup_placeable_profile(placeable_id: StringName) -> PlaceableProfile:
	var profiles := _get_buildable_placeable_profiles()
	for profile in profiles:
		if profile != null and StringName(profile.placeable_id) == placeable_id:
			return profile
	if barricade_placeable_profile != null and StringName(barricade_placeable_profile.placeable_id) == placeable_id:
		return barricade_placeable_profile
	return null


func _get_buildable_placeable_profiles() -> Array[PlaceableProfile]:
	var profiles: Array[PlaceableProfile] = []
	for profile in buildable_placeable_profiles:
		if profile == null or profile.get_script() != PLACEABLE_PROFILE_SCRIPT:
			continue
		profiles.append(profile)
	if profiles.is_empty() and barricade_placeable_profile != null and barricade_placeable_profile.get_script() == PLACEABLE_PROFILE_SCRIPT:
		profiles.append(barricade_placeable_profile)
	return profiles


func _cycle_selected_buildable_profile(step: int) -> void:
	var profiles := _get_buildable_placeable_profiles()
	if profiles.is_empty() or step == 0:
		return
	_selected_buildable_profile_index = posmod(_selected_buildable_profile_index + step, profiles.size())
	_selected_buildable_rotation = 0
	refresh_build_mode_preview()
	refresh_build_mode_status()
	if player != null:
		player.refresh_interaction_prompt()


func _cycle_selected_buildable_rotation(step: int) -> void:
	var profile := get_selected_buildable_profile()
	if profile == null or step == 0:
		return
	_selected_buildable_rotation = posmod(_selected_buildable_rotation + step, 4)
	refresh_build_mode_preview()
	refresh_build_mode_status()
	if player != null:
		player.refresh_interaction_prompt()


func _register_fixed_grid_rect(node: Node2D, rect_size: Vector2, occupant_id: StringName) -> void:
	if node == null or not is_instance_valid(node):
		return
	if rect_size.x <= 0.0 or rect_size.y <= 0.0:
		return
	construction_grid.register_occupied_cells(construction_grid.get_cells_for_world_rect(node.global_position, rect_size), occupant_id)


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


func _format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in ["salvage", "parts", "medicine", "food", "bullets"]:
		var amount := int(cost.get(resource_id, 0))
		if amount <= 0:
			continue
		parts.append("%d %s" % [amount, resource_id.capitalize()])
	return ", ".join(parts)


func _on_construction_placeable_state_changed(_placeable) -> void:
	refresh_runtime_occupancy()
	refresh_build_mode_preview()
	if player != null and is_instance_valid(player):
		player.refresh_interaction_prompt()
	if player != null and is_instance_valid(player) and player.is_build_mode_active():
		refresh_build_mode_status()
	autosave_requested.emit()
