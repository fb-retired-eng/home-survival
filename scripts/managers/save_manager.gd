extends Node
class_name SaveManager

const SAVE_VERSION := 1
const SAVE_ROOT := "user://system/saves"
const SLOT_IDS := [&"slot_1", &"slot_2", &"slot_3"]

var active_slot_id: StringName = StringName()
var _pending_autosave: bool = false


func get_slot_ids() -> PackedStringArray:
	var slot_ids := PackedStringArray()
	for slot_id in SLOT_IDS:
		slot_ids.append(String(slot_id))
	return slot_ids


func has_any_save() -> bool:
	for slot_id in SLOT_IDS:
		if FileAccess.file_exists(_get_slot_path(slot_id)):
			return true
	return false


func set_active_slot(slot_id: StringName) -> void:
	active_slot_id = _normalize_slot_id(slot_id)


func get_active_slot_id() -> StringName:
	return active_slot_id


func choose_new_game_slot() -> StringName:
	for slot_id in SLOT_IDS:
		if not FileAccess.file_exists(_get_slot_path(slot_id)):
			return slot_id
	return get_oldest_slot_id()


func get_latest_slot_id() -> StringName:
	var latest_slot_id := StringName()
	var latest_saved_at: int = -1
	for slot_id in SLOT_IDS:
		var summary := get_slot_summary(slot_id)
		if not bool(summary.get("occupied", false)):
			continue
		var saved_at := int(summary.get("saved_at_unix", 0))
		if saved_at > latest_saved_at:
			latest_saved_at = saved_at
			latest_slot_id = slot_id
	return latest_slot_id


func get_oldest_slot_id() -> StringName:
	var oldest_slot_id := SLOT_IDS[0]
	var oldest_saved_at: int = 2147483647
	for slot_id in SLOT_IDS:
		var summary := get_slot_summary(slot_id)
		if not bool(summary.get("occupied", false)):
			return slot_id
		var saved_at := int(summary.get("saved_at_unix", 2147483647))
		if saved_at < oldest_saved_at:
			oldest_saved_at = saved_at
			oldest_slot_id = slot_id
	return oldest_slot_id


func get_slot_summaries() -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	for slot_id in SLOT_IDS:
		summaries.append(get_slot_summary(slot_id))
	return summaries


func get_slot_summary(slot_id: StringName) -> Dictionary:
	var normalized_slot_id := _normalize_slot_id(slot_id)
	var summary := {
		"slot_id": String(normalized_slot_id),
		"occupied": false,
		"save_version": 0,
		"saved_at_unix": 0,
		"day": 0,
		"wave": 0,
		"phase": "",
		"summary_text": _get_empty_slot_text(normalized_slot_id),
	}
	if normalized_slot_id == StringName():
		return summary

	var payload := load_slot(normalized_slot_id)
	if payload.is_empty():
		return summary

	var meta: Dictionary = payload.get("meta", {})
	summary["occupied"] = true
	summary["save_version"] = int(payload.get("version", 0))
	summary["saved_at_unix"] = int(payload.get("saved_at_unix", 0))
	summary["day"] = int(meta.get("day", 0))
	summary["wave"] = int(meta.get("wave", 0))
	summary["phase"] = String(meta.get("phase", ""))
	summary["summary_text"] = _build_summary_text(summary)
	return summary


func load_slot(slot_id: StringName) -> Dictionary:
	var normalized_slot_id := _normalize_slot_id(slot_id)
	if normalized_slot_id == StringName():
		return {}

	var file_path := _get_slot_path(normalized_slot_id)
	if not FileAccess.file_exists(file_path):
		return {}

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}

	return parsed as Dictionary


func save_game_to_slot(slot_id: StringName, game) -> bool:
	var normalized_slot_id := _normalize_slot_id(slot_id)
	if normalized_slot_id == StringName():
		return false
	if game == null or not is_instance_valid(game) or not game.has_method("get_save_state"):
		return false

	var run_state: Dictionary = game.get_save_state()
	var payload := _build_save_payload(normalized_slot_id, run_state)
	if payload.is_empty():
		return false

	_ensure_storage_directory()
	var file := FileAccess.open(_get_slot_path(normalized_slot_id), FileAccess.WRITE)
	if file == null:
		push_warning("Failed to save run slot %s" % String(normalized_slot_id))
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	if normalized_slot_id == active_slot_id:
		_pending_autosave = false
	return true


