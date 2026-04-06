extends Node
class_name Boot

const GAME_SCENE := preload("res://scenes/main/Game.tscn")
const APP_SERVICES := preload("res://scripts/main/app_services.gd")
const LEGACY_PERK_DEFINITIONS := [
	preload("res://data/legacy_perks/max_energy.tres"),
	preload("res://data/legacy_perks/prepared_stash.tres"),
	preload("res://data/legacy_perks/dog_pack.tres"),
	preload("res://data/legacy_perks/ammo_cache.tres"),
	preload("res://data/legacy_perks/scrapper.tres"),
	preload("res://data/legacy_perks/trainer.tres"),
]

var _settings_manager
var _save_manager
@onready var _game_host: Node2D = $GameHost
@onready var _menu_layer: CanvasLayer = $MenuLayer
@onready var _menu_panel: PanelContainer = $MenuLayer/RootControl/MainMenuPanel
@onready var _load_panel: PanelContainer = $MenuLayer/RootControl/LoadPanel
@onready var _settings_panel: PanelContainer = $MenuLayer/RootControl/SettingsPanel
@onready var _start_button: Button = $MenuLayer/RootControl/MainMenuPanel/MenuBox/StartButton
@onready var _continue_button: Button = $MenuLayer/RootControl/MainMenuPanel/MenuBox/ContinueButton
@onready var _load_button: Button = $MenuLayer/RootControl/MainMenuPanel/MenuBox/LoadButton
@onready var _settings_button: Button = $MenuLayer/RootControl/MainMenuPanel/MenuBox/SettingsButton
@onready var _quit_button: Button = $MenuLayer/RootControl/MainMenuPanel/MenuBox/QuitButton
@onready var _legacy_perk_button: Button = $MenuLayer/RootControl/MainMenuPanel/MenuBox/LegacyPerkButton
@onready var _legacy_perk_label: Label = $MenuLayer/RootControl/MainMenuPanel/MenuBox/LegacyPerkLabel
@onready var _load_back_button: Button = $MenuLayer/RootControl/LoadPanel/LoadBox/LoadBackButton
@onready var _back_button: Button = $MenuLayer/RootControl/SettingsPanel/SettingsBox/BackButton
@onready var _save_settings_button: Button = $MenuLayer/RootControl/SettingsPanel/SettingsBox/SaveSettingsButton
@onready var _master_volume_slider: HSlider = $MenuLayer/RootControl/SettingsPanel/SettingsBox/MasterVolumeSlider
@onready var _fullscreen_check: CheckBox = $MenuLayer/RootControl/SettingsPanel/SettingsBox/FullscreenCheck
@onready var _status_label: Label = $MenuLayer/RootControl/MainMenuPanel/MenuBox/Status
@onready var _menu_title_label: Label = $MenuLayer/RootControl/MainMenuPanel/MenuBox/Title
@onready var _load_status_label: Label = $MenuLayer/RootControl/LoadPanel/LoadBox/LoadStatus
@onready var _load_slot_buttons: Array[Button] = [
	$MenuLayer/RootControl/LoadPanel/LoadBox/LoadSlot1,
	$MenuLayer/RootControl/LoadPanel/LoadBox/LoadSlot2,
	$MenuLayer/RootControl/LoadPanel/LoadBox/LoadSlot3,
]


func _ready() -> void:
	_resolve_app_services()
	if _settings_manager != null:
		_settings_manager.load_settings()
	_bind_controls()
	_sync_settings_controls()
	_refresh_save_menu_state()
	_show_main_menu()

func _resolve_app_services() -> void:
	_settings_manager = APP_SERVICES.get_settings_store(get_tree())
	_save_manager = APP_SERVICES.get_save_store(get_tree())
	if _settings_manager == null:
		push_warning("SettingsStore autoload is missing.")
	if _save_manager == null:
		push_warning("SaveStore autoload is missing.")


