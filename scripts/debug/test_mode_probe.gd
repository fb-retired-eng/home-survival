extends SceneTree


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	game.enable_test_mode = true
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	print("test_mode_probe_initial_weapon=%s" % game.player.get_equipped_weapon_display_name())
	print("test_mode_probe_initial_loadout=%s" % ",".join(game.player.get_obtained_weapon_ids()))

	game.game_manager.reset_run()
	await process_frame
	await physics_frame
	await process_frame

	print("test_mode_probe_after_reset_weapon=%s" % game.player.get_equipped_weapon_display_name())
	print("test_mode_probe_after_reset_loadout=%s" % ",".join(game.player.get_obtained_weapon_ids()))
	quit()
