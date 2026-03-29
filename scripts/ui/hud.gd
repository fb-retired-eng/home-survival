extends CanvasLayer
class_name HUD

var player

@onready var health_label: Label = %HealthLabel
@onready var energy_label: Label = %EnergyLabel
@onready var wave_label: Label = %WaveLabel
@onready var phase_label: Label = %PhaseLabel
@onready var base_label: Label = %BaseLabel
@onready var resources_label: Label = %ResourcesLabel
@onready var status_label: Label = %StatusLabel
@onready var interaction_label: Label = %InteractionLabel


func bind_player(target) -> void:
	player = target
	player.health_changed.connect(_on_health_changed)
	player.energy_changed.connect(_on_energy_changed)
	player.resources_changed.connect(_on_resources_changed)
	player.interaction_prompt_changed.connect(set_interaction_prompt)
	_on_health_changed(player.current_health, player.max_health)
	_on_energy_changed(player.current_energy, player.max_energy)
	_on_resources_changed(player.resources.duplicate(true))
	set_interaction_prompt("")


func set_status(text: String) -> void:
	status_label.text = text


func set_interaction_prompt(text: String) -> void:
	interaction_label.text = text


func set_wave(current_wave: int, final_wave: int) -> void:
	wave_label.text = "Wave: %d / %d" % [current_wave, final_wave]


func set_phase(text: String) -> void:
	phase_label.text = text


func set_base_status(intact_count: int, breached_count: int, hp_percent: int) -> void:
	base_label.text = "Base: %d intact, %d breached, %d%% HP" % [intact_count, breached_count, hp_percent]


func _on_health_changed(current: int, maximum: int) -> void:
	health_label.text = "Health: %d / %d" % [current, maximum]


func _on_energy_changed(current: int, maximum: int) -> void:
	energy_label.text = "Energy: %d / %d" % [current, maximum]


func _on_resources_changed(resources: Dictionary) -> void:
	resources_label.text = "Salvage: %d   Parts: %d   Medicine: %d" % [
		int(resources.get("salvage", 0)),
		int(resources.get("parts", 0)),
		int(resources.get("medicine", 0)),
	]