func _bind_controls() -> void:
	_start_button.pressed.connect(_on_new_game_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_load_button.pressed.connect(_on_load_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_legacy_perk_button.pressed.connect(_on_legacy_perk_pressed)
	_save_settings_button.pressed.connect(_on_save_settings_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_load_back_button.pressed.connect(_on_load_back_pressed)
	_master_volume_slider.value_changed.connect(_on_master_volume_changed)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	for slot_index in range(_load_slot_buttons.size()):
		_load_slot_buttons[slot_index].pressed.connect(_on_load_slot_pressed.bind(slot_index))
	_continue_button.disabled = true
	_load_button.disabled = true
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for button in [_start_button, _continue_button, _load_button, _settings_button, _quit_button]:
		button.focus_mode = Control.FOCUS_ALL
	for button in _load_slot_buttons:
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _show_main_menu() -> void:
	if _game_host != null and is_instance_valid(_game_host):
		for child in _game_host.get_children():
			child.queue_free()
	_game_host.visible = false
	_menu_layer.visible = true
	_menu_panel.visible = true
	_settings_panel.visible = false
	_load_panel.visible = false
	_refresh_save_menu_state()
	_update_status("Perimeter ready. Continue a run or start a fresh day cycle.")


func _show_settings_menu() -> void:
	_menu_layer.visible = true
	_menu_panel.visible = false
	_settings_panel.visible = true
	_load_panel.visible = false
	_update_status("Adjust the shell before heading back into the run.")


func _show_load_menu() -> void:
	_menu_layer.visible = true
	_menu_panel.visible = false
	_settings_panel.visible = false
	_load_panel.visible = true
	_refresh_save_menu_state()
	_update_status("Choose a slot to restore.")


func _sync_settings_controls() -> void:
	if _settings_manager == null:
		return
	_master_volume_slider.value = _settings_manager.get_master_volume()
	_fullscreen_check.button_pressed = _settings_manager.get_fullscreen()
	_refresh_legacy_perk_label()


func _on_new_game_pressed() -> void:
	if _save_manager == null:
		_update_status("Save manager missing")
		return
	var slot_id: StringName = _save_manager.choose_new_game_slot()
	_update_status("Starting new game in %s" % String(slot_id))
	_start_game_with_state(slot_id, {})


func _on_continue_pressed() -> void:
	if _save_manager == null or not _save_manager.has_any_save():
		_update_status("No save slots found")
		return
	var slot_id: StringName = _save_manager.get_latest_slot_id()
	if slot_id == StringName():
		_update_status("No save slots found")
		return
	_update_status("Continuing %s" % String(slot_id))
	_start_game_with_state(slot_id, _save_manager.get_run_state_payload(slot_id))


func _on_load_pressed() -> void:
	_show_load_menu()


func _on_load_slot_pressed(slot_index: int) -> void:
	if _save_manager == null:
		_update_status("Save manager missing")
		return
	var summaries: Array[Dictionary] = _save_manager.get_slot_summaries()
	if slot_index < 0 or slot_index >= summaries.size():
		return
	var summary: Dictionary = summaries[slot_index]
	if not bool(summary.get("occupied", false)):
		_update_status("Slot %d is empty" % (slot_index + 1))
		return
	var slot_id := StringName(summary.get("slot_id", ""))
	_update_status("Loading %s" % String(slot_id))
	_start_game_with_state(slot_id, _save_manager.get_run_state_payload(slot_id))


func _on_load_back_pressed() -> void:
	_show_main_menu()


func _on_settings_pressed() -> void:
	_show_settings_menu()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_legacy_perk_pressed() -> void:
	if _settings_manager == null:
		return
	var current_id: String = _settings_manager.get_legacy_perk_id()
	var current_index: int = 0
	for index in range(LEGACY_PERK_DEFINITIONS.size()):
		var definition = LEGACY_PERK_DEFINITIONS[index]
		if definition != null and String(definition.perk_id) == current_id:
			current_index = index
			break
	var next_index: int = posmod(current_index + 1, LEGACY_PERK_DEFINITIONS.size())
	var next_definition = LEGACY_PERK_DEFINITIONS[next_index]
	_settings_manager.set_legacy_perk_id(String(next_definition.perk_id if next_definition != null else "max_energy"), true)
	_refresh_legacy_perk_label()
	_update_status("Legacy perk set to %s" % String(next_definition.display_name if next_definition != null else ""))


func _on_back_pressed() -> void:
	_sync_settings_controls()
	_show_main_menu()


func _on_save_settings_pressed() -> void:
	if _settings_manager == null:
		return
	_settings_manager.set_master_volume(float(_master_volume_slider.value), false)
	_settings_manager.set_fullscreen(_fullscreen_check.button_pressed, false)
	_settings_manager.save_settings()
	_update_status("Settings saved")
	_show_main_menu()


func _on_master_volume_changed(value: float) -> void:
	if _settings_manager != null:
		_settings_manager.set_master_volume(value, false)


func _on_fullscreen_toggled(pressed: bool) -> void:
	if _settings_manager != null:
		_settings_manager.set_fullscreen(pressed, false)


func _start_game() -> void:
	_start_game_with_state(StringName(), {})


func _start_game_with_state(slot_id: StringName, run_state: Dictionary) -> void:
	if _save_manager != null:
		_save_manager.set_active_slot(StringName())
	for child in _game_host.get_children():
		child.queue_free()
	var game = GAME_SCENE.instantiate()
	if game.has_method("set_legacy_perk_id"):
		var selected_legacy_perk_id := "max_energy"
		if not run_state.is_empty():
			selected_legacy_perk_id = String(run_state.get("legacy_perk_id", selected_legacy_perk_id))
		elif _settings_manager != null:
			selected_legacy_perk_id = _settings_manager.get_legacy_perk_id()
		game.set_legacy_perk_id(selected_legacy_perk_id)
	_game_host.add_child(game)
	if game.has_signal("return_to_menu_requested") and not game.return_to_menu_requested.is_connected(_on_game_return_to_menu_requested):
		game.return_to_menu_requested.connect(_on_game_return_to_menu_requested)
	_game_host.visible = true
	_menu_layer.visible = false
	_menu_panel.visible = false
	_settings_panel.visible = false
	_load_panel.visible = false
	await get_tree().process_frame
	if not run_state.is_empty() and game.has_method("apply_save_state"):
		game.apply_save_state(run_state)
		await get_tree().process_frame
	if _save_manager != null and slot_id != StringName():
		_save_manager.set_active_slot(slot_id)
		if run_state.is_empty():
			_save_manager.save_active_game(game)


func _refresh_save_menu_state() -> void:
	if _save_manager == null:
		_continue_button.disabled = true
		return
	_continue_button.disabled = not _save_manager.has_any_save()
	if _load_status_label != null:
		_load_status_label.text = "Choose a save slot. Latest activity is surfaced first on Continue."
	var summaries: Array[Dictionary] = _save_manager.get_slot_summaries()
	for index in range(_load_slot_buttons.size()):
		var button := _load_slot_buttons[index]
		if button == null:
			continue
		if index >= summaries.size():
			button.text = "Slot %d" % (index + 1)
			button.disabled = true
			continue
		var summary: Dictionary = summaries[index]
		button.text = _format_slot_summary(index, summary)
		button.disabled = not bool(summary.get("occupied", false))
	_refresh_legacy_perk_label()


func _on_game_return_to_menu_requested() -> void:
	get_tree().paused = false
	_show_main_menu()


func _update_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func _format_slot_summary(index: int, summary: Dictionary) -> String:
	if not bool(summary.get("occupied", false)):
		return "Slot %d\nEmpty" % (index + 1)
	var summary_text := String(summary.get("summary_text", "Slot %d" % (index + 1)))
	var slot_id := String(summary.get("slot_id", "slot_%d" % (index + 1)))
	return "%s\n%s" % [summary_text, slot_id.replace("_", " ").capitalize()]


func _refresh_legacy_perk_label() -> void:
	if _legacy_perk_label == null:
		return
	var label_text := "+10 Max Energy"
	if _settings_manager != null:
		var selected_id: String = _settings_manager.get_legacy_perk_id()
		for definition in LEGACY_PERK_DEFINITIONS:
			if definition != null and String(definition.perk_id) == selected_id:
				label_text = String(definition.display_name)
				break
	_legacy_perk_label.text = "Legacy Perk: %s" % label_text
