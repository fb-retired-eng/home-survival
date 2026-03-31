extends SceneTree


func _init() -> void:
	var player_scene := load("res://scenes/player/Player.tscn")
	var pistol := load("res://data/weapons/pistol.tres")
	var bat := load("res://data/weapons/baseball_bat.tres")

	var player = player_scene.instantiate()
	root.add_child(player)
	await process_frame

	player.obtain_weapon(pistol, true, false)
	player.obtain_weapon(bat, false, false)
	player.facing_direction = Vector2.RIGHT
	player._update_facing_visuals()
	player._set_weapon_magazine_ammo(pistol, 1)
	await physics_frame
	await process_frame

	player._attempt_attack()
	await create_timer(0.14).timeout
	print("pistol_reload_switch_probe_during_reload=%s" % player.get_weapon_status_text())
	player._attempt_switch_weapon()
	await physics_frame
	await process_frame
	print("pistol_reload_switch_probe_after_switch=%s" % player.get_weapon_status_text())
	quit()
