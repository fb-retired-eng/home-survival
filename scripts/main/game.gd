extends Node2D
class_name Game

const BASE_PERIMETER_DEFINITION_SCRIPT := preload("res://scripts/data/base_perimeter_definition.gd")
const PERIMETER_SEGMENT_DEFINITION_SCRIPT := preload("res://scripts/data/perimeter_segment_definition.gd")
const STRUCTURE_PROFILE_SCRIPT := preload("res://scripts/data/structure_profile.gd")

@export var defense_socket_scene: PackedScene
@export var perimeter_definition: Resource

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
	_build_defense_sockets()
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
	_connect_defense_socket_signals()
	hud.set_interaction_prompt("")
	player.message_requested.connect(hud.set_status)
	player.player_died.connect(_on_player_died)
	game_manager.run_state_changed.connect(_on_run_state_changed)
	_on_wave_changed(game_manager.current_wave)
	_on_run_state_changed(game_manager.run_state)
	_refresh_base_status()


func _build_defense_sockets() -> void:
	for child in defense_sockets.get_children():
		child.queue_free()

	if defense_socket_scene == null:
		push_warning("Game is missing defense_socket_scene")
		return

	if perimeter_definition == null:
		push_warning("Game is missing perimeter_definition")
		return

	if perimeter_definition.get_script() != BASE_PERIMETER_DEFINITION_SCRIPT:
		push_warning("Game perimeter_definition is not a BasePerimeterDefinition resource")
		return

	var seen_socket_ids := {}
	for segment in perimeter_definition.segments:
		if not _is_valid_perimeter_segment(segment, seen_socket_ids):
			continue

		var socket = defense_socket_scene.instantiate()
		socket.position = segment.position
		socket.socket_id = segment.socket_id
		socket.socket_type = segment.socket_type
		socket.tier = segment.tier
		socket.current_hp = segment.current_hp
		socket.structure_profile = segment.structure_profile
		socket.socket_size = segment.socket_size
		socket.interaction_area_offset = segment.interaction_area_offset
		socket.interaction_area_size = segment.interaction_area_size
		defense_sockets.add_child(socket)


func _is_valid_perimeter_segment(segment: Resource, seen_socket_ids: Dictionary) -> bool:
	if segment == null:
		push_warning("Perimeter definition contains a null segment")
		return false

	if segment.get_script() != PERIMETER_SEGMENT_DEFINITION_SCRIPT:
		push_warning("Perimeter definition contains an invalid segment resource")
		return false

	var socket_id := String(segment.socket_id)
	if socket_id.is_empty():
		push_warning("Perimeter segment is missing socket_id")
		return false

	if seen_socket_ids.has(socket_id):
		push_warning("Perimeter definition contains a duplicate socket_id: %s" % socket_id)
		return false

	if segment.socket_type != "wall" and segment.socket_type != "door":
		push_warning("Perimeter segment %s has invalid socket_type %s" % [socket_id, segment.socket_type])
		return false

	if segment.socket_size.x <= 0.0 or segment.socket_size.y <= 0.0:
		push_warning("Perimeter segment %s has invalid socket_size" % socket_id)
		return false

	if segment.interaction_area_size.x <= 0.0 or segment.interaction_area_size.y <= 0.0:
		push_warning("Perimeter segment %s has invalid interaction_area_size" % socket_id)
		return false

	if segment.structure_profile == null or segment.structure_profile.get_script() != STRUCTURE_PROFILE_SCRIPT:
		push_warning("Perimeter segment %s is missing a valid structure_profile" % socket_id)
		return false

	seen_socket_ids[socket_id] = true
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("restart_run"):
		return

	if game_manager.run_state != game_manager.RunState.WIN and game_manager.run_state != game_manager.RunState.LOSS:
		return

	get_viewport().set_input_as_handled()
	game_manager.reset_run()


func _on_player_died() -> void:
	game_manager.set_run_state(game_manager.RunState.LOSS)


func _on_run_state_changed(new_state: int) -> void:
	if new_state == game_manager.RunState.LOSS:
		wave_manager.reset()
		player.cancel_timed_action()
		hud.set_phase("Phase: Loss")
		hud.set_status("You died")
		hud.set_interaction_prompt("Press R to restart")
		return

	if new_state == game_manager.RunState.WIN:
		wave_manager.reset()
		hud.set_phase("Phase: Victory")
		hud.set_status("You survived all 3 waves")
		hud.set_interaction_prompt("Press R to restart")
		return

	if new_state == game_manager.RunState.ACTIVE_WAVE:
		hud.set_phase("Phase: Active Wave")
		hud.set_status("Wave %d in progress. Defend the base." % game_manager.current_wave)
		player.refresh_interaction_prompt()
		return

	if new_state == game_manager.RunState.PRE_WAVE:
		hud.set_phase("Phase: Pre-Wave")
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
		hud.set_status("Safe before first wave. Scavenge, strengthen, then sleep.")
	elif game_manager.current_wave < game_manager.final_wave:
		hud.set_status("Wave %d cleared. Repair, strengthen, scavenge, then sleep for wave %d." % [game_manager.current_wave, game_manager.current_wave + 1])
	else:
		hud.set_status("Wave %d cleared. Final preparations before wave %d." % [game_manager.current_wave, game_manager.current_wave + 1])


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
	hud.set_phase("Phase: Active Wave")
	hud.set_status("Wave %d incoming. Hold the perimeter." % wave_number)


func _on_wave_cleared(_wave_number: int) -> void:
	game_manager.complete_active_wave()


func _on_run_reset() -> void:
	wave_manager.reset()
	for pickup in get_tree().get_nodes_in_group("pickups"):
		pickup.queue_free()
	player.reset_for_new_run()
	for socket in get_tree().get_nodes_in_group("defense_sockets"):
		if socket.has_method("reset_for_new_run"):
			socket.reset_for_new_run()
	for node in get_tree().get_nodes_in_group("scavenge_nodes"):
		if node.has_method("reset_for_new_run"):
			node.reset_for_new_run()
	_refresh_base_status()
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


func _connect_defense_socket_signals() -> void:
	for socket in get_tree().get_nodes_in_group("defense_sockets"):
		if not socket.has_signal("state_changed"):
			continue
		if not socket.state_changed.is_connected(_on_defense_socket_state_changed):
			socket.state_changed.connect(_on_defense_socket_state_changed)


func _on_defense_socket_state_changed(_socket) -> void:
	_refresh_base_status()


func _refresh_base_status() -> void:
	var sockets := get_tree().get_nodes_in_group("defense_sockets")
	if sockets.is_empty():
		hud.set_base_status(0, 0, 0)
		return

	var intact_count := 0
	var breached_count := 0
	var total_hp := 0
	var total_max_hp := 0

	for socket in sockets:
		if not is_instance_valid(socket):
			continue

		total_hp += int(socket.current_hp)
		total_max_hp += int(socket.max_hp)
		if socket.has_method("is_breached") and socket.is_breached():
			breached_count += 1
		else:
			intact_count += 1

	var hp_percent := 0
	if total_max_hp > 0:
		hp_percent = int(round((float(total_hp) / float(total_max_hp)) * 100.0))

	hud.set_base_status(intact_count, breached_count, hp_percent)
