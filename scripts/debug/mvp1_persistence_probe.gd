extends SceneTree


const SLOT_ID := &"slot_3"


func _wait_frames() -> void:
	await process_frame
	await physics_frame
	await process_frame


func _find_socket(root_node: Node, socket_id: StringName) -> Node:
	if root_node == null or not is_instance_valid(root_node):
		return null
	for child in root_node.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if StringName(str(child.get("socket_id"))) == socket_id:
			return child
		var found: Node = _find_socket(child, socket_id)
		if found != null:
			return found
	return null


func _init() -> void:
	await _wait_frames()
	var settings_store := root.get_node_or_null("SettingsStore")
	if settings_store == null:
		push_error("Required autoload missing")
		quit(1)
		return

	var game_scene: PackedScene = load("res://scenes/main/Game.tscn")
	var boot_scene: PackedScene = load("res://scenes/main/Boot.tscn")
	var energy_game = game_scene.instantiate()
	energy_game.set_legacy_perk_id("max_energy")
	root.add_child(energy_game)
	await _wait_frames()
	var energy_run_state: Dictionary = energy_game.get_save_state()
	var loaded_energy_game = game_scene.instantiate()
	root.add_child(loaded_energy_game)
	await _wait_frames()
	loaded_energy_game.apply_save_state(energy_run_state)
	await _wait_frames()
	print("mvp1_probe_saved_energy_perk_id=%s" % str(loaded_energy_game.legacy_perk_id))
	print("mvp1_probe_saved_energy_player_max=%d" % int(loaded_energy_game.player.max_energy))
	loaded_energy_game.queue_free()
	energy_game.queue_free()
	await _wait_frames()

	var reset_game = game_scene.instantiate()
	reset_game.set_legacy_perk_id("dog_pack")
	root.add_child(reset_game)
	await _wait_frames()
	reset_game.player.add_resource("battery", 1, false)
	reset_game.power_manager.upgrade_generator(reset_game.player)
	print("mvp1_probe_reset_slots_before=%d" % int(reset_game.power_manager.max_load_slots))
	reset_game.game_manager.reset_run()
	await _wait_frames()
	print("mvp1_probe_reset_slots_after=%d" % int(reset_game.power_manager.max_load_slots))
	reset_game.queue_free()
	await _wait_frames()

	var game = game_scene.instantiate()
	game.set_legacy_perk_id("dog_pack")
	root.add_child(game)
	await _wait_frames()
	game.player.add_resource("battery", 2, false)
	game.power_manager.upgrade_generator(game.player)
	game.dog.current_stamina = 77
	var socket = _find_socket(game, &"wall_n")
	game._active_heirloom_socket_ids[&"wall_n"] = true
	game.mvp1_run_controller.apply_heirloom_socket_state()
	if socket != null and is_instance_valid(socket):
		socket.current_hp = max(int(socket.current_hp) - 9, 0)
		socket.state_changed.emit(socket)
	var run_state: Dictionary = game.get_save_state()
	var loaded_game = game_scene.instantiate()
	root.add_child(loaded_game)
	await _wait_frames()
	loaded_game.apply_save_state(run_state)
	await _wait_frames()
	var loaded_socket = _find_socket(loaded_game, &"wall_n")
	print("mvp1_probe_saved_legacy_perk=%s" % str(loaded_game.legacy_perk_id))
	print("mvp1_probe_saved_power_slots=%d" % int(loaded_game.power_manager.max_load_slots))
	print("mvp1_probe_saved_dog_stamina=%d" % int(loaded_game.dog.current_stamina))
	print("mvp1_probe_saved_player_max_energy=%d" % int(loaded_game.player.max_energy))
	print("mvp1_probe_saved_dog_max_stamina=%d" % int(loaded_game.dog.max_stamina))
	print("mvp1_probe_saved_heirloom_active=%s" % str(loaded_socket != null and loaded_socket.has_method("has_heirloom_debris") and loaded_socket.has_heirloom_debris()))
	print("mvp1_probe_saved_heirloom_hp=%d" % int(loaded_socket.max_hp if loaded_socket != null else -1))

	settings_store.set_legacy_perk_id("prepared_stash", false)
	var boot = boot_scene.instantiate()
	root.add_child(boot)
	await _wait_frames()
	await boot._start_game_with_state(SLOT_ID, run_state)
	await _wait_frames()
	var boot_game = boot._game_host.get_child(0) if boot._game_host.get_child_count() > 0 else null
	print("mvp1_probe_boot_loaded_legacy_perk=%s" % str(boot_game.legacy_perk_id if boot_game != null else ""))
	print("mvp1_probe_boot_loaded_dog_max_stamina=%d" % int(boot_game.dog.max_stamina if boot_game != null else -1))
	print("mvp1_probe_boot_loaded_battery=%d" % int(boot_game.player.resources.get("battery", -1) if boot_game != null else -1))

	boot.queue_free()
	loaded_game.queue_free()
	game.queue_free()
	await _wait_frames()
	quit()
