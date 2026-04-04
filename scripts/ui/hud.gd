extends CanvasLayer
class_name HUD

const FOG_START_DISTANCE := 560.0
const FOG_END_DISTANCE := 980.0
const FOG_MAX_ALPHA := 0.9
const FOG_PLAYER_CLEAR_RADIUS := 140.0
const FOG_PLAYER_CLEAR_FADE_RADIUS := 240.0
const FOG_COLOR := Color(0.03, 0.05, 0.06, 1.0)
const HUD_PANEL_OVERLAP_MARGIN := 18.0
const HUD_PANEL_VISIBLE_ALPHA := 1.0
const HUD_PANEL_FADED_ALPHA := 0.24
const PHASE_COLORS := {
	"Day": Color(0.72, 0.9, 0.68, 1.0),
	"Night": Color(0.96, 0.72, 0.44, 1.0),
	"Post-Wave": Color(0.62, 0.82, 0.96, 1.0),
	"Victory": Color(0.97, 0.84, 0.56, 1.0),
	"Loss": Color(0.92, 0.42, 0.44, 1.0),
}
const PHASE_PANEL_COLORS := {
	"Day": Color(0.16, 0.23, 0.16, 0.94),
	"Night": Color(0.25, 0.17, 0.1, 0.94),
	"Post-Wave": Color(0.13, 0.19, 0.25, 0.94),
	"Victory": Color(0.25, 0.2, 0.1, 0.94),
	"Loss": Color(0.29, 0.13, 0.14, 0.94),
}
const STATUS_COLORS := {
	"default": Color(0.92, 0.95, 0.97, 0.94),
	"warning": Color(0.99, 0.86, 0.59, 0.98),
	"danger": Color(0.98, 0.62, 0.62, 0.98),
	"success": Color(0.79, 0.93, 0.74, 0.98),
}
const WEAPON_LABEL_IDLE_COLOR := Color(0.96, 0.82, 0.54, 1.0)
const WEAPON_LABEL_FIRING_COLOR := Color(1.0, 0.94, 0.74, 1.0)

var player
var _health_current: int = 0
var _health_maximum: int = 0
var _energy_current: int = 0
var _energy_maximum: int = 0
var _wave_current: int = 0
var _wave_final: int = 0
var _phase_text: String = "Pre-Wave"
var _weapon_status_base_text: String = "Weapon: None"
var _firearm_windup_active: bool = false
var _power_status_text: String = ""

@onready var health_value_label: Label = %HealthValueLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var energy_value_label: Label = %EnergyValueLabel
@onready var energy_bar: ProgressBar = %EnergyBar
@onready var _main_panel: PanelContainer = $MainPanel
@onready var _status_panel: PanelContainer = $StatusPanel
@onready var wave_label: Label = %WaveLabel
@onready var _phase_label: Label = %PhaseLabel
@onready var _phase_chip: PanelContainer = %PhaseChip
@onready var base_label: Label = %BaseLabel
@onready var weapon_label: Label = %WeaponLabel
@onready var weapon_trait_label: Label = %WeaponTraitLabel
@onready var dog_label: Label = %DogLabel
@onready var power_label: Label = %PowerLabel
@onready var resources_label: RichTextLabel = %ResourcesLabel
@onready var status_label: Label = %StatusLabel
@onready var _status_title_label: Label = %StatusTitle
@onready var fog_overlay: ColorRect = %FogOverlay
@onready var interaction_panel: PanelContainer = %InteractionLabel.get_parent()
@onready var interaction_label: Label = %InteractionLabel
@onready var end_overlay: Control = %EndOverlay
@onready var end_title_label: Label = %EndTitleLabel
@onready var end_message_label: Label = %EndMessageLabel
@onready var _pause_overlay: Control = %PauseOverlay
@onready var _pause_status_label: Label = %PauseStatus
@onready var _pause_resume_button: Button = %PauseResumeButton
@onready var _pause_save_button: Button = %PauseSaveButton
@onready var _pause_save_quit_button: Button = %PauseSaveQuitButton

signal pause_toggle_requested
signal pause_resume_requested
signal pause_save_requested
signal pause_save_quit_requested


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	_pause_resume_button.pressed.connect(_on_pause_resume_pressed)
	_pause_save_button.pressed.connect(_on_pause_save_pressed)
	_pause_save_quit_button.pressed.connect(_on_pause_save_quit_pressed)
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
	player.firearm_windup_changed.connect(_on_firearm_windup_changed)
	_on_health_changed(player.current_health, player.max_health)
	_on_energy_changed(player.current_energy, player.max_energy)
	_on_resources_changed(player.resources.duplicate(true))
	_on_weapon_changed(player.get_equipped_weapon_display_name(), StringName())
	_on_weapon_status_changed(player.get_weapon_status_text())
	_on_weapon_trait_changed(player.get_weapon_trait_text())
	_on_firearm_windup_changed(false)
	set_interaction_prompt("")


