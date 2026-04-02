extends SceneTree


func _wait_frames() -> void:
	await process_frame
	await physics_frame
	await process_frame


func _toggle_build_mode() -> void:
	Input.action_press("build_mode")
	await physics_frame
	await process_frame
	Input.action_release("build_mode")
	await process_frame


func _press_attack() -> void:
	Input.action_press("attack")
	await physics_frame
	await process_frame
	Input.action_release("attack")
	await process_frame


func _press_reload() -> void:
	Input.action_press("reload_weapon")
	await physics_frame
	await process_frame
	Input.action_release("reload_weapon")
	await process_frame


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	await _wait_frames()

	var grid = game.construction_grid
	var player = game.player
	var pistol := load("res://data/weapons/pistol.tres")

	player.global_position = grid.to_global(Vector2(4.0 * grid.cell_size.x, 3.0 * grid.cell_size.y))
	await _wait_frames()
	await _toggle_build_mode()
	await _wait_frames()

	print("construction_grid_probe_active=%s" % str(player.is_build_mode_active()))
	print("construction_grid_probe_preview_visible=%s" % str(grid.preview.visible))
	print("construction_grid_probe_reserved_reason=%s" % grid.get_preview_reason())
	print("construction_grid_probe_sleep_occupied=%s" % str(grid.is_cell_occupied(Vector2i(5, 3))))
	print("construction_grid_probe_table_occupied=%s" % str(grid.is_cell_occupied(Vector2i(3, 3))))
	print("construction_grid_probe_wall_n_occupied=%s" % str(grid.is_cell_occupied(Vector2i(4, 0))))
	print("construction_grid_probe_door_w_occupied=%s" % str(grid.is_cell_occupied(Vector2i(0, 3))))

	player.global_position = grid.to_global(Vector2(-20.0 * grid.cell_size.x, -10.0 * grid.cell_size.y))
	await _wait_frames()

	print("construction_grid_probe_map_in_bounds=%s" % str(grid.is_cell_in_bounds(grid.get_preview_cell())))
	print("construction_grid_probe_map_blocked_reason=%s" % grid.get_preview_reason())
	print("construction_grid_probe_map_blocked_cell=%s" % str(grid.get_preview_cell()))

	player.global_position = grid.to_global(Vector2(40.0 * grid.cell_size.x, 40.0 * grid.cell_size.y))
	await _wait_frames()

	print("construction_grid_probe_offgrid_reason=%s" % grid.get_preview_reason())
	print("construction_grid_probe_offgrid_cell=%s" % str(grid.get_preview_cell()))

	player.global_position = grid.to_global(Vector2(4.0 * grid.cell_size.x, -1.0 * grid.cell_size.y))
	await _wait_frames()

	print("construction_grid_probe_valid_reason=%s" % grid.get_preview_reason())
	print("construction_grid_probe_valid_cell=%s" % str(grid.get_preview_cell()))
	print("construction_grid_probe_valid_tactical=%s" % str(grid.is_cell_tactical(grid.get_preview_cell())))

	player.global_position = grid.to_global(Vector2(12.0 * grid.cell_size.x, 12.0 * grid.cell_size.y))
	await _wait_frames()
	print("construction_grid_probe_non_buildable_reason=%s" % grid.get_preview_reason())
	print("construction_grid_probe_non_buildable_cell=%s" % str(grid.get_preview_cell()))
	print("construction_grid_probe_non_buildable_tactical=%s" % str(grid.is_cell_tactical(grid.get_preview_cell())))

	player.global_position = grid.to_global(Vector2(-2.0 * grid.cell_size.x, 3.0 * grid.cell_size.y))
	await _wait_frames()
	print("construction_grid_probe_expanded_valid_reason=%s" % grid.get_preview_reason())
	print("construction_grid_probe_expanded_valid_cell=%s" % str(grid.get_preview_cell()))
	print("construction_grid_probe_expanded_valid_tactical=%s" % str(grid.is_cell_tactical(grid.get_preview_cell())))

	player.global_position = grid.to_global(Vector2(-2.0 * grid.cell_size.x, -2.0 * grid.cell_size.y))
	await _wait_frames()
	print("construction_grid_probe_corner_reason=%s" % grid.get_preview_reason())
	print("construction_grid_probe_corner_cell=%s" % str(grid.get_preview_cell()))
	print("construction_grid_probe_corner_reserved=%s" % str(grid.is_cell_reserved(grid.get_preview_cell())))
	print("construction_grid_probe_corner_valid=%s" % str(grid.is_cell_valid_for_basic_placeable(grid.get_preview_cell())))
	print("construction_grid_probe_corner_buffer=%s" % str(grid.would_trap_player_local(grid.get_preview_cell(), [Vector2i(-1, -2), Vector2i(-2, -1)], 2)))

	var wall_n = _find_defense_socket(game, &"wall_n")
	if wall_n == null:
		push_error("wall_n defense socket not found")
		quit(1)
		return
	wall_n.take_damage(10000)
	await _wait_frames()
	print("construction_grid_probe_wall_n_breached=%s" % str(wall_n.is_breached()))
	print("construction_grid_probe_wall_n_cleared=%s" % str(not grid.is_cell_occupied(Vector2i(4, 0))))

	await _toggle_build_mode()
	await _wait_frames()
	print("construction_grid_probe_inactive=%s" % str(not player.is_build_mode_active()))

	await _toggle_build_mode()
	await _wait_frames()
	game.game_manager.reset_run()
	await _wait_frames()
	print("construction_grid_probe_reset_closed=%s" % str(not player.is_build_mode_active()))

	await _press_attack()
	await _toggle_build_mode()
	await _wait_frames()
	print("construction_grid_probe_attack_blocked=%s" % str(not player.is_build_mode_active()))
	player.attack_cooldown_remaining = 0.0

	player.obtain_weapon(pistol, true, false)
	player._set_weapon_magazine_ammo(pistol, 1)
	player.add_resource("bullets", 6, false)
	await _press_reload()
	await _toggle_build_mode()
	await _wait_frames()
	print("construction_grid_probe_reload_blocked=%s" % str(not player.is_build_mode_active()))
	player._cancel_reload()

	game._on_food_table_requested(player)
	await _wait_frames()
	game.game_manager.set_run_state(game.game_manager.RunState.ACTIVE_WAVE)
	await _wait_frames()
	if player.is_build_mode_active():
		await _toggle_build_mode()
		await _wait_frames()
	await _toggle_build_mode()
	await _wait_frames()
	print("construction_grid_probe_active_stage_build_mode=%s" % str(player.is_build_mode_active()))
	await _toggle_build_mode()
	await _wait_frames()
	print("construction_grid_probe_active_stage_status=%s" % str(game.hud.status_label.text))
	game.game_manager.set_run_state(game.game_manager.RunState.POST_WAVE)
	await _wait_frames()
	print("construction_grid_probe_post_stage_persist=%s" % str(player.is_build_mode_active()))
	if player.is_build_mode_active():
		await _toggle_build_mode()
		await _wait_frames()
	await _toggle_build_mode()
	await _wait_frames()
	print("construction_grid_probe_post_stage_build_mode=%s" % str(player.is_build_mode_active()))
	await _toggle_build_mode()
	await _wait_frames()
	print("construction_grid_probe_post_stage_status=%s" % str(game.hud.status_label.text))
	quit()


func _find_defense_socket(game, socket_id: StringName):
	for socket in game.defense_sockets.get_children():
		if not is_instance_valid(socket):
			continue
		if StringName(socket.socket_id) == socket_id:
			return socket
	return null
