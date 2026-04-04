extends SceneTree


func _wait_frames(count: int = 1) -> void:
	for _i in count:
		await process_frame
		await physics_frame


func _spawn_enemy(root_node: Node, definition_path: String, position: Vector2):
	var enemy_scene := load("res://scenes/enemies/Enemy.tscn")
	var enemy = enemy_scene.instantiate()
	enemy.definition = load(definition_path)
	root_node.add_child(enemy)
	enemy.global_position = position
	return enemy


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	await _wait_frames(2)

	var player = game.player
	player.global_position = Vector2(1800.0, 1200.0)

	var brute = _spawn_enemy(game.exploration_enemy_layer, "res://data/enemies/zombie_brute.tres", player.global_position + Vector2(120.0, 0.0))
	var elite_brute = _spawn_enemy(game.exploration_enemy_layer, "res://data/enemies/zombie_elite_brute.tres", player.global_position + Vector2(120.0, 160.0))

	for enemy in [brute, elite_brute]:
		enemy.configure_runtime_context(player, game.exploration_enemy_layer, game.construction_placeables)
		enemy.configure_exploration_context(player, Vector2.LEFT, true, enemy.global_position, true)

	await _wait_frames(2)
	player.global_position = elite_brute.global_position + Vector2(-96.0, 0.0)
	await _wait_frames(3)

	print("elite_detection_probe_brute_engaged=%s" % str(brute.is_engaged_with_player()))
	print("elite_detection_probe_elite_brute_engaged=%s" % str(elite_brute.is_engaged_with_player()))
	print("elite_detection_probe_brute_detection_radius=%.1f" % float(brute.targeting_controller.get_player_detection_radius()))
	print("elite_detection_probe_elite_brute_detection_radius=%.1f" % float(elite_brute.targeting_controller.get_player_detection_radius()))

	game.queue_free()
	await _wait_frames(2)
	quit()
