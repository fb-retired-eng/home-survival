extends SceneTree


func _init() -> void:
	var player_scene := load("res://scenes/player/Player.tscn")
	var bat := load("res://data/weapons/baseball_bat.tres")
	var player = player_scene.instantiate()
	root.add_child(player)
	await process_frame

	var weapon_visual: Polygon2D = player.get_node("AttackPivot/WeaponVisual")
	print("initial_points=%d" % weapon_visual.polygon.size())
	print("initial_color=%s" % str(weapon_visual.color))
	print("initial_position=%s" % str(weapon_visual.position))

	player.obtain_weapon(bat, true, false)
	await process_frame

	print("after_bat_points=%d" % weapon_visual.polygon.size())
	print("after_bat_color=%s" % str(weapon_visual.color))
	print("after_bat_position=%s" % str(weapon_visual.position))
	quit()
