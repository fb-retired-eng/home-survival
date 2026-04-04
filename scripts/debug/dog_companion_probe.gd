extends SceneTree

const HOME_POSITION := Vector2(1280.0, 720.0)


func _wait_frames(count: int = 1) -> void:
	for _i in range(count):
		await process_frame
		await physics_frame
		await process_frame


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	await _wait_frames(3)

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
	var started: bool = dog.issue_scavenge_command()
	await _wait_frames(2)
	print("dog_probe_scavenge_started=%s" % str(started))
	print("dog_probe_state_after_start=%s" % dog._build_status_text())
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

	var saved_state: Dictionary = dog.get_save_state()
	dog.current_stamina = 12
	dog.apply_save_state(saved_state)
	await _wait_frames(1)
	print("dog_probe_save_restore_stamina=%d" % int(dog.current_stamina))
	quit()
