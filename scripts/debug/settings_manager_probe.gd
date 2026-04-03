extends SceneTree

const APP_SERVICES := preload("res://scripts/main/app_services.gd")


func _wait_frames() -> void:
	await process_frame
	await physics_frame
	await process_frame


func _init() -> void:
	var settings_script := load("res://scripts/managers/settings_manager.gd")
	var settings: Object = settings_script.new()
	settings.call("load_settings")

	var original_master_volume: float = float(settings.call("get_master_volume"))
	var original_fullscreen: bool = bool(settings.call("get_fullscreen"))

	settings.call("set_master_volume", 0.37, false)
	settings.call("set_fullscreen", true, false)
	settings.call("save_settings")
	print("settings_manager_probe_file_exists=%s" % str(FileAccess.file_exists("user://system/settings.json")))

	var reloaded: Object = settings_script.new()
	reloaded.call("load_settings")

	print("settings_manager_probe_master_volume=%.2f" % float(reloaded.call("get_master_volume")))
	print("settings_manager_probe_fullscreen=%s" % str(bool(reloaded.call("get_fullscreen"))))

	settings.call("set_master_volume", original_master_volume, false)
	settings.call("set_fullscreen", original_fullscreen, false)
	settings.call("save_settings")

	var boot_scene := load("res://scenes/main/Boot.tscn")
	var boot: Node = boot_scene.instantiate()
	root.add_child(boot)
	await _wait_frames()

	print("settings_manager_probe_boot_start_button=%s" % str(boot.get_node("MenuLayer/RootControl/MainMenuPanel/MenuBox/StartButton") != null))
	print("settings_manager_probe_boot_settings_button=%s" % str(boot.get_node("MenuLayer/RootControl/MainMenuPanel/MenuBox/SettingsButton") != null))
	print("settings_manager_probe_boot_settings_panel=%s" % str(boot.get_node("MenuLayer/RootControl/SettingsPanel") != null))
	var boot_settings := APP_SERVICES.get_settings_store(boot.get_tree())
	print("settings_manager_probe_boot_settings_autoload=%s" % str(boot_settings != null))
	if DisplayServer.get_name() != "headless":
		var live_settings := APP_SERVICES.get_settings_store(boot.get_tree())
		if live_settings != null:
			live_settings.call("set_fullscreen", true, false)
			await _wait_frames()
			print("settings_manager_probe_window_fullscreen=%s" % str(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN))
			live_settings.call("set_fullscreen", false, false)
			await _wait_frames()
	if settings is Node:
		(settings as Node).free()
	if reloaded is Node:
		(reloaded as Node).free()
	boot.free()
	quit()
