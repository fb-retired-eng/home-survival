extends SceneTree


func _wait_frames(count: int = 1) -> void:
	for _i in count:
		await process_frame
		await physics_frame


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var enemy_scene := load("res://scenes/enemies/Enemy.tscn")
	var brute_definition := load("res://data/enemies/zombie_brute.tres")

	var game = game_scene.instantiate()
	root.add_child(game)
	await _wait_frames(2)

	var player = game.player
	player.global_position = Vector2(1800.0, 1200.0)

	var enemy = enemy_scene.instantiate()
	enemy.definition = brute_definition
	game.exploration_enemy_layer.add_child(enemy)
	enemy.global_position = player.global_position + Vector2(140.0, 0.0)
	enemy.configure_runtime_context(player, game.exploration_enemy_layer, game.construction_placeables)
	enemy.configure_exploration_context(player, Vector2.LEFT, true, enemy.global_position, true)
	await _wait_frames(4)

	print("brute_initial_detection_probe_idle_target=%s" % str(enemy._get_current_target() == null))
	print("brute_initial_detection_probe_engaged=%s" % str(enemy.is_engaged_with_player()))
	print("brute_initial_detection_probe_alerted=%s" % str(enemy._is_alerted_to_player))

	player.global_position = enemy.global_position + Vector2(-56.0, 0.0)
	await _wait_frames(3)
	print("brute_initial_detection_probe_detected_engaged=%s" % str(enemy.is_engaged_with_player()))
	print("brute_initial_detection_probe_detected_alerted=%s" % str(enemy._is_alerted_to_player))

	game.queue_free()
	await _wait_frames(2)
	quit()
