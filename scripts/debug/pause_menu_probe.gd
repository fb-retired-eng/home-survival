extends SceneTree


func _wait_frames() -> void:
	await process_frame
	await physics_frame
	await process_frame


func _init() -> void:
	var boot_scene := load("res://scenes/main/Boot.tscn")
	var boot = boot_scene.instantiate()
	root.add_child(boot)
	await _wait_frames()

	boot._on_new_game_pressed()
	await _wait_frames()
	var game = boot._game_host.get_children()[0]

	game.player.take_damage(13)
	await _wait_frames()
	var active_slot_id: StringName = boot._save_manager.get_active_slot_id()

	game._on_pause_toggle_requested()
	await _wait_frames()
	print("pause_probe_paused=%s" % str(paused))
	print("pause_probe_menu_visible=%s" % str(game.hud.is_pause_menu_visible()))

	game._on_pause_save_requested()
	await _wait_frames()
	var payload: Dictionary = boot._save_manager.load_slot(active_slot_id)
	var saved_run: Dictionary = payload.get("run", {})
	var saved_player: Dictionary = saved_run.get("player", {})
	print("pause_probe_saved_health=%d" % int(saved_player.get("health", 0)))
	print("pause_probe_saved_slot_summary=%s" % String(boot._save_manager.get_slot_summary(active_slot_id).get("summary_text", "")))

	game._on_pause_resume_requested()
	await _wait_frames()
	print("pause_probe_resumed=%s" % str(not paused))
	print("pause_probe_menu_hidden=%s" % str(not game.hud.is_pause_menu_visible()))

	game.game_manager.set_run_state(game.game_manager.RunState.ACTIVE_WAVE)
	game.player.take_damage(5)
	await _wait_frames()
	game._on_pause_toggle_requested()
	await _wait_frames()
	game._on_pause_save_requested()
	await _wait_frames()
	var active_wave_payload: Dictionary = boot._save_manager.load_slot(active_slot_id)
	var active_wave_saved_player: Dictionary = active_wave_payload.get("run", {}).get("player", {})
	print("pause_probe_active_wave_blocked=%s" % str(int(active_wave_saved_player.get("health", 0)) == int(saved_player.get("health", 0))))
	print("pause_probe_active_wave_status=%s" % String(game.hud.get_node("PauseOverlay/PausePanel/PauseBox/PauseStatus").text))
	game._on_pause_resume_requested()
	await _wait_frames()
	game.game_manager.set_run_state(game.game_manager.RunState.PRE_WAVE)
	await _wait_frames()

	game._on_pause_toggle_requested()
	await _wait_frames()
	game._on_pause_save_quit_requested()
	await _wait_frames()
	print("pause_probe_back_to_menu=%s" % str(boot._menu_panel.visible))
	print("pause_probe_game_host_children=%d" % boot._game_host.get_child_count())

	quit()
