extends CanvasLayer
class_name HUD

const FOG_START_DISTANCE := 720.0
const FOG_END_DISTANCE := 1320.0
const FOG_MAX_ALPHA := 0.82
const FOG_COLOR := Color(0.03, 0.05, 0.06, 1.0)

var player
var _health_current: int = 0
var _health_maximum: int = 0
var _energy_current: int = 0
var _energy_maximum: int = 0
var _wave_current: int = 0
var _wave_final: int = 0
var _phase_text: String = "Pre-Wave"
var _pause_overlay: Control
var _pause_panel: PanelContainer
var _pause_status_label: Label
var _pause_resume_button: Button
var _pause_save_button: Button
var _pause_save_quit_button: Button

@onready var health_value_label: Label = %HealthValueLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var energy_value_label: Label = %EnergyValueLabel
@onready var energy_bar: ProgressBar = %EnergyBar
@onready var wave_label: Label = %WaveLabel
@onready var base_label: Label = %BaseLabel
@onready var weapon_label: Label = %WeaponLabel
@onready var weapon_trait_label: Label = %WeaponTraitLabel
@onready var resources_label: Label = %ResourcesLabel
@onready var status_label: Label = %StatusLabel
@onready var fog_overlay: ColorRect = %FogOverlay
@onready var interaction_panel: PanelContainer = %InteractionLabel.get_parent()
@onready var interaction_label: Label = %InteractionLabel
@onready var end_overlay: Control = %EndOverlay
@onready var end_title_label: Label = %EndTitleLabel
@onready var end_message_label: Label = %EndMessageLabel

signal pause_toggle_requested
signal pause_resume_requested
signal pause_save_requested
signal pause_save_quit_requested


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_pause_menu()
	hide_pause_menu()


func bind_player(target) -> void:
	player = target
	player.health_changed.connect(_on_health_changed)
	player.energy_changed.connect(_on_energy_changed)
	player.resources_changed.connect(_on_resources_changed)
	player.interaction_prompt_changed.connect(set_interaction_prompt)
	player.weapon_changed.connect(_on_weapon_changed)
	player.weapon_status_changed.connect(_on_weapon_status_changed)
	player.weapon_trait_changed.connect(_on_weapon_trait_changed)
	_on_health_changed(player.current_health, player.max_health)
	_on_energy_changed(player.current_energy, player.max_energy)
	_on_resources_changed(player.resources.duplicate(true))
	_on_weapon_changed(player.get_equipped_weapon_display_name(), StringName())
	_on_weapon_status_changed(player.get_weapon_status_text())
	_on_weapon_trait_changed(player.get_weapon_trait_text())
	set_interaction_prompt("")


func _build_pause_menu() -> void:
	if _pause_overlay != null:
		return

	_pause_overlay = Control.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.anchor_right = 1.0
	_pause_overlay.anchor_bottom = 1.0
	_pause_overlay.offset_left = 0.0
	_pause_overlay.offset_top = 0.0
	_pause_overlay.offset_right = 0.0
	_pause_overlay.offset_bottom = 0.0
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_overlay)

	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.anchor_right = 1.0
	dimmer.anchor_bottom = 1.0
	dimmer.offset_left = 0.0
	dimmer.offset_top = 0.0
	dimmer.offset_right = 0.0
	dimmer.offset_bottom = 0.0
	dimmer.color = Color(0.02, 0.03, 0.04, 0.82)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(dimmer)

	_pause_panel = PanelContainer.new()
	_pause_panel.name = "PausePanel"
	_pause_panel.anchor_left = 0.5
	_pause_panel.anchor_top = 0.5
	_pause_panel.anchor_right = 0.5
	_pause_panel.anchor_bottom = 0.5
	_pause_panel.offset_left = -210.0
	_pause_panel.offset_top = -150.0
	_pause_panel.offset_right = 210.0
	_pause_panel.offset_bottom = 150.0
	_pause_overlay.add_child(_pause_panel)

	var pause_box := VBoxContainer.new()
	pause_box.name = "PauseBox"
	pause_box.anchor_right = 1.0
	pause_box.anchor_bottom = 1.0
	pause_box.offset_left = 24.0
	pause_box.offset_top = 18.0
	pause_box.offset_right = -24.0
	pause_box.offset_bottom = -18.0
	pause_box.add_theme_constant_override("separation", 10)
	_pause_panel.add_child(pause_box)

	var pause_title := Label.new()
	pause_title.name = "PauseTitle"
	pause_title.text = "Paused"
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.add_theme_font_size_override("font_size", 26)
	pause_box.add_child(pause_title)

	_pause_status_label = Label.new()
	_pause_status_label.name = "PauseStatus"
	_pause_status_label.text = "Game is paused."
	_pause_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pause_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_status_label.add_theme_font_size_override("font_size", 13)
	_pause_status_label.add_theme_color_override("font_color", Color(0.9, 0.94, 0.97, 0.9))
	pause_box.add_child(_pause_status_label)

	_pause_resume_button = Button.new()
	_pause_resume_button.text = "Resume"
	_pause_resume_button.pressed.connect(_on_pause_resume_pressed)
	pause_box.add_child(_pause_resume_button)

	_pause_save_button = Button.new()
	_pause_save_button.text = "Save Game"
	_pause_save_button.pressed.connect(_on_pause_save_pressed)
	pause_box.add_child(_pause_save_button)

	_pause_save_quit_button = Button.new()
	_pause_save_quit_button.text = "Save and Quit to Menu"
	_pause_save_quit_button.pressed.connect(_on_pause_save_quit_pressed)
	pause_box.add_child(_pause_save_quit_button)


