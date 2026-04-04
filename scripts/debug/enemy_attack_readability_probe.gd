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


func _arm_visual_prep(enemy, prep_fraction: float) -> void:
	enemy.set_physics_process(false)
	enemy._attack_prep_armed = true
	enemy._attack_prep_remaining = enemy.combat_controller.get_attack_prep_time() * prep_fraction
	enemy.combat_controller.update_attack_prep_visual()


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	await _wait_frames(2)

	var player = game.player
	player.global_position = Vector2(1800.0, 1200.0)

	var basic = _spawn_enemy(game.exploration_enemy_layer, "res://data/enemies/zombie_basic.tres", player.global_position + Vector2(60.0, 0.0))
	var runner = _spawn_enemy(game.exploration_enemy_layer, "res://data/enemies/zombie_runner.tres", player.global_position + Vector2(120.0, 0.0))
	var spitter = _spawn_enemy(game.exploration_enemy_layer, "res://data/enemies/zombie_spitter.tres", player.global_position + Vector2(180.0, 0.0))
	var brute = _spawn_enemy(game.exploration_enemy_layer, "res://data/enemies/zombie_brute.tres", player.global_position + Vector2(240.0, 0.0))

	for enemy in [basic, runner, spitter, brute]:
		enemy.configure_runtime_context(player, game.exploration_enemy_layer, game.construction_placeables)
		enemy.configure_exploration_context(player, Vector2.LEFT, true, enemy.global_position, true)
		enemy._update_facing_direction(player.global_position - enemy.global_position)

	_arm_visual_prep(basic, 0.15)
	_arm_visual_prep(runner, 0.15)
	_arm_visual_prep(spitter, 0.15)
	_arm_visual_prep(brute, 0.15)
	await _wait_frames(2)

	var basic_tell: Polygon2D = basic.get_node("VisualRoot/AttackTell")
	var runner_tell: Polygon2D = runner.get_node("VisualRoot/AttackTell")
	var spitter_tell: Polygon2D = spitter.get_node("VisualRoot/AttackTell")
	var brute_tell: Polygon2D = brute.get_node("VisualRoot/AttackTell")

	print("enemy_attack_readability_probe_basic_tell_visible=%s" % str(basic_tell.visible))
	print("enemy_attack_readability_probe_runner_tell_faster=%s" % str(
		runner.presentation_controller.get_attack_tell_pulse_speed() > basic.presentation_controller.get_attack_tell_pulse_speed()
	))
	print("enemy_attack_readability_probe_spitter_tell_offset_higher=%s" % str(spitter.attack_tell.position.y < basic.attack_tell.position.y))
	print("enemy_attack_readability_probe_brute_tell_larger=%s" % str(brute_tell.scale.x > basic_tell.scale.x))
	print("enemy_attack_readability_probe_runner_tell_narrower=%s" % str(runner_tell.polygon[0].x > basic_tell.polygon[0].x))
	print("enemy_attack_readability_probe_spitter_flash_larger=%s" % str(spitter.get_node("VisualRoot/AttackFlash").polygon[0].x < basic.get_node("VisualRoot/AttackFlash").polygon[0].x))

	game.queue_free()
	await _wait_frames(2)
	quit()
