extends SceneTree


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	print("map_layout_probe_player=%s" % str(game.player.global_position))
	print("map_layout_probe_sleep=%s" % str(game.get_node("World/SleepPoint").global_position))
	print("map_layout_probe_poi_a=%s" % str(game.get_node("World/POI_A").global_position))
	print("map_layout_probe_poi_d=%s" % str(game.get_node("World/POI_D").global_position))
	print("map_layout_probe_north_spawn=%s" % str(game.get_node("World/SpawnMarkers/North").global_position))
	print("map_layout_probe_east_spawn=%s" % str(game.get_node("World/SpawnMarkers/East").global_position))
	quit()
