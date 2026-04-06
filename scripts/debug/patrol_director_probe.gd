extends SceneTree

const GAME_SCENE := preload("res://scenes/main/Game.tscn")


func _wait_frames(count: int = 1) -> void:
	for _i in range(count):
		await process_frame
		await physics_frame
		await process_frame


func _get_patrols(game) -> Array:
	var patrols: Array = []
	for enemy in game.exploration_enemy_layer.get_children():
		if enemy != null and is_instance_valid(enemy) and String(enemy.get_meta("spawn_kind", "")) == "patrol":
			patrols.append(enemy)
	return patrols


func _init() -> void:
	var game = GAME_SCENE.instantiate()
	root.add_child(game)
	await _wait_frames(4)

	game.patrol_director.enter_day_phase()
	await _wait_frames(12)

	var patrols: Array = _get_patrols(game)
	var patrol_count: int = patrols.size()
	var start_position: Vector2 = patrols[0].global_position if patrol_count > 0 else Vector2.ZERO
	await _wait_frames(60)
	var moved: bool = patrol_count > 0 and patrols[0].global_position.distance_to(start_position) > 4.0

	var saved_state: Dictionary = game.patrol_director.get_save_state()
	game.patrol_director.clear_patrols()
	await _wait_frames(3)
	game.patrol_director.apply_save_state(saved_state)
	game.patrol_director.restore_day_patrols()
	await _wait_frames(12)
	var restored_count: int = _get_patrols(game).size()

	game.patrol_director.clear_patrols()
	var empty_saved_state: Dictionary = game.patrol_director.get_save_state()
	game.patrol_director.apply_save_state(empty_saved_state)
	game.patrol_director.restore_day_patrols()
	await _wait_frames(6)
	var empty_restore_count: int = _get_patrols(game).size()

	print("patrol_probe_spawn_count=%d" % patrol_count)
	print("patrol_probe_moved=%s" % str(moved))
	print("patrol_probe_restored_count=%d" % restored_count)
	print("patrol_probe_empty_restore_count=%d" % empty_restore_count)

	game.queue_free()
	await _wait_frames(2)
	quit()
