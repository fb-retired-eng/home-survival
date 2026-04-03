extends SceneTree


func _wait_frames() -> void:
	await process_frame
	await physics_frame
	await process_frame


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var enemy_scene := load("res://scenes/enemies/Enemy.tscn")
	var pistol := load("res://data/weapons/pistol.tres")

	var game = game_scene.instantiate()
	root.add_child(game)
	await _wait_frames()

	var player = game.player
	player.set_build_mode_active(true, false)
	await _wait_frames()
	print("actor_visual_probe_build_ring=%s" % str(player.get_node("StateRing").visible))

	player.set_build_mode_active(false, false)
	player.obtain_weapon(pistol, true, false)
	player.add_resource("bullets", 6, false)
	player._set_weapon_magazine_ammo(pistol, 0)
	player._attempt_reload(false)
	await _wait_frames()
	print("actor_visual_probe_reload_ring=%s" % str(player.get_node("StateRing").visible))

	var zombie = enemy_scene.instantiate()
	game.exploration_enemy_layer.add_child(zombie)
	zombie.global_position = player.global_position + Vector2(64.0, 0.0)
	zombie.configure_runtime_context(player, game.exploration_enemy_layer, game.construction_placeables)
	zombie.configure_exploration_context(player)
	await _wait_frames()

	zombie.receive_noise_alert(player, player.global_position + Vector2(120.0, 0.0))
	await _wait_frames()
	print("actor_visual_probe_enemy_noise_indicator=%s" % str(zombie.get_node("StateIndicator").visible))

	zombie.take_damage(5, {"attacker": player})
	await _wait_frames()
	print("actor_visual_probe_enemy_health_bar=%s" % str(zombie.get_node("VisualRoot/HealthBarBackground").visible))

	game.queue_free()
	await _wait_frames()
	quit()
