extends Node
class_name Boot

const GAME_SCENE := preload("res://scenes/main/Game.tscn")
const SETTINGS_MANAGER_SCRIPT := preload("res://scripts/managers/settings_manager.gd")
const SAVE_MANAGER_SCRIPT := preload("res://scripts/managers/save_manager.gd")

var _settings_manager
var _save_manager
var _game_host: Node2D
var _menu_layer: CanvasLayer
var _menu_panel: PanelContainer
var _load_panel: PanelContainer
var _settings_panel: PanelContainer
var _start_button: Button
var _continue_button: Button
var _load_button: Button
var _settings_button: Button
var _quit_button: Button
var _load_back_button: Button
var _back_button: Button
var _save_settings_button: Button
var _master_volume_slider: HSlider
var _fullscreen_check: CheckBox
var _status_label: Label
var _menu_title_label: Label
var _load_status_label: Label
var _load_slot_buttons: Array[Button] = []


func _ready() -> void:
	_settings_manager = _ensure_settings_manager()
	_save_manager = _ensure_save_manager()
	_settings_manager.load_settings()
	_build_shell()
	_sync_settings_controls()
	_refresh_save_menu_state()
	_show_main_menu()


func _ensure_settings_manager():
	var existing := get_node_or_null("/root/SettingsStore")
	if existing != null:
		return existing

	var manager := SETTINGS_MANAGER_SCRIPT.new()
	manager.name = "SettingsStore"
	get_tree().root.add_child(manager)
	return manager


func _ensure_save_manager():
	var existing := get_node_or_null("/root/SaveStore")
	if existing != null:
		return existing

	var manager := SAVE_MANAGER_SCRIPT.new()
	manager.name = "SaveStore"
	get_tree().root.add_child(manager)
	return manager


func _build_shell() -> void:
	if _game_host != null:
		return

	_game_host = Node2D.new()
	_game_host.name = "GameHost"
	add_child(_game_host)

	_menu_layer = CanvasLayer.new()
	_menu_layer.name = "MenuLayer"
	add_child(_menu_layer)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.06, 0.07, 0.08, 0.94)
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.offset_left = 0.0
	backdrop.offset_top = 0.0
	backdrop.offset_right = 0.0
	backdrop.offset_bottom = 0.0
	_menu_layer.add_child(backdrop)

	var root_control := Control.new()
	root_control.name = "RootControl"
	root_control.anchor_right = 1.0
	root_control.anchor_bottom = 1.0
	root_control.offset_left = 0.0
	root_control.offset_top = 0.0
	root_control.offset_right = 0.0
	root_control.offset_bottom = 0.0
	_menu_layer.add_child(root_control)

	_menu_panel = _make_panel(root_control, "MainMenuPanel", Vector2(0.5, 0.45), Vector2(0.5, 0.5), Vector2(420.0, 360.0))
	var menu_box := VBoxContainer.new()
	menu_box.name = "MenuBox"
	menu_box.add_theme_constant_override("separation", 12)
	menu_box.anchor_right = 1.0
	menu_box.anchor_bottom = 1.0
	menu_box.offset_left = 28.0
	menu_box.offset_top = 24.0
	menu_box.offset_right = -28.0
	menu_box.offset_bottom = -24.0
	_menu_panel.add_child(menu_box)

	_menu_title_label = _make_label(menu_box, "Title", "Home Survival", 30)
	_menu_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_make_label(menu_box, "Subtitle", "MVP0.5 bridge build", 16)
	_start_button = _make_button(menu_box, "StartButton", "New Game", Callable(self, "_on_new_game_pressed"))
	_continue_button = _make_button(menu_box, "ContinueButton", "Continue", Callable(self, "_on_continue_pressed"))
	_load_button = _make_button(menu_box, "LoadButton", "Load Game", Callable(self, "_on_load_pressed"))
	_settings_button = _make_button(menu_box, "SettingsButton", "Settings", Callable(self, "_on_settings_pressed"))
	_quit_button = _make_button(menu_box, "QuitButton", "Quit", Callable(self, "_on_quit_pressed"))
	_status_label = _make_label(menu_box, "Status", "Menu ready", 14)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_continue_button.disabled = true
	_load_button.disabled = true

	_settings_panel = _make_panel(root_control, "SettingsPanel", Vector2(0.5, 0.5), Vector2(0.5, 0.5), Vector2(460.0, 340.0))
	_settings_panel.visible = false
	var settings_box := VBoxContainer.new()
	settings_box.name = "SettingsBox"
	settings_box.add_theme_constant_override("separation", 12)
	settings_box.anchor_right = 1.0
	settings_box.anchor_bottom = 1.0
	settings_box.offset_left = 28.0
	settings_box.offset_top = 24.0
	settings_box.offset_right = -28.0
	settings_box.offset_bottom = -24.0
	_settings_panel.add_child(settings_box)

	_make_label(settings_box, "SettingsTitle", "Settings", 30)
	_make_label(settings_box, "VolumeLabel", "Master Volume", 16)
	_master_volume_slider = HSlider.new()
	_master_volume_slider.name = "MasterVolumeSlider"
	_master_volume_slider.min_value = 0.0
	_master_volume_slider.max_value = 1.0
	_master_volume_slider.step = 0.01
	_master_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_master_volume_slider.value_changed.connect(_on_master_volume_changed)
	settings_box.add_child(_master_volume_slider)
	_make_label(settings_box, "FullscreenLabel", "Fullscreen", 16)
	_fullscreen_check = CheckBox.new()
	_fullscreen_check.name = "FullscreenCheck"
	_fullscreen_check.text = "Enable fullscreen"
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	settings_box.add_child(_fullscreen_check)
	_save_settings_button = _make_button(settings_box, "SaveSettingsButton", "Save Changes", Callable(self, "_on_save_settings_pressed"))
	_back_button = _make_button(settings_box, "BackButton", "Back", Callable(self, "_on_back_pressed"))

	_load_panel = _make_panel(root_control, "LoadPanel", Vector2(0.5, 0.48), Vector2(0.5, 0.5), Vector2(480.0, 420.0))
	_load_panel.visible = false
	var load_box := VBoxContainer.new()
	load_box.name = "LoadBox"
	load_box.add_theme_constant_override("separation", 12)
	load_box.anchor_right = 1.0
	load_box.anchor_bottom = 1.0
	load_box.offset_left = 28.0
	load_box.offset_top = 24.0
	load_box.offset_right = -28.0
	load_box.offset_bottom = -24.0
	_load_panel.add_child(load_box)

	_make_label(load_box, "LoadTitle", "Load Game", 30)
	_load_status_label = _make_label(load_box, "LoadStatus", "Choose a save slot.", 14)
	for slot_index in range(3):
		var button := _make_button(load_box, "LoadSlot%d" % (slot_index + 1), "Slot %d" % (slot_index + 1), Callable(self, "_on_load_slot_pressed").bind(slot_index))
		_load_slot_buttons.append(button)
	_load_back_button = _make_button(load_box, "LoadBackButton", "Back", Callable(self, "_on_load_back_pressed"))


