extends SceneTree


func _wait_frames() -> void:
	await process_frame
	await physics_frame
	await process_frame


func _press_action(action_name: StringName) -> void:
	Input.action_press(action_name)
	await physics_frame
	await process_frame
	Input.action_release(action_name)
	await process_frame


func _press_action_event(action_name: StringName) -> void:
	var press_event := InputEventAction.new()
	press_event.action = action_name
	press_event.pressed = true
	Input.parse_input_event(press_event)
	await physics_frame
	await process_frame
	var release_event := InputEventAction.new()
	release_event.action = action_name
	release_event.pressed = false
	Input.parse_input_event(release_event)
	await process_frame


func _press_key(keycode: Key) -> void:
	var press_event := InputEventKey.new()
	press_event.keycode = keycode
	press_event.physical_keycode = keycode
	press_event.pressed = true
	press_event.echo = false
	Input.parse_input_event(press_event)
	await physics_frame
	await process_frame
	var release_event := InputEventKey.new()
	release_event.keycode = keycode
	release_event.physical_keycode = keycode
	release_event.pressed = false
	release_event.echo = false
	Input.parse_input_event(release_event)
	await process_frame


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	game.enable_test_mode = true
	root.add_child(game)
	await _wait_frames()

	var grid = game.construction_grid
	var player = game.player
	var placeables_root = game.construction_placeables
	var tactical_cell := Vector2i(-1, 3)
	var starting_salvage := int(player.resources.get("salvage", 0))
	print("barricade_probe_recycle_action_exists=%s" % str(InputMap.has_action("recycle")))
	player.message_requested.connect(func(text: String) -> void:
		print("barricade_probe_message=%s" % text)
	)
	player.interaction_prompt_changed.connect(func(text: String) -> void:
		print("barricade_probe_prompt=%s" % text)
	)

	player.global_position = grid.to_global(Vector2(tactical_cell.x * grid.cell_size.x, tactical_cell.y * grid.cell_size.y))
	await _wait_frames()
	Input.action_press("build_mode")
	await physics_frame
	await process_frame
	Input.action_release("build_mode")
	await _wait_frames()

	Input.action_press("interact")
	await physics_frame
	await process_frame
	Input.action_release("interact")
	await _wait_frames()

	var placed_placeable = null
	if placeables_root.get_child_count() > 0:
		placed_placeable = placeables_root.get_child(0)

	print("barricade_probe_build_mode=%s" % str(player.is_build_mode_active()))
	print("barricade_probe_placeables=%d" % placeables_root.get_child_count())
	print("barricade_probe_cell_occupied=%s" % str(grid.is_cell_occupied(tactical_cell)))
	print("barricade_probe_salvage_before=%d" % starting_salvage)
	print("barricade_probe_salvage_after=%d" % int(player.resources.get("salvage", 0)))
	print("barricade_probe_placeable_id=%s" % str(placed_placeable.get_placeable_id() if placed_placeable != null else StringName()))
	print("barricade_probe_placeable_hp=%d" % int(placed_placeable.current_hp if placed_placeable != null else 0))
	if placed_placeable != null:
		placed_placeable.take_damage(12, null)
		await _wait_frames()
		print("barricade_probe_damaged_hp=%d" % int(placed_placeable.current_hp))
		await _press_action("build_mode")
		await _wait_frames()
		await _press_action("interact")
		await _wait_frames()
		print("barricade_probe_repaired_hp=%d" % int(placed_placeable.current_hp if is_instance_valid(placed_placeable) else 0))
		print("barricade_probe_salvage_after_repair=%d" % int(player.resources.get("salvage", 0)))
		await _press_action("build_mode")
		await _wait_frames()
		await _press_action_event("recycle")
		await _wait_frames()
		await _wait_frames()
		await _wait_frames()
		print("barricade_probe_placeables_after_recycle=%d" % placeables_root.get_child_count())
		print("barricade_probe_cell_occupied_after_recycle=%s" % str(grid.is_cell_occupied(tactical_cell)))
		print("barricade_probe_salvage_after_recycle=%d" % int(player.resources.get("salvage", 0)))
		await _press_action("build_mode")
		await _wait_frames()
		await _press_action_event("recycle")
		await _wait_frames()
		await _wait_frames()
		print("barricade_probe_placeables_after_outside_recycle=%d" % placeables_root.get_child_count())
		print("barricade_probe_cell_occupied_after_outside_recycle=%s" % str(grid.is_cell_occupied(tactical_cell)))
	quit()
