extends SceneTree


func _wait_frames(count: int = 1) -> void:
	for _i in range(count):
		await process_frame
		await physics_frame


func _press_move_left(active: bool) -> void:
	if active:
		Input.action_press("move_left")
	else:
		Input.action_release("move_left")


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	await _wait_frames(2)

	var player = game.player
	player.global_position = Vector2(-1268.0, 720.0)
	await _wait_frames(1)
	var before_x: float = player.global_position.x
	_press_move_left(true)
	await _wait_frames(18)
	_press_move_left(false)
	await _wait_frames(2)
	var after_x: float = player.global_position.x

	print("map_bounds_probe_before_x=%.1f" % before_x)
	print("map_bounds_probe_after_x=%.1f" % after_x)
	print("map_bounds_probe_blocked=%s" % str(after_x >= -1268.0))
	quit()
