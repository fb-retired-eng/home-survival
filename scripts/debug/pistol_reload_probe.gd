extends SceneTree


func _init() -> void:
	var player_scene := load("res://scenes/player/Player.tscn")
	var pistol := load("res://data/weapons/pistol.tres")

	var player = player_scene.instantiate()
	root.add_child(player)
	await process_frame

	player.global_position = Vector2(200, 200)
	player.facing_direction = Vector2.RIGHT
	player._update_facing_visuals()
	player.obtain_weapon(pistol, true, false)
	player.add_resource("bullets", 5, false)
	player._set_weapon_magazine_ammo(pistol, 1)
	await physics_frame
	await process_frame

	print("pistol_reload_probe_initial_status=%s" % player.get_weapon_status_text())
	player._attempt_attack()
	await create_timer(0.14).timeout
	print("pistol_reload_probe_after_shot_status=%s" % player.get_weapon_status_text())
	player._attempt_attack()
	await physics_frame
	await process_frame
	print("pistol_reload_probe_after_reload_trigger=%s" % player.get_weapon_status_text())
	await create_timer(float(pistol.reload_time) + 0.2).timeout
	print("pistol_reload_probe_after_reload_complete=%s" % player.get_weapon_status_text())
	quit()
