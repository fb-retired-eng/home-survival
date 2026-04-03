extends SceneTree


func _wait_frames() -> void:
	await process_frame
	await physics_frame
	await process_frame


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var enemy_scene := load("res://scenes/enemies/Enemy.tscn")

	var game = game_scene.instantiate()
	root.add_child(game)
	await _wait_frames()

	var player = game.player
	var zombie = enemy_scene.instantiate()
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

	var viewport_rect: Rect2 = game.get_viewport().get_visible_rect()
	var canvas_to_world: Transform2D = game.get_viewport().get_canvas_transform().affine_inverse()
	var screen_world_top_left: Vector2 = canvas_to_world * viewport_rect.position
	var screen_world_bottom_right: Vector2 = canvas_to_world * viewport_rect.end
	var visible_world_size: Vector2 = (screen_world_bottom_right - screen_world_top_left).abs()
	var on_screen_offset_x := visible_world_size.x * 0.35
	player.global_position += Vector2(on_screen_offset_x, 0.0)
	await _wait_frames()
	var chase_rect := Rect2(
		player.global_position - visible_world_size * 0.5,
		visible_world_size
	)
	print("zombie_chase_drop_probe_on_screen_engaged=%s" % str(zombie.is_engaged_with_player()))
	print("zombie_chase_drop_probe_on_screen_alerted=%s" % str(zombie._is_alerted_to_player))
	print("zombie_chase_drop_probe_enemy_still_on_screen=%s" % str(chase_rect.has_point(zombie.global_position)))

	player.global_position += Vector2(visible_world_size.x * 0.8, 0.0)
	await _wait_frames()
	chase_rect = Rect2(
		player.global_position - visible_world_size * 0.5,
		visible_world_size
	)
	print("zombie_chase_drop_probe_far_engaged=%s" % str(zombie.is_engaged_with_player()))
	print("zombie_chase_drop_probe_far_alerted=%s" % str(zombie._is_alerted_to_player))
	print("zombie_chase_drop_probe_enemy_off_screen=%s" % str(not chase_rect.has_point(zombie.global_position)))
	print("zombie_chase_drop_probe_break_radius=%.1f" % float(zombie._get_player_lost_sight_break_radius()))

	game.queue_free()
	await _wait_frames()
	quit()