func set_status(text: String) -> void:
	status_label.text = text


func set_home_fog_state(home_world_position: Vector2, camera_world_position: Vector2, camera_zoom: Vector2, viewport_size: Vector2, reveal_texture: Texture2D, reveal_world_min: Vector2, reveal_world_max: Vector2) -> void:
	var material := fog_overlay.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("home_world_position", home_world_position)
	material.set_shader_parameter("camera_world_position", camera_world_position)
	material.set_shader_parameter("camera_zoom", camera_zoom)
	material.set_shader_parameter("viewport_size", viewport_size)
	material.set_shader_parameter("reveal_texture", reveal_texture)
	material.set_shader_parameter("reveal_world_min", reveal_world_min)
	material.set_shader_parameter("reveal_world_max", reveal_world_max)
	material.set_shader_parameter("fog_start_distance", FOG_START_DISTANCE)
	material.set_shader_parameter("fog_end_distance", FOG_END_DISTANCE)
	material.set_shader_parameter("fog_max_alpha", FOG_MAX_ALPHA)
	material.set_shader_parameter("fog_color", FOG_COLOR)


func set_interaction_prompt(text: String) -> void:
	interaction_label.text = text
	interaction_panel.visible = not text.is_empty()


func show_end_overlay(title: String, message: String, accent: Color) -> void:
	end_title_label.text = title
	end_title_label.add_theme_color_override("font_color", accent)
	end_message_label.text = message
	end_overlay.visible = true


func hide_end_overlay() -> void:
	end_overlay.visible = false


func show_pause_menu(status_text: String = "Game paused") -> void:
	_build_pause_menu()
	_pause_status_label.text = status_text
	_pause_overlay.visible = true


func hide_pause_menu() -> void:
	if _pause_overlay != null:
		_pause_overlay.visible = false


func is_pause_menu_visible() -> bool:
	return _pause_overlay != null and _pause_overlay.visible


func set_wave(current_wave: int, final_wave: int) -> void:
	_wave_current = current_wave
	_wave_final = final_wave
	_refresh_progress()


func set_phase(text: String) -> void:
	_phase_text = text.replace("Phase: ", "")
	_refresh_progress()


func set_base_status(intact_count: int, breached_count: int, hp_percent: int) -> void:
	base_label.text = "Base %d intact  |  %d breached  |  %d%% integrity" % [intact_count, breached_count, hp_percent]


func _on_weapon_changed(display_name: String, _weapon_id: StringName) -> void:
	if display_name.is_empty():
		weapon_label.text = "Weapon: None"
		return
	weapon_label.text = "Weapon: %s" % display_name


func _on_weapon_status_changed(text: String) -> void:
	weapon_label.text = text


func _on_weapon_trait_changed(text: String) -> void:
	if text.is_empty():
		weapon_trait_label.visible = false
		weapon_trait_label.text = ""
		return
	weapon_trait_label.visible = true
	weapon_trait_label.text = text


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause_game"):
		return
	get_viewport().set_input_as_handled()
	if is_pause_menu_visible():
		pause_resume_requested.emit()
		return
	pause_toggle_requested.emit()


func _on_pause_resume_pressed() -> void:
	pause_resume_requested.emit()


func _on_pause_save_pressed() -> void:
	pause_save_requested.emit()


func _on_pause_save_quit_pressed() -> void:
	pause_save_quit_requested.emit()


func _on_health_changed(current: int, maximum: int) -> void:
	_health_current = current
	_health_maximum = maximum
	_refresh_vitals()


func _on_energy_changed(current: int, maximum: int) -> void:
	_energy_current = current
	_energy_maximum = maximum
	_refresh_vitals()


func _on_resources_changed(resources: Dictionary) -> void:
	resources_label.text = "🔩%d  ⚙️%d  🩹%d  ◉%d" % [
		int(resources.get("salvage", 0)),
		int(resources.get("parts", 0)),
		int(resources.get("medicine", 0)),
		int(resources.get("bullets", 0)),
	]
	resources_label.text += "  🍗%d" % int(resources.get("food", 0))


func _refresh_vitals() -> void:
	health_value_label.text = "%d / %d" % [_health_current, _health_maximum]
	energy_value_label.text = "%d / %d" % [_energy_current, _energy_maximum]
	health_bar.max_value = max(_health_maximum, 1)
	health_bar.value = clamp(_health_current, 0, _health_maximum)
	energy_bar.max_value = max(_energy_maximum, 1)
	energy_bar.value = clamp(_energy_current, 0, _energy_maximum)


func _refresh_progress() -> void:
	wave_label.text = "Wave %d / %d   |   %s" % [_wave_current, _wave_final, _phase_text]