func bind_dog(target) -> void:
	if target == null:
		dog_label.text = ""
		return
	target.status_changed.connect(_on_dog_status_changed)
	_on_dog_status_changed(target._build_status_text())


func set_power_status(used_slots: int, max_slots: int) -> void:
	_power_status_text = "Power %d/%d" % [used_slots, max_slots]
	power_label.text = _power_status_text
	power_label.visible = max_slots > 0


func _process(delta: float) -> void:
	_update_overlay_occlusion(delta)


func set_status(text: String) -> void:
	status_label.text = text
	var severity := _get_status_severity(text)
	status_label.add_theme_color_override("font_color", STATUS_COLORS.get(severity, STATUS_COLORS["default"]))
	match severity:
		"danger":
			_status_title_label.text = "ALERT"
		"warning":
			_status_title_label.text = "PRESSURE"
		"success":
			_status_title_label.text = "READY"
		_:
			_status_title_label.text = "FIELD STATUS"


func set_home_fog_state(home_world_position: Vector2, player_world_position: Vector2, screen_world_top_left: Vector2, screen_world_bottom_right: Vector2, reveal_texture: Texture2D, reveal_world_min: Vector2, reveal_world_max: Vector2) -> void:
	var material := fog_overlay.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("home_world_position", home_world_position)
	material.set_shader_parameter("player_world_position", player_world_position)
	material.set_shader_parameter("screen_world_top_left", screen_world_top_left)
	material.set_shader_parameter("screen_world_bottom_right", screen_world_bottom_right)
	material.set_shader_parameter("reveal_texture", reveal_texture)
	material.set_shader_parameter("reveal_world_min", reveal_world_min)
	material.set_shader_parameter("reveal_world_max", reveal_world_max)
	material.set_shader_parameter("fog_start_distance", FOG_START_DISTANCE)
	material.set_shader_parameter("fog_end_distance", FOG_END_DISTANCE)
	material.set_shader_parameter("fog_max_alpha", FOG_MAX_ALPHA)
	material.set_shader_parameter("player_clear_radius", FOG_PLAYER_CLEAR_RADIUS)
	material.set_shader_parameter("player_clear_fade_radius", FOG_PLAYER_CLEAR_FADE_RADIUS)
	material.set_shader_parameter("fog_color", FOG_COLOR)


func set_interaction_prompt(text: String) -> void:
	interaction_label.text = "Action: %s" % text if not text.is_empty() else ""
	interaction_panel.visible = not text.is_empty()


func show_end_overlay(title: String, message: String, accent: Color) -> void:
	end_title_label.text = title
	end_title_label.add_theme_color_override("font_color", accent)
	end_message_label.text = message
	end_overlay.visible = true


func hide_end_overlay() -> void:
	end_overlay.visible = false


func show_pause_menu(status_text: String = "Game paused") -> void:
	_pause_status_label.text = status_text
	_pause_overlay.visible = true
	_pause_resume_button.grab_focus()


func hide_pause_menu() -> void:
	if _pause_overlay != null:
		_pause_overlay.visible = false


func is_pause_menu_visible() -> bool:
	return _pause_overlay != null and _pause_overlay.visible


func set_pause_actions(active_wave: bool) -> void:
	if _pause_save_button == null or _pause_save_quit_button == null:
		return
	_pause_save_button.disabled = active_wave
	_pause_save_button.text = "Save Blocked" if active_wave else "Save Game"
	_pause_save_quit_button.text = "Quit Without Saving" if active_wave else "Save and Quit to Menu"


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
		_weapon_status_base_text = "Weapon: None"
		_refresh_weapon_status_display()
		return
	_weapon_status_base_text = "Weapon: %s" % display_name
	_refresh_weapon_status_display()


func _on_weapon_status_changed(text: String) -> void:
	_weapon_status_base_text = text
	_refresh_weapon_status_display()


func _on_weapon_trait_changed(text: String) -> void:
	if text.is_empty():
		weapon_trait_label.visible = false
		weapon_trait_label.text = ""
		return
	weapon_trait_label.visible = true
	weapon_trait_label.text = text


func _on_dog_status_changed(text: String) -> void:
	dog_label.text = text


