extends SceneTree


func _wait_frames(count: int = 1) -> void:
	for _i in range(count):
		await process_frame
		await physics_frame


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	await _wait_frames(4)

	var player = game.player
	var camera = game.player_camera
	player.global_position = Vector2(-1268.0, 720.0)
	await _wait_frames(20)

	var camera_center: Vector2 = camera.get_screen_center_position()
	print("camera_bounds_probe_limit_left=%d" % int(camera.limit_left))
	print("camera_bounds_probe_camera_center_x=%.1f" % camera_center.x)
	print("camera_bounds_probe_clamped=%s" % str(camera_center.x >= float(camera.limit_left)))
	quit()
