extends SceneTree


func _wait_frames(frame_count: int = 1) -> void:
	for _index in range(frame_count):
		await process_frame
		await physics_frame
		await process_frame


func _press_action(action_name: StringName) -> void:
	Input.action_press(action_name)
	await physics_frame
	await process_frame
	Input.action_release(action_name)
	await process_frame


func _place_barricade(game, tactical_cell: Vector2i):
	var grid = game.construction_grid
	var player = game.player
	player.global_position = grid.to_global(Vector2(tactical_cell.x * grid.cell_size.x, tactical_cell.y * grid.cell_size.y))
	await _wait_frames(2)
	await _press_action("build_mode")
	await _wait_frames(2)
	print("barricade_attack_probe_player_cell=%s" % str(grid.get_cell_for_world_position(game.player.global_position)))
	print("barricade_attack_probe_preview_cell=%s" % str(grid.get_preview_cell()))
	print("barricade_attack_probe_preview_reason=%s" % str(grid.get_preview_reason()))
	await _press_action("interact")
	await _wait_frames(2)
	return game.construction_placeables.get_child(0) if game.construction_placeables.get_child_count() > 0 else null


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	game.enable_test_mode = true
	root.add_child(game)
	await _wait_frames(3)

	var barricade = await _place_barricade(game, Vector2i(-1, 3))
	if barricade == null:
		print("barricade_attack_probe_status=%s" % str(game.hud.status_label.text))
		print("barricade_attack_probe_placed=false")
		quit()
		return

	var enemy_scene := load("res://scenes/enemies/Enemy.tscn")
	var zombie = enemy_scene.instantiate()
	zombie.definition = load("res://data/enemies/zombie_basic.tres")
	game.wave_enemy_layer.add_child(zombie)
	zombie.global_position = barricade.global_position + Vector2(0.0, 14.0)
	zombie.configure_wave_context(null, [])
	await _wait_frames(40)

	print("barricade_attack_probe_placed=true")
	print("barricade_attack_probe_barricade_hp=%d" % int(barricade.current_hp))
	print("barricade_attack_probe_enemy_prep=%s" % str(zombie.is_attack_prep_armed()))
	print("barricade_attack_probe_enemy_target=%s" % str(zombie._get_current_target().get_placeable_id() if zombie._get_current_target() != null and zombie._get_current_target().has_method("get_placeable_id") else StringName()))
	quit()
