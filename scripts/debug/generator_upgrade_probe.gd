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

	game.player.add_resource("battery", 2, false)
	game.player.global_position = game.generator_point.global_position
	game.player.refresh_interaction_prompt()
	await _wait_frames(2)

	print("generator_probe_can_interact_before=%s" % str(game.generator_point.can_interact(game.player)))
	print("generator_probe_label_before=%s" % str(game.generator_point.get_interaction_label(game.player)))
	print("generator_probe_slots_before=%d" % int(game.power_manager.max_load_slots))

	game.generator_point.interact(game.player)
	await _wait_frames(2)

	print("generator_probe_can_interact_after=%s" % str(game.generator_point.can_interact(game.player)))
	print("generator_probe_slots_after=%d" % int(game.power_manager.max_load_slots))
	print("generator_probe_battery_after=%d" % int(game.player.resources.get("battery", 0)))
	print("generator_probe_power_label=%s" % str(game.hud.power_label.text))

	game.player.spend_resource("battery", int(game.player.resources.get("battery", 0)))
	game.player.refresh_interaction_prompt()
	await _wait_frames(1)
	print("generator_probe_can_interact_no_battery=%s" % str(game.generator_point.can_interact(game.player)))
	print("generator_probe_label_no_battery=%s" % str(game.generator_point.get_interaction_label(game.player)))

	game.queue_free()
	await _wait_frames(2)
	quit()
