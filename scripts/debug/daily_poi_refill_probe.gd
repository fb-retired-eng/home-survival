extends SceneTree


func _wait_frames() -> void:
	await process_frame
	await physics_frame
	await process_frame


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	await _wait_frames()

	var resource_node = game.get_node("World/POI_A/Node1")
	var weapon_node = game.get_node("World/POI_B/Node4")
	resource_node.is_depleted = true
	resource_node._refresh_visuals()
	weapon_node.is_depleted = true
	weapon_node._refresh_visuals()

	game.daily_poi_refill_base_nodes = 1
	game.daily_poi_refill_bonus_chance = 0.0
	game.daily_poi_refill_bonus_nodes = 0

	game._enter_day_phase()
	await _wait_frames()

	print("daily_poi_refill_probe_resource_refilled=%s" % str(not resource_node.is_depleted))
	print("daily_poi_refill_probe_weapon_still_depleted=%s" % str(weapon_node.is_depleted))
	print("daily_poi_refill_probe_status=%s" % game.hud.status_label.text)
	quit()
