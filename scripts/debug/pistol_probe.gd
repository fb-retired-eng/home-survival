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
	await create_timer(0.13).timeout
	print("pistol_probe_tracer_visible=%s" % str(player.get_node("ShotTracer").visible))
	print("pistol_probe_tracer_points=%d" % player.get_node("ShotTracer").points.size())
	await create_timer(0.12).timeout
	print("pistol_probe_health_before=%d" % health_before)
	print("pistol_probe_health_after=%d" % zombie.current_health)
	print("pistol_probe_weapon=%s" % player.get_equipped_weapon_display_name())
	quit()
