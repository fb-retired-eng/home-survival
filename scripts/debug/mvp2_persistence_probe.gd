extends SceneTree

const GAME_SCENE := preload("res://scenes/main/Game.tscn")


func _wait_frames(count: int = 1) -> void:
	for _i in range(count):
		await process_frame
		await physics_frame
		await process_frame


func _init() -> void:
	var source_game = GAME_SCENE.instantiate()
	root.add_child(source_game)
	await _wait_frames(4)

	source_game.mvp2_run_controller.generate_day_state()
	source_game.mvp2_run_controller.active_mutator_id = &"rich_salvage"
	for contract in source_game.mvp2_run_controller.get_daily_contracts():
		if StringName(contract.get("type", "")) == &"visit_poi":
			source_game.mvp2_run_controller.on_poi_discovered(StringName(contract.get("target_poi_id", "")))
			break
	source_game.poi_controller._daily_poi_events[&"poi_a"] = &"battery_cache"
	var save_state: Dictionary = source_game.get_save_state()
	source_game.queue_free()
	await _wait_frames(3)

	var restored_game = GAME_SCENE.instantiate()
	root.add_child(restored_game)
	await _wait_frames(4)
	restored_game.apply_save_state(save_state)
	await _wait_frames(4)

	var restored_contracts: Array[Dictionary] = restored_game.mvp2_run_controller.get_daily_contracts()
	var restored_completed: bool = false
	if not restored_contracts.is_empty():
		restored_completed = bool(restored_contracts[0].get("completed", false))

	print("mvp2_persistence_probe_mutator=%s" % String(restored_game.mvp2_run_controller.active_mutator_id))
	print("mvp2_persistence_probe_contract_completed=%s" % str(restored_completed))
	print("mvp2_persistence_probe_poi_event=%s" % String(restored_game.poi_controller.get_daily_poi_event(&"poi_a")))

	restored_game.queue_free()
	await _wait_frames(2)
	quit()
