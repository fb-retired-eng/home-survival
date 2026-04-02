extends SceneTree


func _wait_frames() -> void:
	await process_frame
	await physics_frame
	await process_frame


func _toggle_build_mode() -> void:
	Input.action_press("build_mode")
	await physics_frame
	await process_frame
	Input.action_release("build_mode")
	await process_frame


func _press_interact() -> void:
	Input.action_press("interact")
	await physics_frame
	await process_frame
	Input.action_release("interact")
	await process_frame


func _try_place(game, tactical_cell: Vector2i) -> Variant:
	var grid = game.construction_grid
	var player = game.player
	var placeables_root = game.construction_placeables
	var before_count: int = placeables_root.get_child_count()

	player.global_position = grid.to_global(Vector2(tactical_cell.x * grid.cell_size.x, tactical_cell.y * grid.cell_size.y))
	await _wait_frames()
	print("construction_expanded_probe_candidate=%s" % str(tactical_cell))
	print("construction_expanded_probe_preview_cell=%s" % str(grid.get_preview_cell()))
	print("construction_expanded_probe_preview_reason=%s" % str(grid.get_preview_reason()))
	await _press_interact()
	await _wait_frames()

	if placeables_root.get_child_count() > before_count:
		return placeables_root.get_child(placeables_root.get_child_count() - 1)

	print("construction_expanded_probe_status=%s" % str(game.hud.status_label.text))

	return null


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	game.enable_test_mode = true
	root.add_child(game)
	await _wait_frames()

	var grid = game.construction_grid
	var placeables_root = game.construction_placeables
	var candidates: Array[Vector2i] = [
		Vector2i(-2, 3),
		Vector2i(-2, 4),
		Vector2i(-2, 5),
		Vector2i(10, 3),
		Vector2i(10, 4),
		Vector2i(10, 5),
		Vector2i(4, -2),
		Vector2i(5, -2),
		Vector2i(6, -2),
		Vector2i(4, 8),
		Vector2i(5, 8),
		Vector2i(6, 8),
	]
	var starting_salvage := int(game.player.resources.get("salvage", 0))
	var selected_cell := Vector2i.ZERO
	var placed_placeable = null

	await _toggle_build_mode()
	await _wait_frames()

	for candidate in candidates:
		placed_placeable = await _try_place(game, candidate)
		if placed_placeable != null:
			selected_cell = candidate
			break

	if placed_placeable == null and game.player.is_build_mode_active():
		await _toggle_build_mode()
		await _wait_frames()

	print("construction_expanded_probe_selected_cell=%s" % str(selected_cell))
	print("construction_expanded_probe_build_mode=%s" % str(game.player.is_build_mode_active()))
	print("construction_expanded_probe_placeables=%d" % placeables_root.get_child_count())
	print("construction_expanded_probe_cell_occupied=%s" % str(grid.is_cell_occupied(selected_cell)))
	print("construction_expanded_probe_salvage_before=%d" % starting_salvage)
	print("construction_expanded_probe_salvage_after=%d" % int(game.player.resources.get("salvage", 0)))
	print("construction_expanded_probe_placeable_id=%s" % str(placed_placeable.get_placeable_id() if placed_placeable != null else StringName()))
	print("construction_expanded_probe_placeable_hp=%d" % int(placed_placeable.current_hp if placed_placeable != null else 0))
	quit()
