extends SceneTree


func _wait_frames() -> void:
	await process_frame
	await physics_frame
	await process_frame


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var enemy_scene := load("res://scenes/enemies/Enemy.tscn")
	var brute_definition := load("res://data/enemies/zombie_brute.tres")

	var game = game_scene.instantiate()
	root.add_child(game)
	await _wait_frames()

	var player = game.player
	var enemy = enemy_scene.instantiate()
	game.exploration_enemy_layer.add_child(enemy)
	enemy.definition = brute_definition
	enemy.global_position = player.global_position + Vector2(64.0, 0.0)
	enemy.configure_runtime_context(player, game.exploration_enemy_layer, game.construction_placeables)
	enemy.configure_exploration_context(player, Vector2.LEFT, true, enemy.global_position, true)
	await _wait_frames()

	enemy.receive_noise_alert(player, player.global_position)
	player.global_position = enemy.global_position + Vector2(40.0, 0.0)
	await _wait_frames()

	var viewport_rect: Rect2 = game.get_viewport().get_visible_rect()
	var canvas_to_world: Transform2D = game.get_viewport().get_canvas_transform().affine_inverse()
	var screen_world_top_left: Vector2 = canvas_to_world * viewport_rect.position
	var screen_world_bottom_right: Vector2 = canvas_to_world * viewport_rect.end
	var visible_world_size: Vector2 = (screen_world_bottom_right - screen_world_top_left).abs()
	var still_on_screen_far_offset := minf(visible_world_size.x * 0.35, enemy._get_player_screen_detect_keep_radius() + 48.0)
	player.global_position = enemy.global_position + Vector2(still_on_screen_far_offset, 0.0)
	await _wait_frames()
	var chase_rect := Rect2(
		player.global_position - visible_world_size * 0.5,
		visible_world_size
	)
	print("enemy_screen_chase_cap_probe_enemy_on_screen=%s" % str(chase_rect.has_point(enemy.global_position)))
	print("enemy_screen_chase_cap_probe_distance=%.1f" % float(enemy.global_position.distance_to(player.global_position)))
	print("enemy_screen_chase_cap_probe_screen_keep_radius=%.1f" % float(enemy._get_player_screen_detect_keep_radius()))
	print("enemy_screen_chase_cap_probe_brute_engaged=%s" % str(enemy.is_engaged_with_player()))

	game.queue_free()
	await _wait_frames()
	quit()
