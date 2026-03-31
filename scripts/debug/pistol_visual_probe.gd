extends SceneTree


func _init() -> void:
	var player_scene := load("res://scenes/player/Player.tscn")
	var pistol := load("res://data/weapons/pistol.tres")
	var player = player_scene.instantiate()
	root.add_child(player)
	await process_frame

	player.obtain_weapon(pistol, true, false)
	await process_frame

	var weapon_visual: Polygon2D = player.get_node("AttackPivot/WeaponVisual")
	print("pistol_visual_probe_points=%d" % weapon_visual.polygon.size())
	print("pistol_visual_probe_position=%s" % str(weapon_visual.position))
	print("pistol_visual_probe_tip_y=%.2f" % _get_tip_y(weapon_visual.polygon))
	print("pistol_visual_probe_grip_y=%.2f" % _get_max_y(weapon_visual.polygon))
	quit()


func _get_tip_y(polygon: PackedVector2Array) -> float:
	var min_y := INF
	for point in polygon:
		min_y = minf(min_y, point.y)
	return min_y


func _get_max_y(polygon: PackedVector2Array) -> float:
	var max_y := -INF
	for point in polygon:
		max_y = maxf(max_y, point.y)
	return max_y
