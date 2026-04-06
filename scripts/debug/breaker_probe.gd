extends SceneTree

const GAME_SCENE := preload("res://scenes/main/Game.tscn")
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const PLACEABLE_SCENE := preload("res://scenes/world/Placeable.tscn")
const BREAKER_ENEMY := preload("res://data/enemies/zombie_breaker.tres")
const TURRET_PROFILE := preload("res://data/placeables/turret.tres")
const BARRICADE_PROFILE := preload("res://data/placeables/barricade.tres")
const HOME_POSITION := Vector2(1180.0, 720.0)


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


func _init() -> void:
	var game = GAME_SCENE.instantiate()
	root.add_child(game)
	await _wait_frames(4)

	var powered_turret = _spawn_placeable(game, TURRET_PROFILE, HOME_POSITION + Vector2(92.0, -20.0))
	var barricade = _spawn_placeable(game, BARRICADE_PROFILE, HOME_POSITION + Vector2(144.0, 36.0))
	await _wait_frames(12)

	var breaker = ENEMY_SCENE.instantiate()
	breaker.definition = BREAKER_ENEMY
	breaker.global_position = HOME_POSITION + Vector2(248.0, 0.0)
	game.wave_enemy_layer.add_child(breaker)
	breaker.configure_runtime_context(game.player, game.wave_enemy_layer, game.construction_placeables)
	breaker.configure_wave_context(game.player, [], PackedStringArray())
	await _wait_frames(8)

	var current_target = breaker.targeting_controller.get_current_target()
	print("breaker_probe_turret_powered=%s" % str(powered_turret.is_powered()))
	print("breaker_probe_target_is_powered_placeable=%s" % str(current_target == powered_turret))
	print("breaker_probe_target_not_barricade=%s" % str(current_target != barricade))

	game.queue_free()
	await _wait_frames(2)
	quit()
