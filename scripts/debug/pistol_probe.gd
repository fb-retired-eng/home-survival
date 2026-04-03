extends SceneTree


func _init() -> void:
	var player_scene := load("res://scenes/player/Player.tscn")
	var enemy_scene := load("res://scenes/enemies/Enemy.tscn")
	var pistol := load("res://data/weapons/pistol.tres")

	var player = player_scene.instantiate()
	var zombie = enemy_scene.instantiate()
	root.add_child(player)
	root.add_child(zombie)
	await process_frame

	player.global_position = Vector2(200, 200)
	player.facing_direction = Vector2.RIGHT
	player._update_facing_visuals()
	player.obtain_weapon(pistol, true, false)
	zombie.global_position = Vector2(320, 200)
	await physics_frame
	await process_frame

	var health_before: int = int(zombie.current_health)
	print("pistol_probe_target_count=%d" % player._get_attack_targets_for_weapon(pistol).size())
	player._attempt_attack()
	await create_timer(0.16).timeout
	await physics_frame
	var projectiles: Array = get_nodes_in_group("player_projectiles")
	var projectile = projectiles[0] if not projectiles.is_empty() else null
	print("pistol_probe_projectile_spawned=%s" % str(not projectiles.is_empty()))
	print("pistol_probe_projectile_visible=%s" % str(projectile != null and projectile.visual.visible))
	await create_timer(0.12).timeout
	print("pistol_probe_health_before=%d" % health_before)
	print("pistol_probe_health_after=%d" % zombie.current_health)
	print("pistol_probe_weapon=%s" % player.get_equipped_weapon_display_name())
	quit()
