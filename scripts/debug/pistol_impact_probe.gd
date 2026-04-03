extends SceneTree


func _init() -> void:
	var player_scene := load("res://scenes/player/Player.tscn")
	var enemy_scene := load("res://scenes/enemies/Enemy.tscn")
	var pistol := load("res://data/weapons/pistol.tres")

	var player = player_scene.instantiate()
	var zombie = enemy_scene.instantiate()
	var wall := StaticBody2D.new()
	var wall_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()

	rect.size = Vector2(22, 80)
	wall_shape.shape = rect
	wall.add_child(wall_shape)
	wall.collision_layer = 2
	wall.collision_mask = 0
	wall.add_to_group("defense_sockets")

	root.add_child(player)
	root.add_child(zombie)
	root.add_child(wall)
	await process_frame

	player.global_position = Vector2(200, 200)
	player.facing_direction = Vector2.RIGHT
	player._update_facing_visuals()
	player.obtain_weapon(pistol, true, false)
	zombie.global_position = Vector2(320, 200)
	await physics_frame
	await process_frame

	player._attempt_attack()
	await create_timer(0.11).timeout
	print("pistol_impact_probe_enemy_visible=%s" % str(player.get_node("ShotImpact").visible))
	print("pistol_impact_probe_enemy_color=%s" % str(player.get_node("ShotImpact").color))

	await create_timer(0.32).timeout
	zombie.global_position = Vector2(520, 200)
	wall.global_position = Vector2(300, 200)
	await physics_frame
	await process_frame

	player._attempt_attack()
	await create_timer(0.11).timeout
	print("pistol_impact_probe_structure_visible=%s" % str(player.get_node("ShotImpact").visible))
	print("pistol_impact_probe_structure_color=%s" % str(player.get_node("ShotImpact").color))
	quit()
