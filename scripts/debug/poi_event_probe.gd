extends SceneTree

const GAME_SCENE := preload("res://scenes/main/Game.tscn")


func _wait_frames(count: int = 1) -> void:
	for _i in range(count):
		await process_frame
		await physics_frame
		await process_frame


func _find_scavenge_node(game, poi_id: StringName):
	for child in game.world_root.get_children():
		if child == null or not is_instance_valid(child):
			continue
		for node in child.get_children():
			if node != null and is_instance_valid(node) and node.get("poi_id") == poi_id:
				return node
	return null


func _init() -> void:
	var game = GAME_SCENE.instantiate()
	root.add_child(game)
	await _wait_frames(4)

	game.poi_controller.roll_daily_poi_events(game.mvp2_run_controller)
	var all_poi_ids: Array[StringName] = game.poi_controller.get_all_poi_ids()
	var assigned_count: int = 0
	for poi_id in all_poi_ids:
		if game.poi_controller.get_daily_poi_event(poi_id) != StringName():
			assigned_count += 1

	game.poi_controller._daily_poi_events[&"poi_a"] = &"battery_cache"
	var node = _find_scavenge_node(game, &"poi_a")
	var modified_rewards: Dictionary = game.poi_controller.apply_daily_poi_reward_modifier(node, {"parts": 1})
	var summary: String = game.poi_controller.get_daily_modifier_summary()
	game.poi_controller._daily_poi_events[&"poi_b"] = &"guarded_shipment"
	game.poi_controller.sync_daily_modifier_enemies()
	await _wait_frames(8)
	var forced_elite_found := false
	for enemy in game.exploration_enemy_layer.get_children():
		if enemy == null or not is_instance_valid(enemy):
			continue
		if String(enemy.get_meta("spawn_kind", "")) != "daily_event_elite":
			continue
		if StringName(enemy.get_meta("daily_modifier_poi_id", StringName())) == &"poi_b":
			forced_elite_found = true
			break

	print("poi_event_probe_assigned_count=%d" % assigned_count)
	print("poi_event_probe_battery_bonus=%d" % int(modified_rewards.get("battery", 0)))
	print("poi_event_probe_summary_has_event=%s" % str(summary.contains("Battery Cache")))
	print("poi_event_probe_forced_elite_spawned=%s" % str(forced_elite_found))

	game.queue_free()
	await _wait_frames(2)
	quit()
