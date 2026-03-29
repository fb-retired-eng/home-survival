extends Node2D
class_name Game

@onready var game_manager = $GameManager
@onready var player = $Player
@onready var hud = $HUD
@onready var wave_manager = $WaveManager
@onready var sleep_point: Area2D = $World/SleepPoint
@onready var spawn_markers_root: Node2D = $World/SpawnMarkers
@onready var defense_sockets: Node2D = $World/DefenseSockets
@onready var wave_enemy_layer: Node2D = $World/WaveEnemies


func _ready() -> void:
	randomize()
	player.set_interaction_gate(Callable(self, "_can_player_interact_with"))
	sleep_point.configure(Callable(self, "_can_player_sleep"), Callable(self, "_get_sleep_label"))
	hud.bind_player(player)
	wave_manager.configure(_collect_spawn_markers(), wave_enemy_layer, player, defense_sockets)
	_sync_final_wave_with_definitions()
	game_manager.wave_changed.connect(_on_wave_changed)
	game_manager.run_reset.connect(_on_run_reset)
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_cleared.connect(_on_wave_cleared)
	sleep_point.sleep_requested.connect(_on_sleep_requested)
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
		wave_manager.reset()
		player.cancel_timed_action()
		hud.set_status("You died")
		hud.set_interaction_prompt("Restart flow comes in a later milestone")
		return

	if new_state == game_manager.RunState.WIN:
		wave_manager.reset()
		hud.set_status("You survived all 3 waves")
		hud.set_interaction_prompt("Restart flow comes in a later milestone")
		return

	if new_state == game_manager.RunState.ACTIVE_WAVE:
		hud.set_status("Wave %d in progress" % game_manager.current_wave)
		player.refresh_interaction_prompt()
		return

	if new_state == game_manager.RunState.PRE_WAVE:
		player.refresh_interaction_prompt()
		_refresh_phase_status()


func _on_wave_changed(new_wave: int) -> void:
	hud.set_wave(new_wave, game_manager.final_wave)
	player.refresh_interaction_prompt()
	_refresh_phase_status()


func _refresh_phase_status() -> void:
	if game_manager.run_state != game_manager.RunState.PRE_WAVE:
		return

	if game_manager.current_wave <= 0:
		hud.set_status("Safe before first wave")
	elif game_manager.current_wave < game_manager.final_wave:
		hud.set_status("Wave %d cleared. Prepare for wave %d" % [game_manager.current_wave, game_manager.current_wave + 1])
	else:
		hud.set_status("Final preparations")


func _can_player_interact_with(_interactable) -> bool:
	return game_manager.run_state == game_manager.RunState.PRE_WAVE


func _can_player_sleep(_player) -> bool:
	return game_manager.can_start_next_wave()


func _get_sleep_label(_player) -> String:
	if not game_manager.can_start_next_wave():
		return ""

	var next_wave: int = game_manager.current_wave + 1
	if not wave_manager.can_start_wave(next_wave):
		return "Wave %d not configured" % next_wave

	return "Sleep and start wave %d" % (game_manager.current_wave + 1)


func _on_sleep_requested(_player) -> void:
	var next_wave: int = game_manager.current_wave + 1
	if not _can_player_sleep(_player):
		hud.set_status("Wave %d is not configured" % next_wave)
		return

	if not wave_manager.can_start_wave(next_wave):
		hud.set_status("Wave %d is not configured" % next_wave)
		player.refresh_interaction_prompt()
		return

	if not wave_manager.start_wave(next_wave):
		hud.set_status("Wave %d failed to start" % next_wave)
		return

	player.restore_full_energy()
	game_manager.set_wave(next_wave)
	game_manager.set_run_state(game_manager.RunState.ACTIVE_WAVE)


func _on_wave_started(wave_number: int) -> void:
	hud.set_status("Wave %d in progress" % wave_number)


func _on_wave_cleared(_wave_number: int) -> void:
	game_manager.complete_active_wave()


func _on_run_reset() -> void:
	wave_manager.reset()
	player.reset_for_new_run()
	for socket in get_tree().get_nodes_in_group("defense_sockets"):
		if socket.has_method("reset_for_new_run"):
			socket.reset_for_new_run()
	for node in get_tree().get_nodes_in_group("scavenge_nodes"):
		if node.has_method("reset_for_new_run"):
			node.reset_for_new_run()
	player.refresh_interaction_prompt()


func _collect_spawn_markers() -> Dictionary:
	var markers := {}

	for child in spawn_markers_root.get_children():
		markers[String(child.name).to_lower()] = child

	return markers


func _sync_final_wave_with_definitions() -> void:
	var defined_final_wave: int = wave_manager.get_highest_defined_wave()
	if defined_final_wave > 0:
		game_manager.final_wave = defined_final_wave
