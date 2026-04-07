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


func _restore_game(save_state: Dictionary):
	var game = _spawn_game()
	await _wait_frames(4)
	game.apply_save_state(save_state)
	await _wait_frames(4)
	return game


func _prepare_known_day_game():
	var game = _spawn_game()
	await _wait_frames(4)
	game.mvp2_run_controller.active_mutator_id = StringName()
	game.player.global_position = Vector2(352.0, 252.0)
	await _wait_frames(18)
	return game


func _init() -> void:
	var outbound_game = await _prepare_known_day_game()
	outbound_game.dog.issue_scavenge_command()
	await _wait_frames(6)
	var outbound_save: Dictionary = outbound_game.get_save_state()
	outbound_game.queue_free()
	await _wait_frames(2)
	var outbound_restored = await _restore_game(outbound_save)
	print("dog_task_probe_outbound_state=%s" % outbound_restored.dog._build_status_text())
	print("dog_task_probe_outbound_ring_visible=%s" % str(outbound_restored.dog.target_ring.visible))
	print("dog_task_probe_outbound_returning=%s" % str(outbound_restored.dog._scavenge_returning))
	outbound_restored.queue_free()
	await _wait_frames(2)

	var returning_game = await _prepare_known_day_game()
	returning_game.dog.issue_scavenge_command()
	await _wait_frames(6)
	returning_game.dog._scavenge_returning = true
	returning_game.dog._scavenge_pause_remaining = 0.0
	returning_game.dog._remaining_trip_time = 12.0
	returning_game.dog._scavenge_target_position = returning_game.player.global_position + Vector2(-18.0, 20.0)
	var returning_save: Dictionary = returning_game.get_save_state()
	returning_game.queue_free()
	await _wait_frames(2)
	var returning_restored = await _restore_game(returning_save)
	print("dog_task_probe_return_state=%s" % returning_restored.dog._build_status_text())
	print("dog_task_probe_return_ring_visible=%s" % str(returning_restored.dog.target_ring.visible))
	print("dog_task_probe_return_returning=%s" % str(returning_restored.dog._scavenge_returning))
	returning_restored.queue_free()
	await _wait_frames(2)

	var lure_game = _spawn_game()
	await _wait_frames(4)
	lure_game.game_manager.set_run_state(lure_game.game_manager.RunState.ACTIVE_WAVE)
	var lure_target: Vector2 = lure_game.player.global_position + Vector2(120.0, 0.0)
	lure_game.dog.issue_context_command(lure_target)
	await _wait_frames(4)
	var lure_save: Dictionary = lure_game.get_save_state()
	lure_game.queue_free()
	await _wait_frames(2)
	var lure_restored = await _restore_game(lure_save)
	print("dog_task_probe_lure_state=%s" % lure_restored.dog._build_status_text())
	print("dog_task_probe_lure_ring_visible=%s" % str(lure_restored.dog.target_ring.visible))
	print("dog_task_probe_lure_target_restored=%s" % str(lure_restored.dog._lure_target_position.distance_to(lure_target) <= 0.1))
	lure_restored.queue_free()
	await _wait_frames(2)
	quit()
