extends Node
class_name SettingsManager

const SETTINGS_PATH := "user://system/settings.json"
const KEY_MASTER_VOLUME := "master_volume"
const KEY_FULLSCREEN := "fullscreen"

var master_volume: float = 1.0
var fullscreen: bool = false


func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				var data := parsed as Dictionary
				master_volume = clampf(float(data.get(KEY_MASTER_VOLUME, master_volume)), 0.0, 1.0)
				fullscreen = bool(data.get(KEY_FULLSCREEN, fullscreen))
	_apply_settings()


func save_settings() -> void:
	_ensure_storage_directory()
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to save settings to %s" % SETTINGS_PATH)
		return
	file.store_string(JSON.stringify({
		KEY_MASTER_VOLUME: master_volume,
		KEY_FULLSCREEN: fullscreen,
	}, "\t"))


func set_master_volume(value: float, persist: bool = true) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_settings()
	if persist:
		save_settings()


func set_fullscreen(value: bool, persist: bool = true) -> void:
	fullscreen = value
	_apply_settings()
	if persist:
		save_settings()


func get_master_volume() -> float:
	return master_volume


func get_fullscreen() -> bool:
	return fullscreen


func _apply_settings() -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(max(master_volume, 0.0001)))

	if not _is_headless_display():
		var window := get_window()
		if window != null:
			window.mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


func _is_headless_display() -> bool:
	return DisplayServer.get_name() == "headless"


func _ensure_storage_directory() -> void:
	var directory := ProjectSettings.globalize_path("user://system")
	if directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(directory)
