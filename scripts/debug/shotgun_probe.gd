extends SceneTree


func _get_enemy_health_or_zero(enemy) -> int:
	if enemy == null or not is_instance_valid(enemy):
		return 0
	return int(enemy.current_health)


func _init() -> void:
	var player_scene := load("res://scenes/player/Player.tscn")
	var zombie_scene := load("res://scenes/enemies/Zombie.tscn")
	var shotgun := load("res://data/weapons/shotgun.tres")

	var player = player_scene.instantiate()
	var zombie_a = zombie_scene.instantiate()
	var zombie_b = zombie_scene.instantiate()
	var zombie_c = zombie_scene.instantiate()
	root.add_child(player)
	root.add_child(zombie_a)
	root.add_child(zombie_b)
	root.add_child(zombie_c)
	await process_frame

	player.global_position = Vector2(200, 200)
	player.facing_direction = Vector2.RIGHT
	player._update_facing_visuals()
	player.obtain_weapon(shotgun, true, false)
	player.add_resource("bullets", 4, false)
	zombie_a.global_position = Vector2(300, 190)
	zombie_b.global_position = Vector2(308, 222)
	zombie_c.global_position = Vector2(330, 276)
	await physics_frame
	await process_frame

	var health_a_before: int = int(zombie_a.current_health)
	var health_b_before: int = int(zombie_b.current_health)
	var health_c_before: int = int(zombie_c.current_health)
	print("shotgun_probe_target_count=%d" % player._get_attack_targets_for_weapon(shotgun).size())
	player._attempt_attack()
	await create_timer(0.28).timeout
	print("shotgun_probe_health_a_before=%d" % health_a_before)
	print("shotgun_probe_health_a_after=%d" % _get_enemy_health_or_zero(zombie_a))
	print("shotgun_probe_health_b_before=%d" % health_b_before)
	print("shotgun_probe_health_b_after=%d" % _get_enemy_health_or_zero(zombie_b))
	print("shotgun_probe_health_c_before=%d" % health_c_before)
	print("shotgun_probe_health_c_after=%d" % _get_enemy_health_or_zero(zombie_c))
	print("shotgun_probe_status=%s" % player.get_weapon_status_text())
	quit()
