extends SceneTree

const GAME_SCENE := preload("res://scenes/main/Game.tscn")


func _wait_frames(count: int = 1) -> void:
	for _i in range(count):
		await process_frame
		await physics_frame
		await process_frame


func _spawn_game():
	var game = GAME_SCENE.instantiate()
	root.add_child(game)
	return game


func _find_poi_node_by_id(game, node_id: StringName):
	for node in game.poi_controller._get_local_scavenge_nodes():
		if node == null or not is_instance_valid(node):
			continue
		if StringName(node.node_id) == node_id:
			return node
	return null


func _complete_dog_scavenge(game) -> void:
	game.dog.debug_complete_active_scavenge()
	await _wait_frames(2)


func _init() -> void:
	var poi_id := StringName(&"poi_a")

	var game_a = _spawn_game()
	await _wait_frames(3)
	game_a.mvp2_run_controller.active_mutator_id = StringName()
	game_a.player.global_position = Vector2(352.0, 252.0)
	await _wait_frames(18)
	var node_a = _find_poi_node_by_id(game_a, &"poi_a_1")
	node_a.bonus_table = null
	var stock_before_player: int = game_a.poi_controller.debug_get_remaining_poi_stock_total(poi_id)
	var player_first_salvage_before := int(game_a.player.resources.get("salvage", 0))
	var player_first_parts_before := int(game_a.player.resources.get("parts", 0))
	node_a._complete_search(game_a.player)
	await _wait_frames(2)
	var stock_after_player: int = game_a.poi_controller.debug_get_remaining_poi_stock_total(poi_id)
	var player_first_search_gain := (int(game_a.player.resources.get("salvage", 0)) - player_first_salvage_before) + (int(game_a.player.resources.get("parts", 0)) - player_first_parts_before)
	var salvage_before_player_first := int(game_a.player.resources.get("salvage", 0))
	var parts_before_player_first := int(game_a.player.resources.get("parts", 0))
	var dog_started_after_player: bool = game_a.dog.issue_scavenge_command()
	await _wait_frames(2)
	await _complete_dog_scavenge(game_a)
	var haul_after_player := (int(game_a.player.resources.get("salvage", 0)) - salvage_before_player_first) + (int(game_a.player.resources.get("parts", 0)) - parts_before_player_first)
	print("dog_shared_stock_probe_player_first_stock_decreased=%s" % str(stock_after_player < stock_before_player))
	print("dog_shared_stock_probe_player_first_search_gain=%d" % player_first_search_gain)
	print("dog_shared_stock_probe_player_first_dog_started=%s" % str(dog_started_after_player))
	print("dog_shared_stock_probe_player_first_dog_haul=%d" % haul_after_player)
	game_a.queue_free()
	await _wait_frames(2)

	var game_b = _spawn_game()
	await _wait_frames(3)
	game_b.mvp2_run_controller.active_mutator_id = StringName()
	game_b.player.global_position = Vector2(352.0, 252.0)
	await _wait_frames(18)
	var node_b = _find_poi_node_by_id(game_b, &"poi_a_1")
	node_b.bonus_table = null
	game_b.poi_controller._poi_hidden_stock_remaining[poi_id] = {
		"salvage": 0,
		"parts": 0,
		"medicine": 0,
		"bullets": 0,
		"food": 0,
		"battery": 0,
	}
	var stock_before_dog: int = game_b.poi_controller.debug_get_remaining_poi_stock_total(poi_id)
	var node_b_visible_before: int = int(node_b.get_remaining_rewards().get("salvage", 0)) + int(node_b.get_remaining_rewards().get("parts", 0))
	var dog_started_first: bool = game_b.dog.issue_scavenge_command()
	await _wait_frames(2)
	await _complete_dog_scavenge(game_b)
	var stock_after_dog: int = game_b.poi_controller.debug_get_remaining_poi_stock_total(poi_id)
	var node_b_visible_after_dog: int = int(node_b.get_remaining_rewards().get("salvage", 0)) + int(node_b.get_remaining_rewards().get("parts", 0))
	var player_after_dog_salvage_before := int(game_b.player.resources.get("salvage", 0))
	var player_after_dog_parts_before := int(game_b.player.resources.get("parts", 0))
	var visible_before_player_search := int(node_b.get_remaining_rewards().get("salvage", 0)) + int(node_b.get_remaining_rewards().get("parts", 0))
	node_b._complete_search(game_b.player)
	await _wait_frames(2)
	var stock_after_player_second: int = game_b.poi_controller.debug_get_remaining_poi_stock_total(poi_id)
	var player_after_dog_search_gain := (int(game_b.player.resources.get("salvage", 0)) - player_after_dog_salvage_before) + (int(game_b.player.resources.get("parts", 0)) - player_after_dog_parts_before)
	var visible_after_player_search := int(node_b.get_remaining_rewards().get("salvage", 0)) + int(node_b.get_remaining_rewards().get("parts", 0))
	var player_after_dog_search_consistent := visible_before_player_search == 0 and visible_after_player_search == 0 and player_after_dog_search_gain == 0
	print("dog_shared_stock_probe_dog_first_started=%s" % str(dog_started_first))
	print("dog_shared_stock_probe_dog_first_stock_decreased=%s" % str(stock_after_dog < stock_before_dog))
	print("dog_shared_stock_probe_visible_node_after_dog_reduced=%s" % str(node_b_visible_after_dog < node_b_visible_before))
	print("dog_shared_stock_probe_player_after_dog_search_consistent=%s" % str(player_after_dog_search_consistent))
	print("dog_shared_stock_probe_player_after_dog_search_gain=%d" % player_after_dog_search_gain)
	print("dog_shared_stock_probe_player_after_dog_search_reduced=%s" % str(player_after_dog_search_gain < player_first_search_gain))

	var game_c = _spawn_game()
	await _wait_frames(3)
	var node_c = _find_poi_node_by_id(game_c, &"poi_a_1")
	for resource_id in ["salvage", "parts", "medicine", "bullets", "food", "battery"]:
		var remaining_rewards: Dictionary = node_c.get_remaining_rewards()
		node_c.consume_remaining_reward(resource_id, int(remaining_rewards.get(resource_id, 0)))
	print("dog_shared_stock_probe_empty_node_depleted=%s" % str(node_c.is_depleted))
	print("dog_shared_stock_probe_empty_node_interactable=%s" % str(node_c.can_interact(game_c.player)))
	game_c.queue_free()
	await _wait_frames(2)

	game_b.queue_free()
	await _wait_frames(2)
	quit()
