extends SceneTree

const GAME_SCENE := preload("res://scenes/main/Game.tscn")
const FLOODLIGHT_PROFILE := preload("res://data/placeables/floodlight.tres")
const BASIC_ENEMY := preload("res://data/enemies/zombie_basic.tres")
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const PLACEABLE_SCENE := preload("res://scenes/world/Placeable.tscn")
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


func _init() -> void:
	var game = GAME_SCENE.instantiate()
	root.add_child(game)
	await _wait_frames(4)

	game.mvp2_run_controller.generate_day_state()
	var generated_mutator = game.mvp2_run_controller.get_active_mutator()

	game.mvp2_run_controller.active_mutator_id = &"strong_lights"
	var floodlight = _spawn_placeable(game, FLOODLIGHT_PROFILE, HOME_POSITION + Vector2(-84.0, -24.0))
	var enemy = _spawn_enemy(game, floodlight.global_position + Vector2(48.0, 0.0))
	await _wait_frames(36)
	var slow_multiplier: float = float(enemy.get_slow_effect_multiplier() if enemy != null and is_instance_valid(enemy) else 1.0)

	var restless_enemy = _spawn_enemy(game, HOME_POSITION + Vector2(120.0, 64.0))
	game.mvp2_run_controller.active_mutator_id = &"restless_dead"
	restless_enemy.set_external_move_speed_multiplier(game.mvp2_run_controller.get_mutator_enemy_speed_multiplier())
	var restless_speed := float(restless_enemy.move_speed)

	print("daily_mutator_probe_generated=%s" % str(generated_mutator != null))
	print("daily_mutator_probe_active_id=%s" % String(game.mvp2_run_controller.active_mutator_id))
	print("daily_mutator_probe_strong_lights_slow=%.2f" % slow_multiplier)
	print("daily_mutator_probe_restless_speed=%.1f" % restless_speed)

	game.queue_free()
	await _wait_frames(2)
	quit()
