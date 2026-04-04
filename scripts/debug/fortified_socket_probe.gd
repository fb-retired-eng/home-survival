extends SceneTree


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	game.player.add_resource("salvage", 30, false)
	game.player.add_resource("parts", 12, false)
	await process_frame

	var socket = game.get_tree().get_first_node_in_group("defense_sockets")
	print("fortified_socket_probe_initial_tier=%s" % socket.tier)
	print("fortified_socket_probe_initial_hp=%d" % socket.current_hp)

	socket.interact(game.player)
	await process_frame
	print("fortified_socket_probe_after_strengthen_tier=%s" % socket.tier)
	print("fortified_socket_probe_after_strengthen_hp=%d" % socket.current_hp)

	socket.interact(game.player)
	await process_frame
	print("fortified_socket_probe_after_fortify_tier=%s" % socket.tier)
	print("fortified_socket_probe_after_fortify_hp=%d" % socket.current_hp)

	socket.take_damage(999)
	await process_frame
	print("fortified_socket_probe_breached=%s" % str(socket.is_breached()))

	game.game_manager.set_run_state(game.game_manager.RunState.LOSS)
	await process_frame
	game.game_manager.reset_run()
	await process_frame
	await physics_frame
	await process_frame

	var reset_socket = game.get_tree().get_first_node_in_group("defense_sockets")
	print("fortified_socket_probe_heirloom_active=%s" % str(reset_socket.has_heirloom_debris()))
	print("fortified_socket_probe_heirloom_hp=%d" % int(reset_socket.max_hp))
	print("fortified_socket_probe_heirloom_label=%s" % str(reset_socket.get_interaction_label(game.player)))
	quit()
