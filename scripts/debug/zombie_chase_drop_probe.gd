extends SceneTree


func _wait_frames() -> void:
	await process_frame
	await physics_frame
	await process_frame


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var zombie_scene := load("res://scenes/enemies/Zombie.tscn")

	var game = game_scene.instantiate()
	root.add_child(game)
	await _wait_frames()

	var player = game.player
	var zombie = zombie_scene.instantiate()
	game.exploration_enemy_layer.add_child(zombie)
	zombie.global_position = player.global_position + Vector2(64.0, 0.0)
	zombie.configure_runtime_context(player, game.exploration_enemy_layer, game.construction_placeables)
	zombie.configure_exploration_context(player, Vector2.LEFT, true, zombie.global_position, true)
	await _wait_frames()

	zombie.receive_noise_alert(player, player.global_position)
	await _wait_frames()
	print("zombie_chase_drop_probe_initial_investigating=%s" % str(zombie.is_investigating_noise()))

	player.global_position = zombie.global_position + Vector2(44.0, 0.0)
	await _wait_frames()
	print("zombie_chase_drop_probe_alerted=%s" % str(zombie.is_engaged_with_player()))

	player.global_position = zombie.global_position + Vector2(220.0, 0.0)
	await _wait_frames()
	print("zombie_chase_drop_probe_far_engaged=%s" % str(zombie.is_engaged_with_player()))
	print("zombie_chase_drop_probe_far_alerted=%s" % str(zombie._is_alerted_to_player))
	print("zombie_chase_drop_probe_break_radius=%.1f" % float(zombie._get_player_lost_sight_break_radius()))

	game.queue_free()
	await _wait_frames()
	quit()
