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
	game.exploration_enemy_layer.add_child(enemy)
	return enemy


func _init() -> void:
	var game = GAME_SCENE.instantiate()
	root.add_child(game)
	await _wait_frames(4)

	var near_turret = _spawn_placeable(game, TURRET_PROFILE, HOME_POSITION + Vector2(96.0, -24.0))
	var floodlight = _spawn_placeable(game, FLOODLIGHT_PROFILE, HOME_POSITION + Vector2(-96.0, -24.0))
	var far_turret = _spawn_placeable(game, TURRET_PROFILE, HOME_POSITION + Vector2(360.0, 0.0))
	await _wait_frames(12)

	print("power_probe_near_turret_powered=%s" % str(near_turret.is_powered()))
	print("power_probe_floodlight_powered=%s" % str(floodlight.is_powered()))
	print("power_probe_far_turret_powered=%s" % str(far_turret.is_powered()))
	print("power_probe_hud_label=%s" % str(game.hud.power_label.text))

	var turret_enemy = _spawn_enemy(game, near_turret.global_position + Vector2(72.0, 0.0))
	var floodlight_enemy = _spawn_enemy(game, floodlight.global_position + Vector2(48.0, 0.0))
	await _wait_frames(36)

	print("power_probe_turret_enemy_health=%d" % int(turret_enemy.current_health))
	print("power_probe_floodlight_enemy_slow=%.2f" % float(floodlight_enemy.get_slow_effect_multiplier()))

	game.queue_free()
	await _wait_frames(2)
	quit()
