extends SceneTree


func _init() -> void:
	var hud_scene := load("res://scenes/ui/HUD.tscn")
	var player_scene := load("res://scenes/player/Player.tscn")
	var bat := load("res://data/weapons/baseball_bat.tres")
	var pistol := load("res://data/weapons/pistol.tres")

	var hud = hud_scene.instantiate()
	var player = player_scene.instantiate()
	root.add_child(hud)
	root.add_child(player)
	await process_frame

	hud.bind_player(player)
	await process_frame
	print("initial_weapon_label=%s" % hud.get_node("MainPanel/MarginContainer/VBoxContainer/MetaRow/WeaponLabel").text)
	print("initial_weapon_trait=%s" % hud.get_node("MainPanel/MarginContainer/VBoxContainer/WeaponTraitLabel").text)

	player.obtain_weapon(bat, true, false)
	await process_frame
	print("after_bat_weapon_label=%s" % hud.get_node("MainPanel/MarginContainer/VBoxContainer/MetaRow/WeaponLabel").text)
	print("after_bat_weapon_trait=%s" % hud.get_node("MainPanel/MarginContainer/VBoxContainer/WeaponTraitLabel").text)

	player.obtain_weapon(pistol, true, false)
	await process_frame
	player.add_resource("bullets", 6, false)
	await process_frame
	print("after_pistol_ammo_label=%s" % hud.get_node("MainPanel/MarginContainer/VBoxContainer/MetaRow/WeaponLabel").text)
	player.facing_direction = Vector2.RIGHT
	player._update_facing_visuals()
	player._attempt_attack()
	await process_frame
	print("during_pistol_windup_label=%s" % hud.get_node("MainPanel/MarginContainer/VBoxContainer/MetaRow/WeaponLabel").text)
	print("during_pistol_windup_color=%s" % str(hud.get_node("MainPanel/MarginContainer/VBoxContainer/MetaRow/WeaponLabel").get_theme_color("font_color")))
	await create_timer(0.18).timeout
	print("after_pistol_fire_label=%s" % hud.get_node("MainPanel/MarginContainer/VBoxContainer/MetaRow/WeaponLabel").text)
	quit()
