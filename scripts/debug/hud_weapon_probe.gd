extends SceneTree


func _init() -> void:
	var hud_scene := load("res://scenes/ui/HUD.tscn")
	var player_scene := load("res://scenes/player/Player.tscn")
	var bat := load("res://data/weapons/baseball_bat.tres")

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
	quit()
