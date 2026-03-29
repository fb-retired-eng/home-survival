extends Node2D
class_name Game

@onready var game_manager = $GameManager
@onready var player = $Player
@onready var hud = $HUD


func _ready() -> void:
	randomize()
	player.set_interaction_gate(Callable(self, "_can_player_interact_with"))
	hud.bind_player(player)
	game_manager.wave_changed.connect(_on_wave_changed)
	hud.set_interaction_prompt("")
	player.message_requested.connect(hud.set_status)
	player.player_died.connect(_on_player_died)
	game_manager.run_state_changed.connect(_on_run_state_changed)
	_on_wave_changed(game_manager.current_wave)
	_on_run_state_changed(game_manager.run_state)


func _on_player_died() -> void:
	game_manager.set_run_state(game_manager.RunState.LOSS)


func _on_run_state_changed(new_state: int) -> void:
	if new_state == game_manager.RunState.LOSS:
		player.cancel_timed_action()
		hud.set_status("You died")
		hud.set_interaction_prompt("Restart flow comes in a later milestone")
		return

	if new_state == game_manager.RunState.PRE_WAVE:
		_refresh_phase_status()


func _on_wave_changed(_new_wave: int) -> void:
	_refresh_phase_status()


func _refresh_phase_status() -> void:
	if game_manager.run_state != game_manager.RunState.PRE_WAVE:
		return

	if game_manager.current_wave <= 0:
		hud.set_status("Safe before first wave")
	elif game_manager.current_wave < 3:
		hud.set_status("Prepare for wave %d" % (game_manager.current_wave + 1))
	else:
		hud.set_status("Final preparations")


func _can_player_interact_with(_interactable) -> bool:
	return game_manager.run_state == game_manager.RunState.PRE_WAVE
