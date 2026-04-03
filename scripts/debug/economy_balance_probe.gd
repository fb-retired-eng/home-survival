extends SceneTree


func _wait_frames() -> void:
	await process_frame
	await physics_frame
	await process_frame


func _sum_poi_rewards(game, poi_id: StringName) -> Dictionary:
	var totals := {
		"salvage": 0,
		"parts": 0,
		"medicine": 0,
		"bullets": 0,
		"food": 0,
	}
	for node in game.get_tree().get_nodes_in_group("scavenge_nodes"):
		if StringName(node.poi_id) != poi_id:
			continue
		totals["salvage"] += int(node.reward_salvage)
		totals["parts"] += int(node.reward_parts)
		totals["medicine"] += int(node.reward_medicine)
		totals["bullets"] += int(node.reward_bullets)
		totals["food"] += int(node.reward_food)
	return totals


func _format_rewards(rewards: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in ["salvage", "parts", "medicine", "bullets", "food"]:
		var amount := int(rewards.get(resource_id, 0))
		if amount <= 0:
			continue
		parts.append("%s:%d" % [resource_id, amount])
	if parts.is_empty():
		return "empty"
	return ",".join(parts)


func _find_support_spawn(game, poi_id: StringName):
	for child in game.get_node("World/MicroLootSpawns").get_children():
		if not bool(child.get("use_poi_role_defaults")):
			continue
		if StringName(child.get("poi_id")) == poi_id:
			return child
	return null


func _get_wave_summary(wave_definition: Resource) -> Dictionary:
	var total_count := 0
	var breakdown := {}
	for lane in wave_definition.lanes:
		var count := int(lane.count)
		total_count += count
		var enemy_id := String(lane.enemy_definition.enemy_id)
		breakdown[enemy_id] = int(breakdown.get(enemy_id, 0)) + count
	return {
		"total": total_count,
		"breakdown": breakdown,
	}


func _format_breakdown(breakdown: Dictionary) -> String:
	var keys: Array[String] = []
	for key in breakdown.keys():
		keys.append(String(key))
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		parts.append("%s:%d" % [key, int(breakdown[key])])
	return ",".join(parts)


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	await _wait_frames()

	for poi_id in [&"poi_a", &"poi_b", &"poi_c", &"poi_d", &"poi_e", &"poi_f"]:
		var guard_spawn = game._get_poi_guard_spawn_point(poi_id)
		var support_spawn = _find_support_spawn(game, poi_id)
		var support_defaults := {}
		if support_spawn != null:
			support_defaults = game.poi_controller.resolve_micro_loot_spawn_defaults(support_spawn)
		print("economy_probe_%s_role=%s" % [String(poi_id), game.debug_get_poi_reward_role_label(poi_id)])
		print("economy_probe_%s_base_rewards=%s" % [String(poi_id), _format_rewards(_sum_poi_rewards(game, poi_id))])
		if guard_spawn != null:
			print("economy_probe_%s_guard=%s:%d-%d" % [
				String(poi_id),
				String(guard_spawn.enemy_definition.enemy_id),
				int(guard_spawn.min_count),
				int(guard_spawn.max_count),
			])
		if not support_defaults.is_empty():
			print("economy_probe_%s_support=%s:%d" % [
				String(poi_id),
				String(support_defaults.get("resource_id", "")),
				int(support_defaults.get("amount", 0)),
			])

	var barricade = load("res://data/placeables/barricade.tres")
	var spike_trap = load("res://data/placeables/spike_trap.tres")
	print("economy_probe_barricade_build=%s" % _format_rewards(barricade.build_cost))
	print("economy_probe_barricade_repair=%s" % _format_rewards(barricade.repair_cost))
	print("economy_probe_barricade_recycle=%s" % _format_rewards(barricade.build_cost))
	print("economy_probe_spike_build=%s" % _format_rewards(spike_trap.build_cost))
	print("economy_probe_spike_repair=%s" % _format_rewards(spike_trap.repair_cost))
	print("economy_probe_spike_stats=hp:%d,damage:%d,slow:%.2f" % [int(spike_trap.max_hp), int(spike_trap.contact_damage), float(spike_trap.slow_factor)])

	for wave_number in [3, 5, 7]:
		var wave_definition = game.wave_manager.wave_set_definition.waves[wave_number - 1]
		var wave_summary := _get_wave_summary(wave_definition)
		print("economy_probe_wave_%d_total=%d" % [wave_number, int(wave_summary.get("total", 0))])
		print("economy_probe_wave_%d_breakdown=%s" % [wave_number, _format_breakdown(wave_summary.get("breakdown", {}))])
		print("economy_probe_wave_%d_interval=%.2f" % [wave_number, float(wave_definition.spawn_interval)])

	game.queue_free()
	await _wait_frames()
	quit()
