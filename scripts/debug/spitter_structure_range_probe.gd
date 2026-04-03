extends SceneTree


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var enemy_scene := load("res://scenes/enemies/Enemy.tscn")
	var spitter_definition := load("res://data/enemies/zombie_spitter.tres")
	var game = game_scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var socket = game.get_tree().get_first_node_in_group("defense_sockets")
	socket.global_position = Vector2(340.0, 100.0)

	var zombie = enemy_scene.instantiate()
	game.wave_enemy_layer.add_child(zombie)
	zombie.definition = spitter_definition
	zombie.global_position = Vector2(100.0, 100.0)
	zombie.configure_wave_context(null, [socket], PackedStringArray([String(socket.socket_id)]))
	await process_frame

	print("spitter_structure_range_probe_far=%s" % str(zombie._is_target_in_damage_range(socket)))

	zombie.global_position = Vector2(258.0, 100.0)
	await process_frame
	print("spitter_structure_range_probe_near=%s" % str(zombie._is_target_in_damage_range(socket)))
	quit()