func save_active_game(game) -> bool:
	if active_slot_id == StringName():
		return false
	return save_game_to_slot(active_slot_id, game)


func request_autosave(game) -> void:
	if game == null or not is_instance_valid(game):
		return
	if active_slot_id == StringName():
		return
	if _is_safe_to_save(game):
		save_active_game(game)
		return
	_pending_autosave = true


func flush_pending_autosave(game) -> void:
	if not _pending_autosave:
		return
	if game == null or not is_instance_valid(game):
		return
	if not _is_safe_to_save(game):
		return
	save_active_game(game)


func get_run_state_payload(slot_id: StringName) -> Dictionary:
	var payload := load_slot(slot_id)
	if payload.is_empty():
		return {}
	var run_state: Dictionary = payload.get("run", {})
	if run_state.is_empty():
		return {}
	return run_state


func _build_save_payload(slot_id: StringName, run_state: Dictionary) -> Dictionary:
	if run_state.is_empty():
		return {}
	var player_state: Dictionary = run_state.get("player", {})
	var game_state: Dictionary = run_state.get("game", {})
	var wave := int(game_state.get("wave", 0))
	var phase := String(game_state.get("phase", ""))
	var day := wave + 1
	return {
		"version": SAVE_VERSION,
		"slot_id": String(slot_id),
		"saved_at_unix": Time.get_unix_time_from_system(),
		"meta": {
			"day": day,
			"wave": wave,
			"phase": phase,
			"health": int(player_state.get("health", 0)),
			"energy": int(player_state.get("energy", 0)),
			"weapon": String(player_state.get("equipped_weapon_id", "")),
		},
		"run": run_state.duplicate(true),
	}


func _build_summary_text(summary: Dictionary) -> String:
	var slot_label := _get_slot_label(StringName(summary.get("slot_id", "")))
	var day := int(summary.get("day", 0))
	var wave := int(summary.get("wave", 0))
	var phase := String(summary.get("phase", ""))
	var saved_at_unix := int(summary.get("saved_at_unix", 0))
	var saved_at_text := "recently"
	if saved_at_unix > 0:
		saved_at_text = Time.get_datetime_string_from_unix_time(saved_at_unix, false)
	return "%s | Day %d | Wave %d | %s | %s" % [slot_label, day, wave, phase, saved_at_text]


func _get_empty_slot_text(slot_id: StringName) -> String:
	return "%s | Empty" % _get_slot_label(slot_id)


func _get_slot_label(slot_id: StringName) -> String:
	var normalized_slot_id := _normalize_slot_id(slot_id)
	for index in range(SLOT_IDS.size()):
		if SLOT_IDS[index] == normalized_slot_id:
			return "Slot %d" % (index + 1)
	return String(normalized_slot_id)


func _normalize_slot_id(slot_id: StringName) -> StringName:
	if slot_id == StringName():
		return StringName()
	var slot_text := String(slot_id).strip_edges()
	for candidate in SLOT_IDS:
		if slot_text == String(candidate):
			return candidate
	return StringName()


func _get_slot_path(slot_id: StringName) -> String:
	var normalized_slot_id := _normalize_slot_id(slot_id)
	if normalized_slot_id == StringName():
		return ""
	return "%s/%s.json" % [SAVE_ROOT, String(normalized_slot_id)]


func _ensure_storage_directory() -> void:
	var directory := ProjectSettings.globalize_path(SAVE_ROOT)
	if directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(directory)


func _is_safe_to_save(game) -> bool:
	if game == null or not is_instance_valid(game):
		return false
	if not game.has_method("get_save_state"):
		return false
	var game_manager = game.get("game_manager")
	if game_manager == null:
		return false
	var run_state := int(game.game_manager.run_state)
	return run_state != int(game.game_manager.RunState.ACTIVE_WAVE)
