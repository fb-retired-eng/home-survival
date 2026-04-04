extends SceneTree


func _wait_frames(count: int = 1) -> void:
	for _i in count:
		await process_frame
		await physics_frame


func _spawn_enemy(root: Node, definition_path: String, position: Vector2):
	var enemy_scene := load("res://scenes/enemies/Enemy.tscn")
	var enemy = enemy_scene.instantiate()
	enemy.definition = load(definition_path)
	root.add_child(enemy)
	enemy.global_position = position
	return enemy


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	await _wait_frames(2)

	var player = game.player
	player.global_position = Vector2(1800.0, 1200.0)
	await _wait_frames(1)
	var basic = _spawn_enemy(game.exploration_enemy_layer, "res://data/enemies/zombie_basic.tres", player.global_position + Vector2(80.0, 0.0))
	var runner = _spawn_enemy(game.exploration_enemy_layer, "res://data/enemies/zombie_runner.tres", player.global_position + Vector2(120.0, 0.0))
	var spitter = _spawn_enemy(game.exploration_enemy_layer, "res://data/enemies/zombie_spitter.tres", player.global_position + Vector2(160.0, 0.0))
	var brute = _spawn_enemy(game.exploration_enemy_layer, "res://data/enemies/zombie_brute.tres", player.global_position + Vector2(200.0, 0.0))
	for enemy in [basic, runner, spitter, brute]:
		enemy.configure_runtime_context(player, game.exploration_enemy_layer, game.construction_placeables)
		enemy.configure_exploration_context(player)

	await _wait_frames(2)
	print("enemy_archetype_probe_runner_scale_smaller=%s" % str(runner.get_node("VisualRoot").scale.x < basic.get_node("VisualRoot").scale.x))
	print("enemy_archetype_probe_brute_scale_larger=%s" % str(brute.get_node("VisualRoot").scale.x > basic.get_node("VisualRoot").scale.x))
	print("enemy_archetype_probe_runner_body_narrower=%s" % str(runner.get_node("VisualRoot/Body").polygon[0].x > basic.get_node("VisualRoot/Body").polygon[0].x))
	print("enemy_archetype_probe_brute_body_wider=%s" % str(brute.get_node("VisualRoot/Body").polygon[0].x < basic.get_node("VisualRoot/Body").polygon[0].x))
	print("enemy_archetype_probe_spitter_flash_larger=%s" % str(spitter.get_node("VisualRoot/AttackFlash").polygon[0].x < basic.get_node("VisualRoot/AttackFlash").polygon[0].x))

	var original_runner_rotation: float = runner.get_node("VisualRoot/Body").rotation
	var original_brute_rotation: float = brute.get_node("VisualRoot/Body").rotation
	runner._update_facing_direction(Vector2.LEFT)
	brute._update_facing_direction(Vector2.LEFT)
	await _wait_frames(1)
	var runner_turn_delta: float = absf(wrapf(runner.get_node("VisualRoot/Body").rotation - original_runner_rotation, -PI, PI))
	var brute_turn_delta: float = absf(wrapf(brute.get_node("VisualRoot/Body").rotation - original_brute_rotation, -PI, PI))
	print("enemy_archetype_probe_runner_turns_faster=%s" % str(runner_turn_delta > brute_turn_delta))
	print("enemy_archetype_probe_spitter_profile_taller_prep=%s" % str(spitter.definition.prep_pose_scale.y > 1.0))

	spitter.global_position = player.global_position + Vector2(92.0, 0.0)
	brute.global_position = player.global_position + Vector2(28.0, 0.0)
	await _wait_frames(1)
	brute._update_facing_direction(player.global_position - brute.global_position)
	brute.set_physics_process(false)
	brute._attack_prep_armed = true
	brute._attack_prep_remaining = brute.combat_controller.get_attack_prep_time() * 0.45
	var brute_prep_scale_x := 0.0
	for _i in 20:
		await _wait_frames(1)
		brute_prep_scale_x = brute.get_node("VisualRoot").scale.x
	print("enemy_archetype_probe_brute_prep_heavier=%s" % str(brute_prep_scale_x > basic.get_node("VisualRoot").scale.x * 1.05))

	basic.take_damage(4, {"attacker": player})
	runner.take_damage(4, {"attacker": player})
	brute.take_damage(4, {"attacker": player})
	await _wait_frames(1)
	print("enemy_archetype_probe_runner_hit_reacts_more=%s" % str(runner.get_node("VisualRoot/Body").position.length() > brute.get_node("VisualRoot/Body").position.length()))

	game.queue_free()
	await _wait_frames(2)
	quit()
