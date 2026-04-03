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
	print("map_layout_probe_poi_b=%s" % str(game.get_node("World/POI_B").global_position))
	print("map_layout_probe_poi_c=%s" % str(game.get_node("World/POI_C").global_position))
	print("map_layout_probe_poi_d=%s" % str(game.get_node("World/POI_D").global_position))
	print("map_layout_probe_poi_e=%s" % str(game.get_node("World/POI_E").global_position))
	print("map_layout_probe_poi_f=%s" % str(game.get_node("World/POI_F").global_position))
	print("map_layout_probe_north_spawn=%s" % str(game.get_node("World/SpawnMarkers/North").global_position))
	print("map_layout_probe_east_spawn=%s" % str(game.get_node("World/SpawnMarkers/East").global_position))
	print("map_layout_probe_roam_nw=%s" % str(game.get_node("World/RoamingSpawnZones/NorthWestOuter").global_position))
	print("map_layout_probe_roam_ne=%s" % str(game.get_node("World/RoamingSpawnZones/NorthEastOuter").global_position))
	print("map_layout_probe_roam_n=%s" % str(game.get_node("World/RoamingSpawnZones/NorthMidOuter").global_position))
	print("map_layout_probe_roam_sw=%s" % str(game.get_node("World/RoamingSpawnZones/SouthWestOuter").global_position))
	print("map_layout_probe_roam_se=%s" % str(game.get_node("World/RoamingSpawnZones/SouthEastOuter").global_position))
	print("map_layout_probe_roam_s=%s" % str(game.get_node("World/RoamingSpawnZones/SouthMidOuter").global_position))
	print("map_layout_probe_roam_nw_yard=%s" % str(game.get_node("World/RoamingSpawnZones/NorthWestYard").global_position))
	print("map_layout_probe_roam_ne_checkpoint=%s" % str(game.get_node("World/RoamingSpawnZones/NorthEastCheckpoint").global_position))
	print("map_layout_probe_roam_n_truck=%s" % str(game.get_node("World/RoamingSpawnZones/NorthTruckStop").global_position))
	print("map_layout_probe_roam_sw_garden=%s" % str(game.get_node("World/RoamingSpawnZones/SouthWestGarden").global_position))
	print("map_layout_probe_roam_se_clinic=%s" % str(game.get_node("World/RoamingSpawnZones/SouthEastClinic").global_position))
	print("map_layout_probe_roam_s_scrapyard=%s" % str(game.get_node("World/RoamingSpawnZones/SouthScrapyard").global_position))
	print("map_layout_probe_district_nw=%s" % str(game.get_node("World/DistrictNorthWest") != null))
	print("map_layout_probe_district_ne=%s" % str(game.get_node("World/DistrictNorthEast") != null))
	print("map_layout_probe_road_cross=%s" % str(game.get_node("World/MainRoadHorizontal") != null and game.get_node("World/MainRoadVertical") != null))
	print("map_layout_probe_landmark_nw=%s" % str(game.get_node("World/NorthWestShedA") != null and game.get_node("World/NorthWestShedB") != null))
	print("map_layout_probe_landmark_se=%s" % str(game.get_node("World/SouthEastClinicA") != null and game.get_node("World/SouthEastClinicB") != null))
	print("map_layout_probe_route_islands=%s" % str(game.get_node("World/RouteIslandWest") != null and game.get_node("World/RouteIslandEast") != null))
	quit()
