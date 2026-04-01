extends SceneTree


func _get_fill_width(enemy) -> float:
	var polygon: PackedVector2Array = enemy.get_node("HealthBarFill").polygon
	if polygon.size() < 2:
		return 0.0
	return polygon[1].x - polygon[0].x


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
	var zombie_scene := load("res://scenes/enemies/Zombie.tscn")
	var knife := load("res://data/weapons/kitchen_knife.tres")

	var player = player_scene.instantiate()
	var enemy = zombie_scene.instantiate()
	root.add_child(player)
	root.add_child(enemy)
	await _wait_frames()

	player.global_position = Vector2(200, 200)
	player.facing_direction = Vector2.RIGHT
	player._update_facing_visuals()
	player.obtain_weapon(knife, true, false)
	enemy.global_position = Vector2(224, 200)
	await _wait_frames()

	var width_before := _get_fill_width(enemy)
	print("enemy_health_bar_probe_visible_before=%s" % str(enemy.get_node("HealthBarFill").visible))
	print("enemy_health_bar_probe_width_before=%.2f" % width_before)

	await _trigger_attack_input()
	await _wait_for_attack_resolution(player)

	var width_after := _get_fill_width(enemy)
	print("enemy_health_bar_probe_health_after=%d" % int(enemy.current_health))
	print("enemy_health_bar_probe_visible_after=%s" % str(enemy.get_node("HealthBarFill").visible))
	print("enemy_health_bar_probe_width_after=%.2f" % width_after)
	quit()
