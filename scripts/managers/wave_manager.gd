extends Node
class_name WaveManager

signal wave_started(wave_number: int)
signal wave_cleared(wave_number: int)

const WAVE_SET_DEFINITION_SCRIPT := preload("res://scripts/data/wave_set_definition.gd")
const WAVE_DEFINITION_SCRIPT := preload("res://scripts/data/wave_definition.gd")
const WAVE_LANE_DEFINITION_SCRIPT := preload("res://scripts/data/wave_lane_definition.gd")
const ENEMY_DEFINITION_SCRIPT := preload("res://scripts/data/enemy_definition.gd")

@export var zombie_scene: PackedScene
@export var wave_set_definition: Resource
@export_range(0.0, 128.0, 1.0) var spawn_jitter_radius: float = 32.0
@export_range(1, 12, 1) var spawn_jitter_attempts: int = 6

var active_wave: int = 0
var active_enemies: int = 0
var _spawn_queue: Array[Dictionary] = []
var _spawn_interval: float = 1.0
var _spawn_markers: Dictionary = {}
var _enemy_parent: Node2D
var _player
var _socket_container: Node
var _spawn_timer: Timer
var _wave_definitions: Dictionary = {}


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
	_rebuild_wave_definition_cache()


func has_wave_definition(wave_number: int) -> bool:
	return _wave_definitions.has(wave_number)


func can_start_wave(wave_number: int) -> bool:
	return _validate_wave_setup(wave_number, false)


func get_highest_defined_wave() -> int:
	var highest_wave := 0
	for wave_number in _wave_definitions.keys():
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

	var definition: Dictionary = _wave_definitions.get(wave_number, {})
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
		var lane_id := String(lane_entry.get("id", ""))
		pending.append({
			"lane_id": StringName(lane_id),
			"remaining": int(lane_entry.get("count", 0)),
			"enemy_definition": lane_entry.get("enemy_definition"),
			"preferred_socket_ids": Array(lane_entry.get("preferred_socket_ids", [])),
		})

	var has_remaining := true
	while has_remaining:
		has_remaining = false
		for pending_lane in pending:
			if int(pending_lane.get("remaining", 0)) <= 0:
				continue

			has_remaining = true
			_spawn_queue.append({
				"lane_id": StringName(pending_lane.get("lane_id", &"")),
				"enemy_definition": pending_lane.get("enemy_definition"),
				"preferred_socket_ids": Array(pending_lane.get("preferred_socket_ids", [])),
			})
			pending_lane["remaining"] = int(pending_lane.get("remaining", 0)) - 1


func _validate_wave_setup(wave_number: int, emit_warnings: bool) -> bool:
	var definition: Dictionary = _wave_definitions.get(wave_number, {})
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

	if _player == null or not is_instance_valid(_player):
		if emit_warnings:
			push_warning("WaveManager is missing player reference")
		return false

	if _socket_container == null or not is_instance_valid(_socket_container):
		if emit_warnings:
			push_warning("WaveManager is missing defense socket container")
		return false

	if _get_defense_sockets().is_empty():
		if emit_warnings:
			push_warning("WaveManager found no defense sockets")
		return false

	var valid_socket_ids := {}
	for socket in _get_defense_sockets():
		if not is_instance_valid(socket):
			continue
		valid_socket_ids[String(socket.socket_id)] = true

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

		var enemy_definition: Resource = lane_entry.get("enemy_definition")
		if enemy_definition == null or enemy_definition.get_script() != ENEMY_DEFINITION_SCRIPT:
			if emit_warnings:
				push_warning("Wave %d lane %s is missing a valid enemy_definition" % [wave_number, lane_id])
			return false
		if not enemy_definition.is_valid_definition():
			if emit_warnings:
				push_warning("Wave %d lane %s has an invalid enemy_definition resource" % [wave_number, lane_id])
			return false

		for preferred_socket_id in lane_entry.get("preferred_socket_ids", []):
			var socket_id := String(preferred_socket_id)
			if socket_id.is_empty() or not valid_socket_ids.has(socket_id):
				if emit_warnings:
					push_warning("Wave %d lane %s references unknown preferred socket %s" % [wave_number, lane_id, socket_id])
				return false

		if not _spawn_markers.has(lane_id) or _spawn_markers.get(lane_id) == null:
			if emit_warnings:
				push_warning("Wave %d is missing spawn marker for lane %s" % [wave_number, lane_id])
			return false

	return true


