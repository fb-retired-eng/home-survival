extends SceneTree


func _init() -> void:
	var player_scene := load("res://scenes/player/Player.tscn")
	var pistol := load("res://data/weapons/pistol.tres")

	var player = player_scene.instantiate()
	root.add_child(player)
	await process_frame

	player.obtain_weapon(pistol, true, false)
	player._set_weapon_magazine_ammo(pistol, 0)
	await process_frame

	var energy_before: int = int(player.current_energy)
	player._attempt_attack()
	await create_timer(0.15).timeout

	print("pistol_no_bullets_probe_status=%s" % player.get_weapon_status_text())
	print("pistol_no_bullets_probe_energy_before=%d" % energy_before)
	print("pistol_no_bullets_probe_energy_after=%d" % player.current_energy)
	print("pistol_no_bullets_probe_tracer_visible=%s" % str(player.get_node("ShotTracer").visible))
	quit()
