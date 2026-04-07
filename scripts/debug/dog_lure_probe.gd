extends SceneTree

const GAME_SCENE := preload("res://scenes/main/Game.tscn")
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const BASIC_ENEMY := preload("res://data/enemies/zombie_basic.tres")


func _wait_frames(count: int = 1) -> void:
	for _i in range(count):
		await process_frame
		await physics_frame
		await process_frame


func _init() -> void:
	var game = GAME_SCENE.instantiate()
	root.add_child(game)
	await _wait_frames(3)

	game.game_manager.set_run_state(game.game_manager.RunState.ACTIVE_WAVE)
	game.player.global_position = Vector2(1280.0, 720.0)
	game.dog.global_position = game.player.global_position + Vector2(-24.0, 18.0)
	game.dog.current_stamina = 100
	var lure_target: Vector2 = game.player.global_position + Vector2(128.0, 0.0)

	var enemy = ENEMY_SCENE.instantiate()
	enemy.definition = BASIC_ENEMY
	enemy.global_position = lure_target + Vector2(24.0, 0.0)
	game.exploration_enemy_layer.add_child(enemy)
	await _wait_frames(4)

	var started: bool = game.dog.issue_context_command(lure_target)
	await _wait_frames(10)

	print("dog_lure_probe_started=%s" % str(started))
	print("dog_lure_probe_state=%s" % game.dog._build_status_text())
	print("dog_lure_probe_stamina=%d" % int(game.dog.current_stamina))
	print("dog_lure_probe_enemy_investigating=%s" % str(enemy.is_investigating_noise()))
	print("dog_lure_probe_dog_moved_toward_target=%s" % str(game.dog.global_position.distance_to(lure_target) < game.player.global_position.distance_to(lure_target)))
	print("dog_lure_probe_enemy_not_overlapping_dog=%s" % str(enemy.global_position.distance_to(game.dog.global_position) >= 14.0))

	game.dog.debug_complete_active_scavenge()
	game.dog._remaining_trip_time = 0.0
	await _wait_frames(1)
	game.dog._complete_lure()
	await _wait_frames(2)
	print("dog_lure_probe_state_after=%s" % game.dog._build_status_text())

	game.queue_free()
	await _wait_frames(2)
	quit()
