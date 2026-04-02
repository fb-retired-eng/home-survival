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


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game: Game = game_scene.instantiate() as Game
	game.enable_test_mode = true
	root.add_child(game)
	await _wait_frames()

	var grid: ConstructionGrid = game.construction_grid
	var player: Player = game.player
	var placeables_root: Node2D = game.construction_placeables
	var zombie_scene := load("res://scenes/enemies/Zombie.tscn")
	var tactical_cell := Vector2i(-2, 3)

	player.global_position = grid.to_global(Vector2(tactical_cell.x * grid.cell_size.x, tactical_cell.y * grid.cell_size.y))
	await _wait_frames()
	await _press_action("build_mode")
	await _wait_frames()
	await _press_action("build_next")
	await _wait_frames()
	await _press_action("build_rotate")
	await _wait_frames()
	await _press_action("interact")
	await _wait_frames()

	var trap: Node = placeables_root.get_child(placeables_root.get_child_count() - 1) if placeables_root.get_child_count() > 0 else null
	print("spike_trap_probe_placed=%s" % str(trap != null))
	print("spike_trap_probe_trap_id=%s" % str(trap.get_placeable_id() if trap != null and trap.has_method("get_placeable_id") else StringName()))
	print("spike_trap_probe_trap_rotation=%d" % int(trap.placement_rotation_steps if trap != null else -1))
	print("spike_trap_probe_trap_anchor_occupied=%s" % str(grid.is_cell_occupied(tactical_cell)))
	print("spike_trap_probe_trap_second_cell_occupied=%s" % str(grid.is_cell_occupied(Vector2i(-2, 4))))
	print("spike_trap_probe_trap_active=%s" % str(trap.is_trap_active() if trap != null and trap.has_method("is_trap_active") else false))

	var zombie: Zombie = zombie_scene.instantiate()
	zombie.definition = load("res://data/enemies/zombie_basic.tres")
	game.exploration_enemy_layer.add_child(zombie)
	zombie.global_position = trap.global_position if trap != null else grid.to_global(Vector2(tactical_cell.x * grid.cell_size.x, tactical_cell.y * grid.cell_size.y))
	zombie.set_physics_process(false)
	await _wait_frames()
	print("spike_trap_probe_zombie_in_group=%s" % str(zombie.is_in_group("enemies")))
	print("spike_trap_probe_trap_position=%s" % str(trap.global_position if trap != null else Vector2.ZERO))
	print("spike_trap_probe_zombie_position=%s" % str(zombie.global_position))

	var player_health_before := int(player.current_health)
	var health_before := int(zombie.current_health)
	var slow_before := float(zombie.get_slow_effect_multiplier())
	for _step in range(30):
		await _wait_frames()
	var health_after := int(zombie.current_health)
	var player_health_after := int(player.current_health)
	var slow_after := float(zombie.get_slow_effect_multiplier())
	print("spike_trap_probe_overlap_count=%d" % int(trap.get_trap_overlap_count() if trap != null and trap.has_method("get_trap_overlap_count") else -1))
	print("spike_trap_probe_player_health_before=%d" % player_health_before)
	print("spike_trap_probe_player_health_after=%d" % player_health_after)
	print("spike_trap_probe_health_before=%d" % health_before)
	print("spike_trap_probe_health_after=%d" % health_after)
	print("spike_trap_probe_slow_before=%.2f" % slow_before)
	print("spike_trap_probe_slow_after=%.2f" % slow_after)
	quit()