func _on_firearm_windup_changed(active: bool) -> void:
	_firearm_windup_active = active
	_refresh_weapon_status_display()


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
	resources_label.text = (
		"[right]"
		+ "[color=#a69f86]🔩[/color] [color=#f5e6ae]%d[/color]  "
		+ "[color=#a69f86]⚙️[/color] [color=#f5e6ae]%d[/color]  "
		+ "[color=#a69f86]🩹[/color] [color=#f5e6ae]%d[/color]  "
		+ "[color=#a69f86]🍗[/color] [color=#f5e6ae]%d[/color]  "
		+ "[color=#a69f86]🔋[/color] [color=#b8f2a8]%d[/color]"
		+ "[/right]"
	) % [
		int(resources.get("salvage", 0)),
		int(resources.get("parts", 0)),
		int(resources.get("medicine", 0)),
		int(resources.get("food", 0)),
		int(resources.get("battery", 0)),
	]


func _refresh_vitals() -> void:
	health_value_label.text = "%d / %d" % [_health_current, _health_maximum]
	energy_value_label.text = "%d / %d" % [_energy_current, _energy_maximum]
	health_bar.max_value = max(_health_maximum, 1)
	health_bar.value = clamp(_health_current, 0, _health_maximum)
	energy_bar.max_value = max(_energy_maximum, 1)
	energy_bar.value = clamp(_energy_current, 0, _energy_maximum)


func _refresh_progress() -> void:
	wave_label.text = "Night %d / %d" % [_wave_current, _wave_final]
	_phase_label.text = _phase_text.to_upper()
	var accent: Color = PHASE_COLORS.get(_phase_text, Color(0.95, 0.97, 0.99, 1.0))
	_phase_label.add_theme_color_override("font_color", accent)
	wave_label.add_theme_color_override("font_color", accent.lightened(0.16))
	var stylebox := _phase_chip.get_theme_stylebox("panel")
	if stylebox is StyleBoxFlat:
		var chip_style := stylebox.duplicate() as StyleBoxFlat
		chip_style.bg_color = PHASE_PANEL_COLORS.get(_phase_text, Color(0.19, 0.25, 0.19, 0.94))
		chip_style.border_color = accent.darkened(0.15)
		_phase_chip.add_theme_stylebox_override("panel", chip_style)


func _refresh_weapon_status_display() -> void:
	if _weapon_status_base_text.is_empty():
		weapon_label.text = "Weapon: None"
		weapon_label.add_theme_color_override("font_color", WEAPON_LABEL_IDLE_COLOR)
		return
	weapon_label.text = _weapon_status_base_text
	weapon_label.add_theme_color_override("font_color", WEAPON_LABEL_FIRING_COLOR if _firearm_windup_active else WEAPON_LABEL_IDLE_COLOR)


func _get_status_severity(text: String) -> String:
	var lower := text.to_lower()
	if lower.contains("died") or lower.contains("failed") or lower.contains("blocked") or lower.contains("breached") or lower.contains("not enough"):
		return "danger"
	if lower.contains("need ") or lower.contains("incoming") or lower.contains("too close") or lower.contains("hold the") or lower.contains("night "):
		return "warning"
	if lower.contains("cleared") or lower.contains("saved") or lower.contains("ready") or lower.contains("survived"):
		return "success"
	return "default"


func _update_overlay_occlusion(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_set_panel_alpha(_main_panel, HUD_PANEL_VISIBLE_ALPHA)
		_set_panel_alpha(_status_panel, HUD_PANEL_VISIBLE_ALPHA)
		return
	var canvas_transform: Transform2D = get_viewport().get_canvas_transform()
	var player_screen_position: Vector2 = canvas_transform * player.global_position
	_update_panel_occlusion_alpha(_main_panel, player_screen_position, delta)
	_update_panel_occlusion_alpha(_status_panel, player_screen_position, delta)


func _update_panel_occlusion_alpha(panel: Control, player_screen_position: Vector2, delta: float) -> void:
	if panel == null or not is_instance_valid(panel) or not panel.visible:
		return
	var rect := panel.get_global_rect().grow(HUD_PANEL_OVERLAP_MARGIN)
	var target_alpha := HUD_PANEL_FADED_ALPHA if rect.has_point(player_screen_position) else HUD_PANEL_VISIBLE_ALPHA
	var current_alpha := panel.modulate.a
	panel.modulate.a = move_toward(current_alpha, target_alpha, delta * 5.0)


func _set_panel_alpha(panel: Control, alpha: float) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	panel.modulate.a = alpha
