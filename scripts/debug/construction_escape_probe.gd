extends SceneTree


func _wait_frames() -> void:
	await process_frame
	await physics_frame
	await process_frame


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	await _wait_frames()

	var player_cell: Vector2i = game.construction_grid.get_cell_for_world_position(game.player.global_position)
	var west_footprint := [Vector2i(-1, 3)]
	var east_footprint := [Vector2i(9, 3)]
	var both_footprints := [Vector2i(-1, 3), Vector2i(9, 3)]
	var synthetic_player_cell := Vector2i(0, 0)
	var synthetic_one_side := [Vector2i(1, 0)]
	var synthetic_two_side := [Vector2i(1, 0), Vector2i(-1, 0)]
	var synthetic_same_cell := [Vector2i(0, 0)]

	print("construction_escape_probe_west_only=%s" % str(game._would_block_all_door_routes(west_footprint)))
	print("construction_escape_probe_east_only=%s" % str(game._would_block_all_door_routes(east_footprint)))
	print("construction_escape_probe_both=%s" % str(game.construction_grid.would_trap_player_local(player_cell, both_footprints, 2)))
	print("construction_escape_probe_synth_one=%s" % str(game.construction_grid.would_trap_player_local(synthetic_player_cell, synthetic_one_side, 2)))
	print("construction_escape_probe_synth_two=%s" % str(game.construction_grid.would_trap_player_local(synthetic_player_cell, synthetic_two_side, 2)))
	print("construction_escape_probe_synth_same=%s" % str(game.construction_grid.would_trap_player_local(synthetic_player_cell, synthetic_same_cell, 2)))
	quit()
