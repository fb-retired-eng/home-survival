extends SceneTree


func _wait_frames(count: int = 1) -> void:
	for _i in range(count):
		await process_frame
		await physics_frame


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	await _wait_frames(3)

	var pickups_root = game.ambient_pickups_root
	var initial_count: int = pickups_root.get_child_count()
	var target_pickup = pickups_root.get_child(0) if initial_count > 0 else null
	if target_pickup == null:
		push_error("No ambient micro-loot pickup spawned")
		quit(1)
		return

	var player = game.player
	var tool_yard_spawn = game.get_node("World/MicroLootSpawns/ToolYardSalvage")
	var tool_yard_defaults: Dictionary = game.poi_controller.resolve_micro_loot_spawn_defaults(tool_yard_spawn)
	var before_salvage := int(player.resources.get("salvage", 0))
	player.global_position = target_pickup.global_position
	await _wait_frames(3)
	var after_salvage := int(player.resources.get("salvage", 0))
	var after_count: int = pickups_root.get_child_count()
	var save_state: Dictionary = game.get_save_state()
	var collected_ids: Array = save_state.get("game", {}).get("collected_micro_loot_ids", [])

	print("micro_loot_probe_initial_count=%d" % initial_count)
	print("micro_loot_probe_after_count=%d" % after_count)
	print("micro_loot_probe_tool_yard_resource=%s" % str(tool_yard_defaults.get("resource_id", "")))
	print("micro_loot_probe_tool_yard_amount=%d" % int(tool_yard_defaults.get("amount", 0)))
	print("micro_loot_probe_salvage_before=%d" % before_salvage)
	print("micro_loot_probe_salvage_after=%d" % after_salvage)
	print("micro_loot_probe_collected_saved=%s" % str(not collected_ids.is_empty()))
	game.queue_free()
	await _wait_frames(2)
	quit()
