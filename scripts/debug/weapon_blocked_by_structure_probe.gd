extends SceneTree


func _wait_frames() -> void:
	await process_frame
	await physics_frame
	await process_frame


func _trigger_attack_input() -> void:
	Input.action_press("attack")
	await physics_frame
	await process_frame
	Input.action_release("attack")
	await process_frame


func _wait_for_attack_resolution(player) -> void:
	for _step in range(180):
		await physics_frame
		await process_frame
		if not player._attack_windup_pending and player.attack_cooldown_remaining > 0.0:
			return


func _get_enemy_health_or_zero(enemy) -> int:
	if enemy == null or not is_instance_valid(enemy):
		return 0
	return int(enemy.current_health)


func _spawn_enemy(root_node: Node, definition_path: String, position: Vector2, player) -> Node:
	var enemy_scene = load("res://scenes/enemies/Enemy.tscn")
	var enemy = enemy_scene.instantiate()
	enemy.definition = load(definition_path)
	root_node.add_child(enemy)
	enemy.global_position = position
	enemy.configure_exploration_context(player, Vector2.DOWN, true, position, true)
	return enemy


func _get_socket(game, target_socket_id: StringName):
	for child in game.defense_sockets.get_children():
		if StringName(child.socket_id) == target_socket_id:
			return child
	return null


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var bat := load("res://data/weapons/baseball_bat.tres")
	var pistol := load("res://data/weapons/pistol.tres")
	var game = game_scene.instantiate()
	root.add_child(game)
	await _wait_frames()

	game.exploration_controller.clear_exploration_enemies()
	await _wait_frames()

	var wall_n = _get_socket(game, &"wall_n")
	var door_e = _get_socket(game, &"door_e")
	var player = game.player

	player.obtain_weapon(bat, true, false)
	player.global_position = wall_n.global_position + Vector2(0, 24)
	player.facing_direction = Vector2.UP
	player._update_facing_visuals()
	var wall_enemy = _spawn_enemy(game.exploration_enemy_layer, "res://data/enemies/zombie_basic.tres", wall_n.global_position + Vector2(0, -24), player)
	await _wait_frames()
	await _trigger_attack_input()
	await _wait_for_attack_resolution(player)
	print("weapon_blocked_by_structure_probe_wall_blocked_bat_health=%d" % int(wall_enemy.current_health))
	player.attack_cooldown_remaining = 0.0
	wall_enemy.queue_free()
	await _wait_frames()

	player.global_position = Vector2(800, 800)
	player.facing_direction = Vector2.UP
	player._update_facing_visuals()
	var open_bat_enemy = _spawn_enemy(game.exploration_enemy_layer, "res://data/enemies/zombie_basic.tres", Vector2(800, 752), player)
	await _wait_frames()
	await _trigger_attack_input()
	await _wait_for_attack_resolution(player)
	print("weapon_blocked_by_structure_probe_open_bat_health=%d" % _get_enemy_health_or_zero(open_bat_enemy))
	player.attack_cooldown_remaining = 0.0
	if is_instance_valid(open_bat_enemy):
		open_bat_enemy.queue_free()
	await _wait_frames()

	player.obtain_weapon(pistol, true, false)
	player.add_resource("bullets", 6, false)
	player.global_position = door_e.global_position + Vector2(-24, 0)
	player.facing_direction = Vector2.RIGHT
	player._update_facing_visuals()
	var door_enemy = _spawn_enemy(game.exploration_enemy_layer, "res://data/enemies/zombie_basic.tres", door_e.global_position + Vector2(24, 0), player)
	await _wait_frames()
	await _trigger_attack_input()
	await _wait_for_attack_resolution(player)
	print("weapon_blocked_by_structure_probe_door_blocked_pistol_health=%d" % _get_enemy_health_or_zero(door_enemy))
	player.attack_cooldown_remaining = 0.0
	if is_instance_valid(door_enemy):
		door_enemy.queue_free()
	await _wait_frames()

	player.global_position = Vector2(900, 900)
	player.facing_direction = Vector2.RIGHT
	player._update_facing_visuals()
	var open_pistol_enemy = _spawn_enemy(game.exploration_enemy_layer, "res://data/enemies/zombie_basic.tres", Vector2(960, 900), player)
	await _wait_frames()
	await _trigger_attack_input()
	await _wait_for_attack_resolution(player)
	print("weapon_blocked_by_structure_probe_open_pistol_health=%d" % _get_enemy_health_or_zero(open_pistol_enemy))
	quit()
