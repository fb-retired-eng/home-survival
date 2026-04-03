extends SceneTree


func _init() -> void:
	var player_scene := load("res://scenes/player/Player.tscn")
	var enemy_scene := load("res://scenes/enemies/Enemy.tscn")
	var pistol = load("res://data/weapons/pistol.tres").duplicate(true)

	var player = player_scene.instantiate()
	var zombie = enemy_scene.instantiate()
	root.add_child(player)
	root.add_child(zombie)
	await process_frame

	pistol.attack_windup = 0.2
	player.global_position = Vector2(200, 200)
	player.facing_direction = Vector2.RIGHT
	player._update_facing_visuals()
	player.obtain_weapon(pistol, true, false)
	zombie.global_position = Vector2(420, 200)
	await physics_frame
	await process_frame

	player._attempt_attack()
	await create_timer(0.08).timeout
	zombie.global_position = Vector2(320, 200)
	await physics_frame
	await process_frame
	await create_timer(0.13).timeout

	var tracer_end_local: Vector2 = Vector2.ZERO
	var tracer_point_count: int = int(player.get_node("ShotTracer").points.size())
	if tracer_point_count >= 2:
		tracer_end_local = player.get_node("ShotTracer").points[1]
	var tracer_end_global: Vector2 = player.to_global(tracer_end_local)
	var distance_to_enemy: float = tracer_end_global.distance_to(zombie.global_position)
	print("pistol_visual_only_probe_health=%d" % zombie.current_health)
	print("pistol_visual_only_probe_tracer_visible=%s" % str(player.get_node("ShotTracer").visible))
	print("pistol_visual_only_probe_tracer_points=%d" % tracer_point_count)
	print("pistol_visual_only_probe_tracer_enemy_distance=%.2f" % distance_to_enemy)
	quit()
