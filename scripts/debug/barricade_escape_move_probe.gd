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

	var first = await _place_barricade(game, Vector2i(-2, 3))
	if first == null:
		print("barricade_escape_move_probe_first=false")
		quit()
		return
	print("barricade_escape_move_probe_after_first_cell=%s" % str(game.construction_grid.get_cell_for_world_position(game.player.global_position)))

	var second = await _place_barricade(game, Vector2i(-2, 4))
	print("barricade_escape_move_probe_second=%s" % str(second != null))

	var start_position: Vector2 = game.player.global_position
	await _press_action("move_right")
	await _wait_frames(4)
	var moved_right: bool = game.player.global_position.distance_to(start_position) > 1.0

	start_position = game.player.global_position
	await _press_action("move_left")
	await _wait_frames(4)
	var moved_left: bool = game.player.global_position.distance_to(start_position) > 1.0

	start_position = game.player.global_position
	await _press_action("move_up")
	await _wait_frames(4)
	var moved_up: bool = game.player.global_position.distance_to(start_position) > 1.0

	start_position = game.player.global_position
	await _press_action("move_down")
	await _wait_frames(4)
	var moved_down: bool = game.player.global_position.distance_to(start_position) > 1.0

	print("barricade_escape_move_probe_player_cell=%s" % str(game.construction_grid.get_cell_for_world_position(game.player.global_position)))
	print("barricade_escape_move_probe_moved_right=%s" % str(moved_right))
	print("barricade_escape_move_probe_moved_left=%s" % str(moved_left))
	print("barricade_escape_move_probe_moved_up=%s" % str(moved_up))
	print("barricade_escape_move_probe_moved_down=%s" % str(moved_down))
	quit()
