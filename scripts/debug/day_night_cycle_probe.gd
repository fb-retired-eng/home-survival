extends SceneTree


func _count_live_exploration_enemies(game) -> int:
	var count := 0
	for child in game.exploration_enemy_layer.get_children():
		if not is_instance_valid(child):
			continue
		if child.is_queued_for_deletion():
			continue
		count += 1
	return count


func _clear_wave_by_killing_enemies(game) -> void:
	for _step in range(240):
		for child in game.wave_enemy_layer.get_children():
			if not is_instance_valid(child):
				continue
			if child.is_queued_for_deletion():
				continue
			if child.has_method("take_damage"):
				child.take_damage(9999, {"source_position": child.global_position + Vector2.LEFT})
		if game.game_manager.run_state == game.game_manager.RunState.POST_WAVE:
			return
		await process_frame
		await physics_frame
		await process_frame


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	game.player.resources["food"] = 0
	game.player.resources_changed.emit(game.player.resources.duplicate(true))
	game.player.current_energy = 55
	game.player.energy_changed.emit(game.player.current_energy, game.player.max_energy)
	game.player.add_resource("food", 3, false)
	await process_frame

	print("day_night_cycle_probe_day_state=%d" % game.game_manager.run_state)
	print("day_night_cycle_probe_day_phase=%s" % game.hud.wave_label.text)
	print("day_night_cycle_probe_day_enemy_count=%d" % _count_live_exploration_enemies(game))
	print("day_night_cycle_probe_table_label=%s" % game._get_food_table_label(game.player))

	game._on_food_table_requested(game.player)
	await process_frame
	await physics_frame
	await process_frame
	print("day_night_cycle_probe_after_dinner_state=%d" % game.game_manager.run_state)
	print("day_night_cycle_probe_after_dinner_wave=%d" % game.game_manager.current_wave)

	await _clear_wave_by_killing_enemies(game)
	await process_frame
	print("day_night_cycle_probe_after_wave_state=%d" % game.game_manager.run_state)
	print("day_night_cycle_probe_bed_label=%s" % game._get_sleep_label(game.player))

	game._on_sleep_requested(game.player)
	await process_frame
	await physics_frame
	await process_frame
	print("day_night_cycle_probe_after_sleep_state=%d" % game.game_manager.run_state)
	print("day_night_cycle_probe_after_sleep_phase=%s" % game.hud.wave_label.text)
	print("day_night_cycle_probe_after_sleep_enemy_count=%d" % _count_live_exploration_enemies(game))
	quit()
