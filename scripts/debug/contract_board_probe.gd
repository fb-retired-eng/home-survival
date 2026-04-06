extends SceneTree

const GAME_SCENE := preload("res://scenes/main/Game.tscn")


func _wait_frames(count: int = 1) -> void:
	for _i in range(count):
		await process_frame
		await physics_frame
		await process_frame


func _init() -> void:
	var game = GAME_SCENE.instantiate()
	root.add_child(game)
	await _wait_frames(4)

	game.mvp2_run_controller.generate_day_state()
	game.poi_controller._daily_poi_events[&"poi_a"] = &"battery_cache"
	game.mvp2_run_controller._generate_daily_contracts()
	var contracts: Array[Dictionary] = game.mvp2_run_controller.get_daily_contracts()
	var visit_contract: Dictionary = {}
	for contract in contracts:
		if StringName(contract.get("type", "")) == &"visit_poi":
			visit_contract = contract
			break

	var salvage_before: int = int(game.player.resources.get("salvage", 0))
	if not visit_contract.is_empty():
		game.mvp2_run_controller.on_poi_discovered(StringName(visit_contract.get("target_poi_id", "")))
	game.mvp2_run_controller.on_contract_board_requested(game.player)
	await _wait_frames(3)

	var salvage_after: int = int(game.player.resources.get("salvage", 0))
	var updated_contracts: Array[Dictionary] = game.mvp2_run_controller.get_daily_contracts()
	var claimed: bool = false
	for contract in updated_contracts:
		if StringName(contract.get("type", "")) == &"visit_poi":
			claimed = bool(contract.get("claimed", false))
			break

	print("contract_probe_contract_count=%d" % contracts.size())
	print("contract_probe_visit_target=%s" % String(visit_contract.get("target_poi_id", "")))
	print("contract_probe_visit_claimed=%s" % str(claimed))
	print("contract_probe_salvage_delta=%d" % (salvage_after - salvage_before))

	game.queue_free()
	await _wait_frames(2)
	quit()
