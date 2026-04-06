extends SceneTree

const GAME_SCENE := preload("res://scenes/main/Game.tscn")


func _wait_frames(count: int = 1) -> void:
	for _i in range(count):
		await process_frame
		await physics_frame
		await process_frame


func _wave_contains_enemy_id(wave_definition, enemy_id: StringName) -> bool:
	if wave_definition == null:
		return false
	for lane in wave_definition.lanes:
		if lane == null or lane.enemy_definition == null:
			continue
		if StringName(lane.enemy_definition.enemy_id) == enemy_id:
			return true
	return false


func _init() -> void:
	var game = GAME_SCENE.instantiate()
	root.add_child(game)
	await _wait_frames(2)

	var waves: Array = game.wave_manager.wave_set_definition.waves
	print("mvp2_wave_probe_wave6_has_screamer=%s" % str(_wave_contains_enemy_id(waves[5], &"zombie_screamer")))
	print("mvp2_wave_probe_wave7_has_breaker=%s" % str(_wave_contains_enemy_id(waves[6], &"zombie_breaker")))
	print("mvp2_wave_probe_wave8_has_screamer=%s" % str(_wave_contains_enemy_id(waves[7], &"zombie_screamer")))
	print("mvp2_wave_probe_wave8_has_breaker=%s" % str(_wave_contains_enemy_id(waves[7], &"zombie_breaker")))

	game.queue_free()
	await _wait_frames(2)
	quit()
