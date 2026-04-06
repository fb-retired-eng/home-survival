extends SceneTree

const GAME_SCENE := preload("res://scenes/main/Game.tscn")
const PLACEABLE_SCENE := preload("res://scenes/world/Placeable.tscn")
const POWER_RELAY_PROFILE := preload("res://data/placeables/power_relay.tres")
const TURRET_PROFILE := preload("res://data/placeables/turret.tres")
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

	var far_turret = _spawn_placeable(game, TURRET_PROFILE, HOME_POSITION + Vector2(300.0, 0.0))
	await _wait_frames(10)
	var unpowered_before: bool = not far_turret.is_powered()

	var relay = _spawn_placeable(game, POWER_RELAY_PROFILE, HOME_POSITION + Vector2(160.0, 0.0))
	await _wait_frames(12)

	print("power_relay_probe_turret_unpowered_before=%s" % str(unpowered_before))
	print("power_relay_probe_relay_powered=%s" % str(relay.is_powered()))
	print("power_relay_probe_turret_powered_after=%s" % str(far_turret.is_powered()))

	game.queue_free()
	await _wait_frames(2)
	quit()
