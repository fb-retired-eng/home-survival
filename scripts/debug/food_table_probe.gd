extends SceneTree


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	game.player.current_energy = 55
	game.player.energy_changed.emit(game.player.current_energy, game.player.max_energy)
	game.player.add_resource("food", 3, false)
	await process_frame

	print("food_table_probe_before_energy=%d" % game.player.current_energy)
	print("food_table_probe_before_food=%d" % int(game.player.resources.get("food", 0)))
	print("food_table_probe_label=%s" % game._get_food_table_label(game.player))

	game._on_food_table_requested(game.player)
	await process_frame

	print("food_table_probe_after_energy=%d" % game.player.current_energy)
	print("food_table_probe_after_food=%d" % int(game.player.resources.get("food", 0)))
	quit()
