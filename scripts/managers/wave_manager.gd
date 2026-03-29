extends Node
class_name WaveManager

signal wave_started(wave_number: int)
signal wave_cleared(wave_number: int)

const WAVE_DEFINITIONS := {
	1: {
		"spawn_interval": 0.9,
		"lanes": [
			{"id": "north", "count": 3},
			{"id": "west", "count": 2},
		],
	},
	2: {
		"spawn_interval": 0.75,
		"lanes": [
			{"id": "north", "count": 3},
			{"id": "east", "count": 2},
			{"id": "west", "count": 2},
		],
	},
	3: {
		"spawn_interval": 0.6,
		"lanes": [
			{"id": "north", "count": 4},
			{"id": "east", "count": 3},
			{"id": "west", "count": 3},
		],
	},
}

@export var zombie_scene: PackedScene

var active_wave: int = 0
var active_enemies: int = 0
var _spawn_queue: Array[StringName] = []
var _spawn_interval: float = 1.0
var _spawn_markers: Dictionary = {}
var _enemy_parent: Node2D
var _player
var _socket_container: Node
var _spawn_timer: Timer


func _ready() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = true
	add_child(_spawn_timer)
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)


func configure(spawn_markers: Dictionary, enemy_parent: Node2D, player_ref, socket_container: Node) -> void:
	_spawn_markers = spawn_markers.duplicate()
	_enemy_parent = enemy_parent
	_player = player_ref
	_socket_container = socket_container


func has_wave_definition(wave_number: int) -> bool:
	return WAVE_DEFINITIONS.has(wave_number)


func can_start_wave(wave_number: int) -> bool:
	return _validate_wave_setup(wave_number, false)


func get_highest_defined_wave() -> int:
	var highest_wave := 0
	for wave_number in WAVE_DEFINITIONS.keys():
		highest_wave = max(highest_wave, int(wave_number))
	return highest_wave


func reset() -> void:
	if _spawn_timer != null:
		_spawn_timer.stop()

	_spawn_queue.clear()
	_spawn_interval = 1.0
	active_wave = 0
	active_enemies = 0

	if _enemy_parent == null:
		return

	for child in _enemy_parent.get_children():
		child.queue_free()


func start_wave(wave_number: int) -> bool:
	if not _validate_wave_setup(wave_number, true):
		return false

	reset()

	var definition: Dictionary = WAVE_DEFINITIONS.get(wave_number, {})
	active_wave = wave_number
	active_enemies = 0
	_spawn_interval = float(definition.get("spawn_interval", 1.0))
	_build_spawn_queue(definition)
	wave_started.emit(active_wave)
	_spawn_next_enemy()
	return true


func clear_wave() -> void:
	if active_wave == 0:
		return

	if _spawn_timer != null:
		_spawn_timer.stop()

	var cleared_wave := active_wave
	_spawn_queue.clear()
	active_wave = 0
	active_enemies = 0
	wave_cleared.emit(cleared_wave)


func _build_spawn_queue(definition: Dictionary) -> void:
	_spawn_queue.clear()
	var pending: Array[Dictionary] = []

	for lane_entry in definition.get("lanes", []):
		pending.append({
			"id": StringName(str(lane_entry.get("id", ""))),
			"remaining": int(lane_entry.get("count", 0)),
		})

	var has_remaining := true
	while has_remaining:
		has_remaining = false
		for pending_lane in pending:
			if int(pending_lane.get("remaining", 0)) <= 0:
				continue

			has_remaining = true
			_spawn_queue.append(StringName(pending_lane.get("id", &"")))
			pending_lane["remaining"] = int(pending_lane.get("remaining", 0)) - 1


func _validate_wave_setup(wave_number: int, emit_warnings: bool) -> bool:
	var definition: Dictionary = WAVE_DEFINITIONS.get(wave_number, {})
	if definition.is_empty():
		if emit_warnings:
			push_warning("Missing wave definition for wave %d" % wave_number)
		return false

	if zombie_scene == null:
		if emit_warnings:
			push_warning("WaveManager is missing zombie_scene")
		return false

	if _enemy_parent == null:
		if emit_warnings:
			push_warning("WaveManager is missing enemy parent")
		return false

	var lanes: Array = definition.get("lanes", [])
	if lanes.is_empty():
		if emit_warnings:
			push_warning("Wave %d has no lane entries" % wave_number)
		return false

	for lane_entry in lanes:
		var lane_id := String(lane_entry.get("id", ""))
		var lane_count := int(lane_entry.get("count", 0))
		if lane_id.is_empty() or lane_count <= 0:
			if emit_warnings:
				push_warning("Wave %d has an invalid lane entry" % wave_number)
			return false

		if not _spawn_markers.has(lane_id) or _spawn_markers.get(lane_id) == null:
			if emit_warnings:
				push_warning("Wave %d is missing spawn marker for lane %s" % [wave_number, lane_id])
			return false

	return true


func _spawn_next_enemy() -> void:
	if _spawn_queue.is_empty():
		if active_enemies == 0:
			clear_wave()
		return

	if zombie_scene == null or _enemy_parent == null:
		push_warning("WaveManager is missing spawn configuration")
		_spawn_queue.clear()
		clear_wave()
		return

	var lane_id := String(_spawn_queue.pop_front())
	var marker: Node2D = _spawn_markers.get(lane_id, null)
	if marker == null:
		push_warning("Missing spawn marker for lane %s" % lane_id)
	else:
		var zombie = zombie_scene.instantiate()
		_enemy_parent.add_child(zombie)
		zombie.global_position = marker.global_position
		if zombie.has_method("configure_wave_context"):
			zombie.configure_wave_context(_player, _get_defense_sockets())
		if zombie.has_signal("died"):
			zombie.died.connect(_on_zombie_died)
		active_enemies += 1

	if not _spawn_queue.is_empty():
		_spawn_timer.start(_spawn_interval)
	elif active_enemies == 0:
		clear_wave()


func _get_defense_sockets() -> Array:
	var sockets: Array = []
	if _socket_container == null:
		return sockets

	for child in _socket_container.get_children():
		sockets.append(child)

	return sockets


func _on_spawn_timer_timeout() -> void:
	_spawn_next_enemy()


func _on_zombie_died(_zombie) -> void:
	active_enemies = max(active_enemies - 1, 0)
	if _spawn_queue.is_empty() and active_enemies == 0:
		clear_wave()
