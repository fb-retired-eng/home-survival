extends Node
class_name GameManager

signal run_state_changed(new_state: RunState)
signal wave_changed(new_wave: int)
signal run_reset()

enum RunState {
	PRE_WAVE,
	ACTIVE_WAVE,
	POST_WAVE,
	WIN,
	LOSS,
}

@export var starting_wave: int = 0
@export var final_wave: int = 3

var current_wave: int = 0
var run_state: RunState = RunState.PRE_WAVE


func _ready() -> void:
	reset_run()


func set_run_state(new_state: RunState) -> void:
	if run_state == new_state:
		return

	run_state = new_state
	run_state_changed.emit(run_state)


func set_wave(new_wave: int) -> void:
	if current_wave == new_wave:
		return

	current_wave = new_wave
	wave_changed.emit(current_wave)


func reset_run() -> void:
	current_wave = starting_wave
	run_state = RunState.PRE_WAVE
	wave_changed.emit(current_wave)
	run_state_changed.emit(run_state)
	run_reset.emit()


func can_start_next_wave() -> bool:
	return run_state == RunState.PRE_WAVE and current_wave < final_wave


func start_next_wave() -> int:
	if not can_start_next_wave():
		return current_wave

	set_wave(current_wave + 1)
	set_run_state(RunState.ACTIVE_WAVE)
	return current_wave


func complete_active_wave() -> void:
	if run_state != RunState.ACTIVE_WAVE:
		return

	if current_wave >= final_wave:
		set_run_state(RunState.WIN)
		return

	set_run_state(RunState.POST_WAVE)
