extends Node
class_name WaveManager

signal wave_started(wave_number: int)
signal wave_cleared(wave_number: int)

@export var lane_ids: PackedStringArray = ["north", "east", "west"]

var active_wave: int = 0
var active_enemies: int = 0


func start_wave(wave_number: int) -> void:
	active_wave = wave_number
	active_enemies = 0
	wave_started.emit(active_wave)


func clear_wave() -> void:
	wave_cleared.emit(active_wave)
	active_wave = 0
	active_enemies = 0
