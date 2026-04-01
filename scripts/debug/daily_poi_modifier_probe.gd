extends SceneTree


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


func _force_day_phase_with_modifiers(game, modifiers: Dictionary) -> void:
	game.debug_queue_forced_next_daily_poi_modifiers(modifiers)
	game._enter_day_phase()
	await process_frame
	await physics_frame
	await process_frame


func _count_modifier_types(modifiers: Dictionary) -> Dictionary:
	var positive_count := 0
	var negative_count := 0
	for modifier_variant in modifiers.values():
		var modifier_id := StringName(modifier_variant)
		match modifier_id:
			&"bountiful_food", &"extra_parts":
				positive_count += 1
			&"disturbed", &"elite_present":
				negative_count += 1
	return {
		"positive": positive_count,
		"negative": negative_count,
	}


func _get_guard_spawn(game, poi_id: StringName):
	return game._get_poi_guard_spawn_point(poi_id)


func _count_daily_elites(game, poi_id: StringName) -> int:
	var count := 0
	for child in game.exploration_enemy_layer.get_children():
		if not is_instance_valid(child):
			continue
		if child.is_queued_for_deletion():
			continue
		if StringName(child.get_meta("daily_modifier_poi_id", StringName())) == poi_id:
			count += 1
	return count


func _count_spawned_enemies_for_spawn_id(game, spawn_id: StringName) -> int:
	var count := 0
	for child in game.exploration_enemy_layer.get_children():
		if not is_instance_valid(child):
			continue
		if child.is_queued_for_deletion():
			continue
		if StringName(child.get_meta("spawn_id", StringName())) == spawn_id:
			count += 1
	return count


func _kill_enemies_for_spawn_id(game, spawn_id: StringName, kill_count: int) -> void:
	var remaining := kill_count
	for child in game.exploration_enemy_layer.get_children():
		if remaining <= 0:
			break
		if not is_instance_valid(child):
			continue
		if child.is_queued_for_deletion():
			continue
		if StringName(child.get_meta("spawn_id", StringName())) != spawn_id:
			continue
		if child.has_method("take_damage"):
			child.take_damage(9999, {"source_position": child.global_position + Vector2.LEFT})
			remaining -= 1
	await process_frame
	await physics_frame
	await process_frame


