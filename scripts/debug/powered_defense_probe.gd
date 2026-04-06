extends SceneTree

const GAME_SCENE := preload("res://scenes/main/Game.tscn")
const PLACEABLE_SCENE := preload("res://scenes/world/Placeable.tscn")
const TURRET_PROFILE := preload("res://data/placeables/turret.tres")
const FLOODLIGHT_PROFILE := preload("res://data/placeables/floodlight.tres")
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const BASIC_ENEMY := preload("res://data/enemies/zombie_basic.tres")
const HOME_POSITION := Vector2(1280.0, 720.0)


func _wait_frames(count: int = 1) -> void:
	for _i in range(count):
		await process_frame
		await physics_frame
		await process_frame


func _spawn_placeable(game, profile: Resource, position: Vector2):
	var placeable = PLACEABLE_SCENE.instantiate()
	placeable.profile = profile
	placeable.global_position = position
	game.construction_placeables.add_child(placeable)
	return placeable


func _spawn_enemy(game, position: Vector2):
	var enemy = ENEMY_SCENE.instantiate()
	enemy.definition = BASIC_ENEMY
	enemy.global_position = position
	game.wave_enemy_layer.add_child(enemy)
	return enemy


func _count_defeated(enemies: Array) -> int:
	var defeated := 0
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			defeated += 1
			continue
		if int(enemy.current_health) <= 0:
			defeated += 1
	return defeated


func _average_slow_multiplier(enemies: Array) -> float:
	var total := 0.0
	var count := 0
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		total += float(enemy.get_slow_effect_multiplier())
		count += 1
	if count <= 0:
		return 1.0
	return total / float(count)


func _total_remaining_health(enemies: Array) -> int:
	var total := 0
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		total += int(enemy.current_health)
	return total


func _init() -> void:
	var game = GAME_SCENE.instantiate()
	root.add_child(game)
	await _wait_frames(4)
	game.mvp2_run_controller.active_mutator_id = StringName()

	game.player.add_resource("bullets", 24, false)

	var turret = _spawn_placeable(game, TURRET_PROFILE, HOME_POSITION + Vector2(92.0, -18.0))
	var floodlight = _spawn_placeable(game, FLOODLIGHT_PROFILE, HOME_POSITION + Vector2(-88.0, -18.0))
	await _wait_frames(12)

	var turret_enemies: Array = []
	for offset in [Vector2(116.0, -10.0), Vector2(136.0, 18.0), Vector2(148.0, -28.0)]:
		turret_enemies.append(_spawn_enemy(game, turret.global_position + offset))

	var floodlight_enemies: Array = []
	for offset in [Vector2(-136.0, -8.0), Vector2(-152.0, 16.0), Vector2(-168.0, -20.0)]:
		floodlight_enemies.append(_spawn_enemy(game, floodlight.global_position + offset))

	var bullets_before := int(game.player.resources.get("bullets", 0))
	await _wait_frames(72)
	var bullets_after := int(game.player.resources.get("bullets", 0))

	print("powered_defense_probe_turret_powered=%s" % str(turret.is_powered()))
	print("powered_defense_probe_floodlight_powered=%s" % str(floodlight.is_powered()))
	print("powered_defense_probe_bullets_spent=%d" % (bullets_before - bullets_after))
	print("powered_defense_probe_turret_defeated=%d" % _count_defeated(turret_enemies))
	print("powered_defense_probe_turret_total_remaining_health=%d" % _total_remaining_health(turret_enemies))
	print("powered_defense_probe_floodlight_avg_slow=%.2f" % _average_slow_multiplier(floodlight_enemies))
	print("powered_defense_probe_power_label=%s" % str(game.hud.power_label.text))

	game.queue_free()
	await _wait_frames(2)
	quit()
