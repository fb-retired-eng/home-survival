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
	print("roaming_zone_probe_has_landmark_zones=%s" % str(
		zone_ids.has("roam_nw_yard")
		and zone_ids.has("roam_ne_checkpoint")
		and zone_ids.has("roam_n_truck")
		and zone_ids.has("roam_sw_garden")
		and zone_ids.has("roam_se_clinic")
		and zone_ids.has("roam_s_scrapyard")
	))
	quit()
