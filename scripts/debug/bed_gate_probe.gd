extends SceneTree


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	game.player.current_energy = 60
	game.player.energy_changed.emit(game.player.current_energy, game.player.max_energy)
	game.player.add_resource("food", 2, false)
	await process_frame

	print("bed_gate_probe_sleep_label_before=%s" % game._get_sleep_label(game.player))
	print("bed_gate_probe_can_sleep_before=%s" % str(game._can_player_sleep(game.player)))

	game.player.add_resource("food", 1, false)
	game._on_food_table_requested(game.player)
	await process_frame

	print("bed_gate_probe_sleep_label_after=%s" % game._get_sleep_label(game.player))
	print("bed_gate_probe_can_sleep_after=%s" % str(game._can_player_sleep(game.player)))
	quit()
