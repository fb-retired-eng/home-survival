extends SceneTree

const HOME_POSITION := Vector2(1280.0, 720.0)


func _wait_frames(count: int = 1) -> void:
	for _i in range(count):
		await process_frame
		await physics_frame
		await process_frame


func _get_poi_depleted_node_count(game, poi_id: StringName) -> int:
	var count := 0
	for node in game.poi_controller._get_local_scavenge_nodes():
		if node == null or not is_instance_valid(node):
			continue
		if StringName(node.poi_id) != poi_id:
			continue
		var remaining: Dictionary = node.get_remaining_rewards() if node.has_method("get_remaining_rewards") else {}
		var remaining_total := 0
		for resource_id in remaining.keys():
			remaining_total += int(remaining.get(resource_id, 0))
		if bool(node.is_depleted) or remaining_total <= 0:
			count += 1
	return count


func _get_poi_node_debug(game, poi_id: StringName) -> String:
	var lines: Array[String] = []
	for node in game.poi_controller._get_local_scavenge_nodes():
		if node == null or not is_instance_valid(node):
			continue
		if StringName(node.poi_id) != poi_id:
			continue
		var remaining: Dictionary = node.get_remaining_rewards() if node.has_method("get_remaining_rewards") else {}
		lines.append("%s:%s:%d" % [String(node.node_id), str(node.is_depleted), int(remaining.get("salvage", 0)) + int(remaining.get("parts", 0))])
	return "|".join(lines)


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	await _wait_frames(3)
	game.mvp2_run_controller.active_mutator_id = StringName()

	var player = game.player
	var dog = game.dog

	player.global_position = Vector2(300.0, 300.0)
	await _wait_frames(10)
	print("dog_probe_follow_distance=%.1f" % dog.global_position.distance_to(player.global_position))

	player.global_position = HOME_POSITION + Vector2(24.0, 0.0)
	await _wait_frames(2)
	dog.global_position = HOME_POSITION + Vector2(-18.0, 12.0)
	dog.current_stamina = 40
	if int(player.resources.get("food", 0)) <= 0:
		player.add_resource("food", 1, false)
	player.refresh_interaction_prompt()
	await _wait_frames(2)
	print("dog_probe_feed_label=%s" % str(dog.get_interaction_label(player)))
	print("dog_probe_can_feed=%s" % str(dog.can_interact(player)))
	dog.interact(player)
	await _wait_frames(2)
	print("dog_probe_stamina_after_feed=%d" % int(dog.current_stamina))
	print("dog_probe_food_after_feed=%d" % int(player.resources.get("food", 0)))

	player.global_position = Vector2(352.0, 252.0)
	await _wait_frames(18)
	print("dog_probe_known_poi_a=%s" % str(game.poi_controller.is_poi_known(&"poi_a")))

	if int(player.resources.get("food", 0)) > 0:
		player.spend_resource("food", int(player.resources.get("food", 0)))
	var salvage_before := int(player.resources.get("salvage", 0))
	var parts_before := int(player.resources.get("parts", 0))
	var poi_stock_before: int = game.poi_controller.debug_get_remaining_poi_stock_total(&"poi_a")
	var poi_position: Vector2 = game.poi_controller.get_poi_world_position(&"poi_a")
	var distance_to_poi_before: float = dog.global_position.distance_to(poi_position)
	var started: bool = dog.issue_scavenge_command()
	await _wait_frames(2)
	print("dog_probe_scavenge_started=%s" % str(started))
	print("dog_probe_state_after_start=%s" % dog._build_status_text())
	print("dog_probe_scavenge_visible=%s" % str(dog.visible))
	print("dog_probe_scavenge_moved_toward_poi=%s" % str(dog.global_position.distance_to(poi_position) < distance_to_poi_before))
	var saw_returning := false
	for _i in range(180):
		await _wait_frames(1)
		if dog._scavenge_returning:
			saw_returning = true
			break
	print("dog_probe_scavenge_returning=%s" % str(saw_returning))
	var completed: bool = dog.debug_complete_active_scavenge()
	await _wait_frames(2)
	print("dog_probe_scavenge_completed=%s" % str(completed))
	print("dog_probe_state_after_return=%s" % dog._build_status_text())
	var salvage_after := int(player.resources.get("salvage", 0))
	var parts_after := int(player.resources.get("parts", 0))
	print("dog_probe_salvage_after=%d" % salvage_after)
	print("dog_probe_salvage_gained=%d" % (salvage_after - salvage_before))
	print("dog_probe_parts_after=%d" % parts_after)
	print("dog_probe_parts_gained=%d" % (parts_after - parts_before))
	print("dog_probe_total_haul=%d" % ((salvage_after - salvage_before) + (parts_after - parts_before)))
	print("dog_probe_poi_stock_after_first=%d" % int(game.poi_controller.debug_get_remaining_poi_stock_total(&"poi_a")))
	print("dog_probe_poi_depleted_nodes_after_first=%d" % _get_poi_depleted_node_count(game, &"poi_a"))
	print("dog_probe_poi_nodes_after_first=%s" % _get_poi_node_debug(game, &"poi_a"))
	var second_salvage_before := int(player.resources.get("salvage", 0))
	var second_parts_before := int(player.resources.get("parts", 0))
	var second_started: bool = dog.issue_scavenge_command()
	await _wait_frames(2)
	var second_completed: bool = dog.debug_complete_active_scavenge()
	await _wait_frames(2)
	var second_salvage_after := int(player.resources.get("salvage", 0))
	var second_parts_after := int(player.resources.get("parts", 0))
	print("dog_probe_second_scavenge_started=%s" % str(second_started))
	print("dog_probe_second_scavenge_completed=%s" % str(second_completed))
	print("dog_probe_second_total_haul=%d" % ((second_salvage_after - second_salvage_before) + (second_parts_after - second_parts_before)))
	print("dog_probe_poi_stock_decreased=%s" % str(game.poi_controller.debug_get_remaining_poi_stock_total(&"poi_a") < poi_stock_before))
	print("dog_probe_poi_depleted_nodes_after_second=%d" % _get_poi_depleted_node_count(game, &"poi_a"))
	print("dog_probe_poi_nodes_after_second=%s" % _get_poi_node_debug(game, &"poi_a"))

	var third_started: bool = dog.issue_scavenge_command()
	await _wait_frames(2)
	var third_completed: bool = dog.debug_complete_active_scavenge()
	await _wait_frames(2)
	print("dog_probe_third_scavenge_started=%s" % str(third_started))
	print("dog_probe_third_scavenge_completed=%s" % str(third_completed))
	print("dog_probe_poi_depleted_nodes_after_third=%d" % _get_poi_depleted_node_count(game, &"poi_a"))
	print("dog_probe_poi_nodes_after_third=%s" % _get_poi_node_debug(game, &"poi_a"))

	var saved_state: Dictionary = dog.get_save_state()
	dog.current_stamina = 12
	dog.apply_save_state(saved_state)
	await _wait_frames(1)
	print("dog_probe_save_restore_stamina=%d" % int(dog.current_stamina))
	quit()
