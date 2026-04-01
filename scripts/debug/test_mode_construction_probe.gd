extends SceneTree


func _wait_frames() -> void:
	await process_frame
	await physics_frame
	await process_frame


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	game.enable_test_mode = true
	root.add_child(game)
	await _wait_frames()

	print("test_mode_construction_probe_salvage=%d" % int(game.player.resources.get("salvage", 0)))
	print("test_mode_construction_probe_parts=%d" % int(game.player.resources.get("parts", 0)))
	print("test_mode_construction_probe_bullets=%d" % int(game.player.resources.get("bullets", 0)))
	print("test_mode_construction_probe_food=%d" % int(game.player.resources.get("food", 0)))

	game.game_manager.reset_run()
	await _wait_frames()

	print("test_mode_construction_probe_after_reset_salvage=%d" % int(game.player.resources.get("salvage", 0)))
	print("test_mode_construction_probe_after_reset_parts=%d" % int(game.player.resources.get("parts", 0)))
	quit()
