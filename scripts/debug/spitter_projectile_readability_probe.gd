extends SceneTree


func _wait_frames(count: int = 1) -> void:
	for _i in count:
		await process_frame
		await physics_frame


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var enemy_scene := load("res://scenes/enemies/Enemy.tscn")
	var spitter_definition := load("res://data/enemies/zombie_spitter.tres")
	var game = game_scene.instantiate()
	root.add_child(game)
	await _wait_frames(2)

	var player = game.player
	player.global_position = Vector2(1600.0, 900.0)
	var player_health_before: int = player.current_health
	var enemy = enemy_scene.instantiate()
	game.exploration_enemy_layer.add_child(enemy)
	enemy.definition = spitter_definition
	enemy.global_position = player.global_position + Vector2(-128.0, 0.0)
	enemy.configure_runtime_context(player, game.exploration_enemy_layer, game.construction_placeables)
	enemy.configure_exploration_context(player, Vector2.RIGHT, true, enemy.global_position, true)
	enemy._update_facing_direction(player.global_position - enemy.global_position)
	await _wait_frames(2)

	var spawned: bool = enemy._spawn_attack_projectile(player)
	await _wait_frames(1)

	var projectiles: Array = get_nodes_in_group("enemy_projectiles")
	var projectile = projectiles[0] if not projectiles.is_empty() else null
	var projectile_visible: bool = projectile != null and projectile.visual.visible
	var projectile_color: Color = projectile.visual.color if projectile != null else Color.BLACK
	var projectile_impacting: bool = projectile != null and projectile._is_impacting
	var projectile_position: Vector2 = projectile.global_position if projectile != null else Vector2.ZERO
	await _wait_frames(30)
	var player_health_after: int = player.current_health

	print("spitter_projectile_probe_spawned=%s" % str(spawned))
	print("spitter_projectile_probe_projectile_count=%d" % projectiles.size())
	print("spitter_projectile_probe_projectile_visible=%s" % str(projectile_visible))
	print("spitter_projectile_probe_projectile_impacting=%s" % str(projectile_impacting))
	print("spitter_projectile_probe_projectile_position=%s" % str(projectile_position))
	print("spitter_projectile_probe_projectile_red=%s" % str(projectile_color.r > projectile_color.g))
	print("spitter_projectile_probe_player_health_before=%d" % player_health_before)
	print("spitter_projectile_probe_player_health_after=%d" % player_health_after)
	print("spitter_projectile_probe_player_damaged=%s" % str(player_health_after < player_health_before))

	game.queue_free()
	await _wait_frames(2)
	quit()
