extends SceneTree


func _count_roaming_enemies(layer: Node) -> int:
	var count := 0
	for child in layer.get_children():
		if not is_instance_valid(child):
			continue
		if String(child.get_meta("spawn_kind", "")) == "roaming":
			count += 1
	return count


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	print("roaming_spawn_probe_final_wave=%d" % game.game_manager.final_wave)
	print("roaming_spawn_probe_initial_roaming=%d" % _count_roaming_enemies(game.exploration_enemy_layer))

	game.game_manager.current_wave = 4
	game._spawn_roaming_exploration_enemies()
	await process_frame
	print("roaming_spawn_probe_mid_roaming=%d" % _count_roaming_enemies(game.exploration_enemy_layer))

	game.game_manager.current_wave = 7
	game._spawn_roaming_exploration_enemies()
	await process_frame
	print("roaming_spawn_probe_late_roaming=%d" % _count_roaming_enemies(game.exploration_enemy_layer))
	quit()
