extends SceneTree


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	game.hud.set_phase("Phase: Victory")
	game._is_resetting_run = true
	game.game_manager.reset_run()
	await process_frame

	print("reset_phase_probe_wave_label=%s" % game.hud.wave_label.text)
	quit()
