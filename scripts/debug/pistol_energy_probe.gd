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

	var energy_before: int = int(player.current_energy)
	player._attempt_attack()
	await create_timer(0.14).timeout
	print("pistol_energy_probe_before=%d" % energy_before)
	print("pistol_energy_probe_after=%d" % player.current_energy)
	print("pistol_energy_probe_cost=%d" % pistol.energy_cost)
	quit()
