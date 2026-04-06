extends SceneTree

const GAME_SCENE := preload("res://scenes/main/Game.tscn")
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const SCREAMER_ENEMY := preload("res://data/enemies/zombie_screamer.tres")
const BASIC_ENEMY := preload("res://data/enemies/zombie_basic.tres")


func _wait_frames(count: int = 1) -> void:
	for _i in range(count):
		await process_frame
		await physics_frame
		await process_frame


func _spawn_enemy(game, definition: Resource, position: Vector2):
	var enemy = ENEMY_SCENE.instantiate()
	enemy.definition = definition
	enemy.global_position = position
	game.exploration_enemy_layer.add_child(enemy)
	enemy.configure_runtime_context(game.player, game.exploration_enemy_layer, game.construction_placeables)
	enemy.configure_exploration_context(game.player, Vector2.RIGHT, true, position, true)
	return enemy


func _init() -> void:
	var game = GAME_SCENE.instantiate()
	root.add_child(game)
	await _wait_frames(4)

	var screamer = _spawn_enemy(game, SCREAMER_ENEMY, game.player.global_position + Vector2(88.0, 0.0))
	var ally = _spawn_enemy(game, BASIC_ENEMY, screamer.global_position + Vector2(-24.0, 0.0))
	screamer.targeting_controller.alert_to_player(game.player, false)
	await _wait_frames(180)

	print("screamer_probe_screamer_chasing=%s" % str(bool(screamer.get("_is_chasing_player"))))
	print("screamer_probe_ally_alerted=%s" % str(bool(ally.get("_is_alerted_to_player")) or bool(ally.get("_is_chasing_player"))))

	game.queue_free()
	await _wait_frames(2)
	quit()
