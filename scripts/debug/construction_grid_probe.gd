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

	player.global_position = grid.to_global(Vector2(12.0 * grid.cell_size.x, 12.0 * grid.cell_size.y))
	await _wait_frames()

	print("construction_grid_probe_offgrid_reason=%s" % grid.get_preview_reason())
	print("construction_grid_probe_offgrid_cell=%s" % str(grid.get_preview_cell()))

	player.global_position = grid.to_global(Vector2(4.0 * grid.cell_size.x, -1.0 * grid.cell_size.y))
	await _wait_frames()

	print("construction_grid_probe_valid_reason=%s" % grid.get_preview_reason())
	print("construction_grid_probe_valid_cell=%s" % str(grid.get_preview_cell()))

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
	await _toggle_build_mode()
	await _wait_frames()
	print("construction_grid_probe_night_blocked=%s" % str(not player.is_build_mode_active()))
	quit()
