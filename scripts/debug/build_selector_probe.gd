extends SceneTree


func _wait_frames() -> void:
	await process_frame
	await physics_frame
	await process_frame


func _press_action(action_name: StringName) -> void:
	Input.action_press(action_name)
	await physics_frame
	await process_frame
	Input.action_release(action_name)
	await process_frame


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game: Game = game_scene.instantiate() as Game
	game.enable_test_mode = true
	root.add_child(game)
	await _wait_frames()

	var grid = game.construction_grid
	var player = game.player
	var placeables_root = game.construction_placeables

	var first_profile: PlaceableProfile = game.get_selected_buildable_profile()
	print("build_selector_probe_initial_profile=%s" % str(first_profile.placeable_id if first_profile != null else StringName()))
	print("build_selector_probe_initial_footprint=%d" % int(first_profile.footprint_cells.size() if first_profile != null else 0))

	player.global_position = grid.to_global(Vector2(-2.0 * grid.cell_size.x, 3.0 * grid.cell_size.y))
	await _wait_frames()
	await _press_action("build_mode")
	await _wait_frames()
	print("build_selector_probe_build_mode=%s" % str(player.is_build_mode_active()))
	print("build_selector_probe_preview_footprint_cells=%d" % int(grid.preview_footprint.get_child_count() / 2))

	await _press_action("build_next")
	await _wait_frames()
	var second_profile: PlaceableProfile = game.get_selected_buildable_profile()
	print("build_selector_probe_next_profile=%s" % str(second_profile.placeable_id if second_profile != null else StringName()))
	print("build_selector_probe_next_footprint=%d" % int(second_profile.footprint_cells.size() if second_profile != null else 0))
	print("build_selector_probe_next_preview_footprint_cells=%d" % int(grid.preview_footprint.get_child_count() / 2))
	print("build_selector_probe_next_preview_reason=%s" % grid.get_preview_reason())

	await _press_action("build_rotate")
	await _wait_frames()
	print("build_selector_probe_rotation=%d" % game.get_selected_buildable_rotation())
	print("build_selector_probe_rotated_preview_footprint_cells=%d" % int(grid.preview_footprint.get_child_count() / 2))
	print("build_selector_probe_rotated_preview_reason=%s" % grid.get_preview_reason())

	var before_count: int = placeables_root.get_child_count()
	await _press_action("interact")
	await _wait_frames()
	print("build_selector_probe_placeables=%d" % placeables_root.get_child_count())
	print("build_selector_probe_placed=%s" % str(placeables_root.get_child_count() > before_count))
	print("build_selector_probe_anchor_occupied=%s" % str(grid.is_cell_occupied(Vector2i(-2, 3))))
	print("build_selector_probe_horizontal_cell_occupied=%s" % str(grid.is_cell_occupied(Vector2i(-1, 3))))
	var placed_placeable: Node = placeables_root.get_child(placeables_root.get_child_count() - 1) if placeables_root.get_child_count() > 0 else null
	print("build_selector_probe_placeable_id=%s" % str(placed_placeable.get_placeable_id() if placed_placeable != null and placed_placeable.has_method("get_placeable_id") else StringName()))
	print("build_selector_probe_placeable_scale=%s" % str(placed_placeable.scale if placed_placeable != null else Vector2.ZERO))
	print("build_selector_probe_rotated_anchor_occupied=%s" % str(grid.is_cell_occupied(Vector2i(-2, 3))))
	print("build_selector_probe_rotated_second_cell_occupied=%s" % str(grid.is_cell_occupied(Vector2i(-2, 4))))
	quit()
