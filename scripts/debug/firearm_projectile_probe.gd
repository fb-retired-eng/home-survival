extends SceneTree


func _wait_frames(count: int = 1) -> void:
	for _i in range(count):
		await process_frame
		await physics_frame


func _init() -> void:
	var player_scene := load("res://scenes/player/Player.tscn")
	var enemy_scene := load("res://scenes/enemies/Enemy.tscn")
	var pistol := load("res://data/weapons/pistol.tres")
	var player = player_scene.instantiate()
	var enemy = enemy_scene.instantiate()
	root.add_child(player)
	root.add_child(enemy)
	await _wait_frames(1)

	player.global_position = Vector2(200.0, 200.0)
	player.facing_direction = Vector2.RIGHT
	player._update_facing_visuals()
	player.obtain_weapon(pistol, true, false)
	enemy.global_position = Vector2(392.0, 200.0)
	await _wait_frames(2)

	var before_health: int = int(enemy.current_health)
	player._attempt_attack()
	await create_timer(0.16).timeout
	await _wait_frames(1)
	var projectiles: Array = get_nodes_in_group("player_projectiles")
	var projectile = projectiles[0] if not projectiles.is_empty() else null
	var projectile_visible: bool = projectile != null and projectile.visual.visible
	var projectile_count: int = projectiles.size()
	await create_timer(0.2).timeout

	print("firearm_projectile_probe_spawned=%s" % str(projectile_count > 0))
	print("firearm_projectile_probe_count=%d" % projectile_count)
	print("firearm_projectile_probe_visible=%s" % str(projectile_visible))
	print("firearm_projectile_probe_before=%d" % before_health)
	print("firearm_projectile_probe_after=%d" % int(enemy.current_health))
	print("firearm_projectile_probe_damaged=%s" % str(int(enemy.current_health) < before_health))
	quit()
