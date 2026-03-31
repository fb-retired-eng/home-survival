extends SceneTree


func _damage_taken(socket, amount: int) -> int:
	var before_hp := int(socket.current_hp)
	socket.take_damage(amount, {"damage_type": &"impact"})
	return before_hp - int(socket.current_hp)


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var template_socket = game.get_tree().get_first_node_in_group("defense_sockets")
	var damaged_socket = template_socket
	var reinforced_socket = template_socket.duplicate()
	var fortified_socket = template_socket.duplicate()
	game.defense_sockets.add_child(reinforced_socket)
	game.defense_sockets.add_child(fortified_socket)
	reinforced_socket.position += Vector2(120.0, 0.0)
	fortified_socket.position += Vector2(240.0, 0.0)
	await process_frame

	damaged_socket.tier = "damaged"
	damaged_socket.current_hp = damaged_socket._get_max_hp_for_tier("damaged")
	damaged_socket._refresh_visuals()

	reinforced_socket.tier = "reinforced"
	reinforced_socket.current_hp = reinforced_socket._get_max_hp_for_tier("reinforced")
	reinforced_socket._refresh_visuals()

	fortified_socket.tier = "fortified"
	fortified_socket.current_hp = fortified_socket._get_max_hp_for_tier("fortified")
	fortified_socket._refresh_visuals()

	print("fortified_mitigation_probe_damaged=%d" % _damage_taken(damaged_socket, 20))
	print("fortified_mitigation_probe_reinforced=%d" % _damage_taken(reinforced_socket, 20))
	print("fortified_mitigation_probe_fortified=%d" % _damage_taken(fortified_socket, 20))
	quit()
