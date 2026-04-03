extends SceneTree


func _wait_frames(count: int) -> void:
	for _i in range(count):
		await process_frame
		await physics_frame


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	await _wait_frames(2)

	var player = game.player
	var player_audio = player.get_node("CombatAudio")

	var pickup_scene := load("res://scenes/world/ResourcePickup.tscn")
	var pickup = pickup_scene.instantiate()
	game.get_node("World/AmbientPickups").add_child(pickup)
	pickup.resource_id = "salvage"
	pickup.amount = 1
	pickup.global_position = player.global_position
	await _wait_frames(1)
	pickup.collect(player)
	await _wait_frames(1)
	print("interaction_audio_probe_pickup=%s" % str(player_audio.get_last_sound_id()))

	player.set_build_mode_active(true, false)
	var grid = game.construction_grid
	var build_cell := Vector2i(4, -1)
	grid.set_preview_world_position(grid.get_world_position_for_cell(build_cell))
	game.construction_controller.on_player_build_placement_requested()
	await _wait_frames(1)
	print("interaction_audio_probe_build=%s" % str(player_audio.get_last_sound_id()))

	var placeables_root = game.get_node("World/ConstructionPlaceables")
	print("interaction_audio_probe_placeables=%d" % placeables_root.get_child_count())
	var barricade = placeables_root.get_child(0)
	barricade.take_damage(12, {"attacker": player, "damage_type": &"impact"})
	await _wait_frames(1)
	barricade.interact(player)
	await _wait_frames(1)
	print("interaction_audio_probe_repair=%s" % str(player_audio.get_last_sound_id()))

	barricade.recycle(player)
	await _wait_frames(1)
	print("interaction_audio_probe_recycle=%s" % str(player_audio.get_last_sound_id()))

	var socket = game.defense_sockets.get_child(0)
	socket.current_hp = max(1, socket.current_hp - 10)
	socket.interact(player)
	await _wait_frames(1)
	print("interaction_audio_probe_socket_repair=%s" % str(player_audio.get_last_sound_id()))

	quit()