func _make_panel(parent: Control, name: String, anchor_position: Vector2, pivot: Vector2, size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = name
	panel.anchor_left = anchor_position.x
	panel.anchor_top = anchor_position.y
	panel.anchor_right = anchor_position.x
	panel.anchor_bottom = anchor_position.y
	panel.offset_left = -size.x * pivot.x
	panel.offset_top = -size.y * pivot.y
	panel.offset_right = panel.offset_left + size.x
	panel.offset_bottom = panel.offset_top + size.y
	parent.add_child(panel)
	return panel


func _make_label(parent: VBoxContainer, name: String, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = name
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _make_button(parent: VBoxContainer, name: String, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = name
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 38.0)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _show_main_menu() -> void:
	if _game_host != null and is_instance_valid(_game_host):
		for child in _game_host.get_children():
			child.queue_free()
	_game_host.visible = false
	_menu_panel.visible = true
	_settings_panel.visible = false
	_load_panel.visible = false
	_refresh_save_menu_state()
	_update_status("Menu ready")


func _show_settings_menu() -> void:
	_menu_panel.visible = false
	_settings_panel.visible = true
	_load_panel.visible = false
	_update_status("Settings")


func _show_load_menu() -> void:
	_menu_panel.visible = false
	_settings_panel.visible = false
	_load_panel.visible = true
	_refresh_save_menu_state()
	_update_status("Select a save slot")


func _sync_settings_controls() -> void:
	if _settings_manager == null:
		return
	_master_volume_slider.value = _settings_manager.get_master_volume()
	_fullscreen_check.button_pressed = _settings_manager.get_fullscreen()


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
	_game_host.add_child(game)
	if game.has_signal("return_to_menu_requested") and not game.return_to_menu_requested.is_connected(_on_game_return_to_menu_requested):
		game.return_to_menu_requested.connect(_on_game_return_to_menu_requested)
	_game_host.visible = true
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
		_load_status_label.text = "Choose a save slot."
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
		button.text = String(summary.get("summary_text", "Slot %d" % (index + 1)))
		button.disabled = not bool(summary.get("occupied", false))


func _on_game_return_to_menu_requested() -> void:
	get_tree().paused = false
	_show_main_menu()


func _update_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
