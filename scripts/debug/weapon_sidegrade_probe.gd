extends SceneTree


func _spawn_enemy(root_node: Node, definition_path: String, position: Vector2):
	var zombie_scene = load("res://scenes/enemies/Zombie.tscn")
	var enemy = zombie_scene.instantiate()
	enemy.definition = load(definition_path)
	root_node.add_child(enemy)
	enemy.global_position = position
	return enemy


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


func _init() -> void:
	var player_scene := load("res://scenes/player/Player.tscn")
	var knife := load("res://data/weapons/kitchen_knife.tres")
	var bat := load("res://data/weapons/baseball_bat.tres")
	var pistol := load("res://data/weapons/pistol.tres")
	var shotgun := load("res://data/weapons/shotgun.tres")

	var player = player_scene.instantiate()
	root.add_child(player)
	await _wait_frames()

	player.global_position = Vector2(200, 200)
	player.facing_direction = Vector2.RIGHT
	player._update_facing_visuals()

	var knife_isolated_enemy = _spawn_enemy(root, "res://data/enemies/zombie_basic.tres", Vector2(224, 200))
	await _wait_frames()
	player.obtain_weapon(knife, true, false)
	await _trigger_attack_input()
	await _wait_for_attack_resolution(player)
	print("weapon_sidegrade_probe_knife_isolated_health=%d" % int(knife_isolated_enemy.current_health))
	player.attack_cooldown_remaining = 0.0
	knife_isolated_enemy.queue_free()
	await _wait_frames()

	var knife_group_enemy_a = _spawn_enemy(root, "res://data/enemies/zombie_basic.tres", Vector2(224, 194))
	var knife_group_enemy_b = _spawn_enemy(root, "res://data/enemies/zombie_basic.tres", Vector2(224, 210))
	await _wait_frames()
	await _trigger_attack_input()
	await _wait_for_attack_resolution(player)
	print("weapon_sidegrade_probe_knife_group_health_a=%d" % int(knife_group_enemy_a.current_health))
	print("weapon_sidegrade_probe_knife_group_health_b=%d" % int(knife_group_enemy_b.current_health))
	player.attack_cooldown_remaining = 0.0
	knife_group_enemy_a.queue_free()
	knife_group_enemy_b.queue_free()
	await _wait_frames()

	var bat_enemy = _spawn_enemy(root, "res://data/enemies/zombie_brute.tres", Vector2(236, 200))
	await _wait_frames()
	bat_enemy.configure_exploration_context(player, Vector2.LEFT, true, bat_enemy.global_position, true)
	await _wait_frames()
	for _step in range(30):
		await physics_frame
		await process_frame
		if bat_enemy.is_attack_prep_armed():
			break
	player.obtain_weapon(bat, true, false)
	print("weapon_sidegrade_probe_bat_prep_before=%s" % str(bat_enemy.is_attack_prep_armed()))
	await _trigger_attack_input()
	await _wait_for_attack_resolution(player)
	print("weapon_sidegrade_probe_bat_prep_after=%s" % str(bat_enemy.is_attack_prep_armed()))
	print("weapon_sidegrade_probe_bat_health=%d" % int(bat_enemy.current_health))
	player.attack_cooldown_remaining = 0.0
	bat_enemy.queue_free()
	await _wait_frames()

	var pistol_enemy = _spawn_enemy(root, "res://data/enemies/zombie_brute.tres", Vector2(236, 200))
	await _wait_frames()
	pistol_enemy.configure_exploration_context(player, Vector2.LEFT, true, pistol_enemy.global_position, true)
	await _wait_frames()
	for _step in range(30):
		await physics_frame
		await process_frame
		if pistol_enemy.is_attack_prep_armed():
			break
	player.obtain_weapon(pistol, true, false)
	print("weapon_sidegrade_probe_pistol_prep_before=%s" % str(pistol_enemy.is_attack_prep_armed()))
	await _trigger_attack_input()
	await _wait_for_attack_resolution(player)
	print("weapon_sidegrade_probe_pistol_prep_after=%s" % str(pistol_enemy.is_attack_prep_armed()))
	print("weapon_sidegrade_probe_pistol_health=%d" % int(pistol_enemy.current_health))
	player.attack_cooldown_remaining = 0.0
	pistol_enemy.queue_free()
	await _wait_frames()

	player.obtain_weapon(shotgun, true, false)
	player.add_resource("bullets", 4, false)
	var shotgun_enemy_a = _spawn_enemy(root, "res://data/enemies/zombie_basic.tres", Vector2(300, 190))
	var shotgun_enemy_b = _spawn_enemy(root, "res://data/enemies/zombie_basic.tres", Vector2(308, 222))
	await _wait_frames()
	await _trigger_attack_input()
	await _wait_for_attack_resolution(player)
	print("weapon_sidegrade_probe_shotgun_health_a=%d" % int(shotgun_enemy_a.current_health))
	print("weapon_sidegrade_probe_shotgun_health_b=%d" % int(shotgun_enemy_b.current_health))
	print("weapon_sidegrade_probe_shotgun_target_count=%d" % player._get_attack_targets_for_weapon(shotgun).size())
	quit()
