extends Node2D
class_name Game

@onready var game_manager = $GameManager
@onready var player = $Player
@onready var hud = $HUD


func _ready() -> void:
	hud.bind_player(player)
	hud.set_status("MVP0 prototype scaffold")
	hud.set_interaction_prompt("Move: WASD/Arrows  Attack: J/Click  Heal: F/Q")
	player.message_requested.connect(hud.set_status)
	player.player_died.connect(_on_player_died)
	game_manager.run_state_changed.connect(_on_run_state_changed)
	_on_run_state_changed(game_manager.run_state)


func _on_player_died() -> void:
	game_manager.set_run_state(game_manager.RunState.LOSS)


func _on_run_state_changed(new_state: int) -> void:
	if new_state == game_manager.RunState.LOSS:
		hud.set_status("You died")
		hud.set_interaction_prompt("Restart flow comes in a later milestone")