func _rebuild_wave_definition_cache() -> void:
	_wave_definitions.clear()

	if wave_set_definition == null:
		return

	if wave_set_definition.get_script() != WAVE_SET_DEFINITION_SCRIPT:
		push_warning("WaveManager wave_set_definition is not a WaveSetDefinition resource")
		return

	var valid_socket_ids := {}
	for socket in _get_defense_sockets():
		if not is_instance_valid(socket):
			continue
		valid_socket_ids[String(socket.socket_id)] = true

	for wave_resource in wave_set_definition.waves:
		if wave_resource == null:
			push_warning("Wave set contains a null wave resource")
			continue

		if wave_resource.get_script() != WAVE_DEFINITION_SCRIPT:
			push_warning("Wave set contains an invalid wave resource")
			continue

		var wave_number := int(wave_resource.wave_number)
		if wave_number <= 0:
			push_warning("Wave resource has invalid wave_number")
			continue

		if _wave_definitions.has(wave_number):
			push_warning("Wave set contains duplicate wave_number %d" % wave_number)
			continue

		if float(wave_resource.spawn_interval) <= 0.0:
			push_warning("Wave %d has invalid spawn_interval" % wave_number)
			continue

		var lanes: Array[Dictionary] = []
		var wave_is_valid := true
		for lane_resource in wave_resource.lanes:
			if lane_resource == null:
				push_warning("Wave %d contains a null lane resource" % wave_number)
				wave_is_valid = false
				break

			if lane_resource.get_script() != WAVE_LANE_DEFINITION_SCRIPT:
				push_warning("Wave %d contains an invalid lane resource" % wave_number)
				wave_is_valid = false
				break

			var lane_id := StringName(lane_resource.lane_id)
			var lane_count := int(lane_resource.count)
			if String(lane_id).is_empty() or lane_count <= 0:
				push_warning("Wave %d contains an invalid lane definition" % wave_number)
				wave_is_valid = false
				break

			if lane_resource.enemy_definition == null or lane_resource.enemy_definition.get_script() != ENEMY_DEFINITION_SCRIPT:
				push_warning("Wave %d lane %s is missing a valid enemy_definition" % [wave_number, lane_id])
				wave_is_valid = false
				break

			if not lane_resource.enemy_definition.is_valid_definition():
				push_warning("Wave %d lane %s has an invalid enemy_definition resource" % [wave_number, lane_id])
				wave_is_valid = false
				break

			for preferred_socket_id in lane_resource.preferred_socket_ids:
				var socket_id := String(preferred_socket_id)
				if socket_id.is_empty() or not valid_socket_ids.has(socket_id):
					push_warning("Wave %d lane %s references unknown preferred socket %s" % [wave_number, lane_id, socket_id])
					wave_is_valid = false
					break

			if not wave_is_valid:
				break

			lanes.append({
				"id": lane_id,
				"count": lane_count,
				"enemy_definition": lane_resource.enemy_definition,
				"preferred_socket_ids": Array(lane_resource.preferred_socket_ids),
			})

		if not wave_is_valid:
			continue

		if lanes.is_empty():
			push_warning("Wave %d has no valid lanes" % wave_number)
			continue

		_wave_definitions[wave_number] = {
			"spawn_interval": float(wave_resource.spawn_interval),
			"lanes": lanes,
		}


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

	var spawn_entry: Dictionary = _spawn_queue.pop_front()
	var lane_id := String(spawn_entry.get("lane_id", ""))
	var marker: Node2D = _spawn_markers.get(lane_id, null)
	var preferred_socket_ids := PackedStringArray(Array(spawn_entry.get("preferred_socket_ids", [])))
	if marker == null:
		push_warning("Missing spawn marker for lane %s" % lane_id)
	else:
		var zombie = zombie_scene.instantiate()
		zombie.definition = spawn_entry.get("enemy_definition")
		_enemy_parent.add_child(zombie)
		zombie.global_position = _get_spawn_position(marker, preferred_socket_ids)
		if zombie.has_method("configure_wave_context"):
			zombie.configure_wave_context(
				_player,
				_get_defense_sockets(),
				preferred_socket_ids
			)
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
		if not child.is_in_group("defense_sockets"):
			continue
		sockets.append(child)

	return sockets


func _get_spawn_position(marker: Node2D, preferred_socket_ids: PackedStringArray = PackedStringArray()) -> Vector2:
	if marker == null:
		return Vector2.ZERO

	if spawn_jitter_radius <= 0.0 or _enemy_parent == null:
		return marker.global_position

	var forward: Vector2 = _get_spawn_forward_direction(marker, preferred_socket_ids)
	var lateral: Vector2 = forward.orthogonal()
	var best_position: Vector2 = marker.global_position
	var best_score: float = -INF
	for _attempt in spawn_jitter_attempts:
		var lateral_offset: float = randf_range(-spawn_jitter_radius, spawn_jitter_radius)
		var forward_offset: float = randf_range(-spawn_jitter_radius * 0.2, spawn_jitter_radius * 0.35)
		var candidate: Vector2 = marker.global_position + lateral * lateral_offset + forward * forward_offset
		var score: float = _score_spawn_position(candidate) - abs(forward_offset) * 0.1
		if score > best_score:
			best_score = score
			best_position = candidate

	return best_position


func _get_spawn_forward_direction(marker: Node2D, preferred_socket_ids: PackedStringArray) -> Vector2:
	var target_sockets: Array = _get_spawn_target_sockets(preferred_socket_ids)
	var closest_socket = null
	var best_distance := INF

	for socket in target_sockets:
		if not is_instance_valid(socket):
			continue

		var distance: float = marker.global_position.distance_squared_to(socket.global_position)
		if distance < best_distance:
			best_distance = distance
			closest_socket = socket

	if closest_socket == null:
		return Vector2.DOWN

	var direction: Vector2 = closest_socket.global_position - marker.global_position
	if direction.is_zero_approx():
		return Vector2.DOWN

	return direction.normalized()


func _get_spawn_target_sockets(preferred_socket_ids: PackedStringArray) -> Array:
	var sockets := _get_defense_sockets()
	if preferred_socket_ids.is_empty():
		return sockets

	var preferred: Array = []
	for socket in sockets:
		if not is_instance_valid(socket):
			continue
		if preferred_socket_ids.has(String(socket.socket_id)):
			preferred.append(socket)

	if preferred.is_empty():
		return sockets

	return preferred


func _score_spawn_position(candidate: Vector2) -> float:
	var best_distance := spawn_jitter_radius
	for child in _enemy_parent.get_children():
		if not (child is Node2D):
			continue

		var enemy_position: Vector2 = child.global_position
		best_distance = min(best_distance, candidate.distance_to(enemy_position))

	return best_distance


func _on_spawn_timer_timeout() -> void:
	_spawn_next_enemy()


func _on_zombie_died(_zombie) -> void:
	active_enemies = max(active_enemies - 1, 0)
	if _spawn_queue.is_empty() and active_enemies == 0:
		clear_wave()