func _deplete_poi(game, poi_id: StringName) -> void:
	for node in game.get_tree().get_nodes_in_group("scavenge_nodes"):
		if StringName(node.poi_id) != poi_id:
			continue
		node.is_depleted = true
		if node.has_method("_refresh_visuals"):
			node._refresh_visuals()


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var initial_modifiers: Dictionary = game.debug_get_daily_poi_modifiers()
	var modifier_counts := _count_modifier_types(initial_modifiers)
	print("daily_poi_modifier_probe_positive_count=%d" % int(modifier_counts.get("positive", 0)))
	print("daily_poi_modifier_probe_negative_count=%d" % int(modifier_counts.get("negative", 0)))

	for poi_id_variant in initial_modifiers.keys():
		var poi_id := StringName(poi_id_variant)
		print("daily_poi_modifier_probe_label_%s=%s" % [String(poi_id), game.debug_get_poi_label_text(poi_id)])

	game.player.resources["food"] = 0
	game.player.resources_changed.emit(game.player.resources.duplicate(true))
	game.player.current_energy = 55
	game.player.energy_changed.emit(game.player.current_energy, game.player.max_energy)
	game.player.add_resource("food", 3, false)
	await process_frame
	game._on_food_table_requested(game.player)
	await process_frame
	await physics_frame
	await process_frame
	await _clear_wave_by_killing_enemies(game)
	await process_frame
	game._on_sleep_requested(game.player)
	await process_frame
	await physics_frame
	await process_frame
	var live_cycle_modifiers: Dictionary = game.debug_get_daily_poi_modifiers()
	var live_cycle_counts := _count_modifier_types(live_cycle_modifiers)
	print("daily_poi_modifier_probe_live_cycle_positive=%d" % int(live_cycle_counts.get("positive", 0)))
	print("daily_poi_modifier_probe_live_cycle_negative=%d" % int(live_cycle_counts.get("negative", 0)))

	await _force_day_phase_with_modifiers(game, {
		&"poi_e": &"bountiful_food",
		&"poi_b": &"disturbed",
	})
	var poi_e_node = game.get_node("World/POI_E/Node1")
	poi_e_node.bonus_table = null
	game.player.resources["food"] = 0
	game.player.resources_changed.emit(game.player.resources.duplicate(true))
	poi_e_node._complete_search(game.player)
	print("daily_poi_modifier_probe_food_reward=%d" % int(game.player.resources.get("food", 0)))

	var poi_b_guard = _get_guard_spawn(game, &"poi_b")
	var poi_b_base_count: int = game._get_or_roll_exploration_spawn_count(poi_b_guard)
	var poi_b_adjusted_count: int = game._get_adjusted_exploration_spawn_count(poi_b_guard)
	print("daily_poi_modifier_probe_disturbed_counts=%d>%d" % [poi_b_adjusted_count, poi_b_base_count])
	game._clear_exploration_enemies()
	game._defeated_exploration_spawn_ids.erase("explore_guard_b")
	game._defeated_exploration_enemy_counts.erase("explore_guard_b")
	game._current_exploration_target_counts.erase("explore_guard_b")
	await process_frame
	await physics_frame
	await process_frame
	await _force_day_phase_with_modifiers(game, {
		&"poi_b": &"disturbed",
	})
	print("daily_poi_modifier_probe_disturbed_spawned=%d" % _count_spawned_enemies_for_spawn_id(game, &"explore_guard_b"))
	await _kill_enemies_for_spawn_id(game, &"explore_guard_b", poi_b_base_count)
	print("daily_poi_modifier_probe_disturbed_cleared_after_base=%s" % str(game._defeated_exploration_spawn_ids.has("explore_guard_b")))
	print("daily_poi_modifier_probe_disturbed_remaining=%d" % _count_spawned_enemies_for_spawn_id(game, &"explore_guard_b"))
	await _kill_enemies_for_spawn_id(game, &"explore_guard_b", 1)
	print("daily_poi_modifier_probe_disturbed_cleared_after_extra=%s" % str(game._defeated_exploration_spawn_ids.has("explore_guard_b")))

	game._clear_exploration_enemies()
	await process_frame
	await physics_frame
	await process_frame
	game.default_daily_elite_enemy = null
	await _force_day_phase_with_modifiers(game, {
		&"poi_c": &"elite_present",
	})
	print("daily_poi_modifier_probe_elite_count=%d" % _count_daily_elites(game, &"poi_c"))
	for child in game.exploration_enemy_layer.get_children():
		if not is_instance_valid(child):
			continue
		if StringName(child.get_meta("daily_modifier_poi_id", StringName())) != &"poi_c":
			continue
		print("daily_poi_modifier_probe_elite_enemy_id=%s" % String(child.definition.enemy_id))
		break
	game._clear_exploration_enemies()
	await process_frame
	await physics_frame
	await process_frame
	await _force_day_phase_with_modifiers(game, {
		&"poi_b": &"elite_present",
	})
	print("daily_poi_modifier_probe_alt_elite_count=%d" % _count_daily_elites(game, &"poi_b"))
	for child in game.exploration_enemy_layer.get_children():
		if not is_instance_valid(child):
			continue
		if StringName(child.get_meta("daily_modifier_poi_id", StringName())) != &"poi_b":
			continue
		print("daily_poi_modifier_probe_alt_elite_enemy_id=%s" % String(child.definition.enemy_id))
		break
	await _force_day_phase_with_modifiers(game, {
		&"poi_e": &"extra_parts",
	})
	print("daily_poi_modifier_probe_elite_cleared=%d" % _count_daily_elites(game, &"poi_c"))

	_deplete_poi(game, &"poi_a")
	game._roll_daily_poi_modifiers()
	game._refresh_poi_modifier_visuals()
	var rerolled_modifiers: Dictionary = game.debug_get_daily_poi_modifiers()
	print("daily_poi_modifier_probe_depleted_poi_a_selected=%s" % str(rerolled_modifiers.has(&"poi_a")))

	game._is_resetting_run = true
	game.game_manager.reset_run()
	await process_frame
	await physics_frame
	await process_frame
	var reset_modifiers: Dictionary = game.debug_get_daily_poi_modifiers()
	var reset_counts := _count_modifier_types(reset_modifiers)
	print("daily_poi_modifier_probe_after_reset_positive=%d" % int(reset_counts.get("positive", 0)))
	print("daily_poi_modifier_probe_after_reset_negative=%d" % int(reset_counts.get("negative", 0)))

	quit()
