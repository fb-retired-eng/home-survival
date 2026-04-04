extends SceneTree

const GAME_SCENE := preload("res://scenes/main/Game.tscn")


func _wait_frames(count: int = 1) -> void:
	for _i in range(count):
		await process_frame
		await physics_frame
		await process_frame


func _spawn_game(perk_id: String):
	var game = GAME_SCENE.instantiate()
	game.set_legacy_perk_id(perk_id)
	root.add_child(game)
	return game


func _init() -> void:
	var energy_game = _spawn_game("max_energy")
	await _wait_frames(3)
	print("legacy_probe_max_energy=%d" % int(energy_game.player.max_energy))
	energy_game.queue_free()
	await _wait_frames(2)

	var stash_game = _spawn_game("prepared_stash")
	await _wait_frames(3)
	print("legacy_probe_stash_battery=%d" % int(stash_game.player.resources.get("battery", 0)))
	print("legacy_probe_stash_bullets=%d" % int(stash_game.player.resources.get("bullets", 0)))
	stash_game.queue_free()
	await _wait_frames(2)

	var dog_game = _spawn_game("dog_pack")
	await _wait_frames(3)
	print("legacy_probe_dog_max_stamina=%d" % int(dog_game.dog.max_stamina))
	dog_game.queue_free()
	await _wait_frames(2)
	quit()
