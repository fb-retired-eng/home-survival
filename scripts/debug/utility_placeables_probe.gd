extends SceneTree

const GAME_SCENE := preload("res://scenes/main/Game.tscn")
const PLACEABLE_SCENE := preload("res://scenes/world/Placeable.tscn")
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const ALARM_BEACON_PROFILE := preload("res://data/placeables/alarm_beacon.tres")
const REPAIR_STATION_PROFILE := preload("res://data/placeables/repair_station.tres")
const AMMO_LOCKER_PROFILE := preload("res://data/placeables/ammo_locker.tres")
const BARRICADE_PROFILE := preload("res://data/placeables/barricade.tres")
const BASIC_ENEMY := preload("res://data/enemies/zombie_basic.tres")
const HOME_POSITION := Vector2(1280.0, 720.0)


func _wait_frames(count: int = 1) -> void:
	for _i in range(count):
		await process_frame
		await physics_frame
		await process_frame


func _wait_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout
	await _wait_frames(2)


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
	game.mvp2_run_controller.active_mutator_id = StringName()

	var alarm_beacon = _spawn_placeable(game, ALARM_BEACON_PROFILE, HOME_POSITION + Vector2(84.0, -24.0))
	var repair_station = _spawn_placeable(game, REPAIR_STATION_PROFILE, HOME_POSITION + Vector2(-84.0, -24.0))
	var ammo_locker = _spawn_placeable(game, AMMO_LOCKER_PROFILE, HOME_POSITION + Vector2(0.0, 98.0))
	var barricade = _spawn_placeable(game, BARRICADE_PROFILE, repair_station.global_position + Vector2(56.0, 0.0))
	await _wait_frames(12)

	barricade.take_damage(18)
	game.player.spend_resource("bullets", int(game.player.resources.get("bullets", 0)))
	game.player.global_position = ammo_locker.global_position
	await _wait_seconds(3.0)
	var repair_hp_first := int(barricade.current_hp)
	var bullets_first := int(game.player.resources.get("bullets", 0))
	await _wait_seconds(3.0)

	print("utility_placeables_probe_alarm_powered=%s" % str(alarm_beacon.is_powered()))
	print("utility_placeables_probe_repair_powered=%s" % str(repair_station.is_powered()))
	print("utility_placeables_probe_ammo_powered=%s" % str(ammo_locker.is_powered()))
	print("utility_placeables_probe_repair_hp_after=%d" % repair_hp_first)
	print("utility_placeables_probe_bullets_after=%d" % bullets_first)
	print("utility_placeables_probe_repair_capped=%s" % str(int(barricade.current_hp) == repair_hp_first))
	print("utility_placeables_probe_ammo_capped=%s" % str(int(game.player.resources.get("bullets", 0)) == bullets_first))

	var bullets_before_active := int(game.player.resources.get("bullets", 0))
	var hp_before_active := int(barricade.current_hp)
	game.game_manager.set_run_state(game.game_manager.RunState.ACTIVE_WAVE)
	var enemy = _spawn_enemy(game, alarm_beacon.global_position + Vector2(132.0, 0.0))
	await _wait_seconds(2.4)

	var targeting_controller = enemy.get("targeting_controller")
	var investigating := false
	if targeting_controller != null and is_instance_valid(targeting_controller) and targeting_controller.has_method("has_active_noise_investigation"):
		investigating = bool(targeting_controller.has_active_noise_investigation())

	print("utility_placeables_probe_alarm_enemy_investigating=%s" % str(investigating or bool(enemy.get("_is_chasing_player"))))
	print("utility_placeables_probe_repair_active_wave_unchanged=%s" % str(int(barricade.current_hp) == hp_before_active))
	print("utility_placeables_probe_ammo_active_wave_unchanged=%s" % str(int(game.player.resources.get("bullets", 0)) == bullets_before_active))

	game.queue_free()
	await _wait_frames(2)
	quit()
