extends SceneTree


func _wait_frames(frame_count: int = 1) -> void:
	for _index in range(frame_count):
		await process_frame
		await physics_frame
		await process_frame


func _press_action(action_name: StringName) -> void:
	Input.action_press(action_name)
	await physics_frame
	await process_frame
	Input.action_release(action_name)
	await process_frame


func _place_barricade(game, tactical_cell: Vector2i):
	var grid = game.construction_grid
	var player = game.player
	player.global_position = grid.to_global(Vector2(tactical_cell.x * grid.cell_size.x, tactical_cell.y * grid.cell_size.y))
	await _wait_frames(2)
	if not player.is_build_mode_active():
		await _press_action("build_mode")
	await _wait_frames(2)
	await _press_action("interact")
	await _wait_frames(2)
	return game.construction_placeables.get_child(game.construction_placeables.get_child_count() - 1) if game.construction_placeables.get_child_count() > 0 else null


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	game.enable_test_mode = true
	root.add_child(game)
	await _wait_frames(3)

	var first: Variant = await _place_barricade(game, Vector2i(-2, 3))
	print("barricade_pinch_probe_first=%s" % str(first != null))
	print("barricade_pinch_probe_status_after_first=%s" % str(game.hud.status_label.text))

	if first == null:
		quit()
		return

	var grid = game.construction_grid
	var player = game.player
	player.global_position = grid.to_global(Vector2(-2.0 * grid.cell_size.x, 4.0 * grid.cell_size.y))
	await _wait_frames(2)
	var before_second_count: int = game.construction_placeables.get_child_count()
	await _press_action("interact")
	await _wait_frames(2)

	print("barricade_pinch_probe_second_placed=%s" % str(game.construction_placeables.get_child_count() > before_second_count))
	print("barricade_pinch_probe_placeables=%d" % game.construction_placeables.get_child_count())
	print("barricade_pinch_probe_preview_cell=%s" % str(grid.get_preview_cell()))
	print("barricade_pinch_probe_preview_reason=%s" % str(grid.get_preview_reason()))
	print("barricade_pinch_probe_status=%s" % str(game.hud.status_label.text))
	quit()
