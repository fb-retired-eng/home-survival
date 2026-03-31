extends SceneTree


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var zone_ids := PackedStringArray()
	for child in game.roaming_spawn_zones_root.get_children():
		if child == null:
			continue
		zone_ids.append(String(child.zone_id))

	print("roaming_zone_probe_count=%d" % zone_ids.size())
	print("roaming_zone_probe_ids=%s" % ",".join(zone_ids))
	quit()
