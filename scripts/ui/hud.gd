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
