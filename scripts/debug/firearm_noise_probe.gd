extends SceneTree


func _count_investigating(game) -> int:
	var count := 0
	for child in game.exploration_enemy_layer.get_children():
		if not is_instance_valid(child):
			continue
		if child.is_queued_for_deletion():
			continue
		if child.has_method("is_investigating_noise") and child.is_investigating_noise():
			count += 1
	return count


func _clear_exploration_layer(game) -> void:
	game._clear_exploration_enemies()
	await process_frame
	await physics_frame
	await process_frame


func _spawn_probe_enemy(game, definition: Resource, offset: Vector2) -> void:
	var enemy = game.exploration_enemy_scene.instantiate()
	enemy.definition = definition
	game.exploration_enemy_layer.add_child(enemy)
	enemy.global_position = game.player.global_position + offset
	enemy.configure_exploration_context(game.player, Vector2.RIGHT, true, enemy.global_position, true)


func _setup_probe_enemies(game) -> void:
	var basic := load("res://data/enemies/zombie_basic.tres")
	var runner := load("res://data/enemies/zombie_runner.tres")
	var spitter := load("res://data/enemies/zombie_spitter.tres")
	_spawn_probe_enemy(game, basic, Vector2(60.0, 0.0))
	_spawn_probe_enemy(game, runner, Vector2(80.0, 0.0))
	_spawn_probe_enemy(game, spitter, Vector2(100.0, 0.0))
	_spawn_probe_enemy(game, basic, Vector2(120.0, 0.0))
	_spawn_probe_enemy(game, basic, Vector2(140.0, 0.0))
	await process_frame
	await physics_frame
	await process_frame


func _setup_open_radius_probe_enemies(game) -> void:
	var basic := load("res://data/enemies/zombie_basic.tres")
	_spawn_probe_enemy(game, basic, Vector2(150.0, -120.0))
	_spawn_probe_enemy(game, basic, Vector2(210.0, -120.0))
	await process_frame
	await physics_frame
	await process_frame


func _fire_weapon_noise_through_player(game, weapon: Resource) -> void:
	game.player.obtain_weapon(weapon, true, false)
	game.player._commit_attack(weapon)
	await process_frame
	await physics_frame
	await process_frame


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	game.player.global_position = Vector2(1280.0, 720.0)

	var pistol := load("res://data/weapons/pistol.tres")
	var shotgun := load("res://data/weapons/shotgun.tres")

	await _clear_exploration_layer(game)
	await _setup_probe_enemies(game)
	await _fire_weapon_noise_through_player(game, pistol)
	print("firearm_noise_probe_pistol_investigating=%d" % _count_investigating(game))

	await _clear_exploration_layer(game)
	await _setup_probe_enemies(game)
	await _fire_weapon_noise_through_player(game, shotgun)
	print("firearm_noise_probe_shotgun_investigating=%d" % _count_investigating(game))

	await _clear_exploration_layer(game)
	var basic := load("res://data/enemies/zombie_basic.tres")
	var spitter := load("res://data/enemies/zombie_spitter.tres")
	_spawn_probe_enemy(game, spitter, Vector2(60.0, 0.0))
	_spawn_probe_enemy(game, basic, Vector2(80.0, 0.0))
	_spawn_probe_enemy(game, basic, Vector2(100.0, 0.0))
	await process_frame
	await physics_frame
	await process_frame
	game._on_player_weapon_noise_emitted(game.player.global_position, 160.0, 1.5, &"probe")
	await process_frame
	await physics_frame
	await process_frame
	print("firearm_noise_probe_budget_skip_investigating=%d" % _count_investigating(game))

	await _clear_exploration_layer(game)
	await _setup_open_radius_probe_enemies(game)
	await _fire_weapon_noise_through_player(game, pistol)
	print("firearm_noise_probe_open_pistol_investigating=%d" % _count_investigating(game))

	await _clear_exploration_layer(game)
	await _setup_open_radius_probe_enemies(game)
	await _fire_weapon_noise_through_player(game, shotgun)
	print("firearm_noise_probe_open_shotgun_investigating=%d" % _count_investigating(game))

	await process_frame
	await physics_frame
	await create_timer(3.3).timeout
	await process_frame
	print("firearm_noise_probe_after_timeout_investigating=%d" % _count_investigating(game))
	quit()
