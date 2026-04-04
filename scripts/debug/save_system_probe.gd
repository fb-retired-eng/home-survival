extends SceneTree


func _wait_frames() -> void:
	await process_frame
	await physics_frame
	await process_frame


func _find_socket(root_node: Node, socket_id: StringName) -> Node:
	if root_node == null or not is_instance_valid(root_node):
		return null
	for child in root_node.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if StringName(str(child.get("socket_id"))) == socket_id:
			return child
		var found: Node = _find_socket(child, socket_id)
		if found != null:
			return found
	return null


func _find_scavenge_node(root_node: Node, node_id: StringName) -> Node:
	if root_node == null or not is_instance_valid(root_node):
		return null
	for child in root_node.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if StringName(str(child.get("node_id"))) == node_id:
			return child
		var found: Node = _find_scavenge_node(child, node_id)
		if found != null:
			return found
	return null


func _init() -> void:
	await _wait_frames()
	var save_store := root.get_node_or_null("SaveStore")
	if save_store == null:
		push_error("SaveStore autoload missing")
		quit(1)
		return

	var slot_id := &"slot_3"
	save_store.set_active_slot(slot_id)

	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	await _wait_frames()

	game.player.global_position = Vector2(1344.0, 704.0)
	game.player.take_damage(17)
	game.player.add_resource("salvage", 9, false)
	game.player.add_resource("parts", 4, false)
	game.player.add_resource("food", 1, false)
	game.player.set_build_mode_active(true, false)
	game.dog.current_stamina = 58
	game.construction_controller.on_player_build_selection_next_requested()
	game.construction_controller.on_player_build_rotation_requested()
	var build_profile = game.get_selected_buildable_profile()
	var build_cell := Vector2i(10, 8)
	game.construction_grid.set_preview_footprint_offsets(build_profile.get_rotated_footprint_offsets(game.get_selected_buildable_rotation()))
	game.construction_grid.set_preview_world_position(game.construction_grid.get_world_position_for_cell(build_cell))
	game.construction_controller.on_player_build_placement_requested()

	var wall_socket = _find_socket(game, &"wall_n")
	if wall_socket != null:
		wall_socket.take_damage(7)

	var scavenge_node = _find_scavenge_node(game, &"poi_a_1")
	if scavenge_node != null:
		scavenge_node.is_depleted = true
		if scavenge_node.has_method("_refresh_visuals"):
			scavenge_node._refresh_visuals()

	game.poi_controller.debug_set_daily_poi_modifiers({&"poi_b": &"elite_present"})
	game.game_manager.set_wave(2)
	game.game_manager.set_run_state(game.game_manager.RunState.POST_WAVE)
	game.player.set_build_mode_active(true, false)
	save_store.save_active_game(game)

	var payload: Dictionary = save_store.load_slot(slot_id)
	print("save_probe_slot_occupied=%s" % str(bool(save_store.get_slot_summary(slot_id).get("occupied", false))))
	print("save_probe_summary_text=%s" % str(save_store.get_slot_summary(slot_id).get("summary_text", "")))
	print("save_probe_payload_has_run=%s" % str(payload.has("run")))

	var loaded_game = game_scene.instantiate()
	root.add_child(loaded_game)
	await _wait_frames()
	loaded_game.apply_save_state(payload.get("run", {}))
	await _wait_frames()

	var loaded_socket = _find_socket(loaded_game, &"wall_n")
	var loaded_node = _find_scavenge_node(loaded_game, &"poi_a_1")
	var loaded_placeables: Array = loaded_game.construction_placeables.get_children()
	var loaded_placeable = loaded_placeables[0] if not loaded_placeables.is_empty() else null
	var loaded_modifiers: Dictionary = loaded_game.poi_controller.debug_get_daily_poi_modifiers()
	var loaded_placeable_id := ""
	var loaded_placeable_rotation := -1
	var loaded_socket_hp := -1
	var loaded_node_depleted := false
	if loaded_placeable != null:
		loaded_placeable_id = String(loaded_placeable.get_placeable_id())
		loaded_placeable_rotation = int(loaded_placeable.placement_rotation_steps)
	if loaded_socket != null:
		loaded_socket_hp = int(loaded_socket.current_hp)
	if loaded_node != null:
		loaded_node_depleted = bool(loaded_node.is_depleted)

	print("save_probe_player_health=%d" % loaded_game.player.current_health)
	print("save_probe_player_energy=%d" % loaded_game.player.current_energy)
	print("save_probe_player_build_mode=%s" % str(loaded_game.player.is_build_mode_active()))
	print("save_probe_player_position=%s" % str(loaded_game.player.global_position))
	print("save_probe_dog_stamina=%d" % int(loaded_game.dog.current_stamina))
	print("save_probe_dog_state=%s" % str(loaded_game.dog._build_status_text()))
	print("save_probe_wave=%d" % loaded_game.game_manager.current_wave)
	print("save_probe_run_state=%d" % loaded_game.game_manager.run_state)
	print("save_probe_placeable_count=%d" % loaded_placeables.size())
	print("save_probe_placeable_id=%s" % loaded_placeable_id)
	print("save_probe_placeable_rotation=%d" % loaded_placeable_rotation)
	print("save_probe_socket_hp=%d" % loaded_socket_hp)
	print("save_probe_node_depleted=%s" % str(loaded_node_depleted))
	print("save_probe_daily_modifier=%s" % str(loaded_modifiers.get(&"poi_b", StringName())))

	var boot_scene := load("res://scenes/main/Boot.tscn")
	var boot = boot_scene.instantiate()
	root.add_child(boot)
	await _wait_frames()
	var payload_before_continue: Dictionary = boot._save_manager.load_slot(slot_id)
	boot._on_continue_pressed()
	await _wait_frames()
	var payload_after_continue: Dictionary = boot._save_manager.load_slot(slot_id)
	var run_before_continue: Dictionary = payload_before_continue.get("run", {})
	var run_after_continue: Dictionary = payload_after_continue.get("run", {})
	print("save_probe_continue_did_not_rewrite=%s" % str(run_before_continue == run_after_continue))
	boot._on_game_return_to_menu_requested()
	await _wait_frames()
	if boot.has_method("_show_load_menu"):
		boot._show_load_menu()
	await _wait_frames()
	print("save_probe_boot_continue_disabled=%s" % str(boot._continue_button.disabled))

	boot.queue_free()
	loaded_game.queue_free()
	game.queue_free()
	await _wait_frames()
	quit()
