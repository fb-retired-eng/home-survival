extends Area2D
class_name DogCompanion

const GAMEPLAY_Z_BASE := 1000

signal stamina_changed(current: int, maximum: int)
signal status_changed(text: String)
signal message_requested(text: String)
signal autosave_requested

enum DogState {
	FOLLOW,
	SCAVENGING,
	LURING,
}

@export var max_stamina: int = 100
@export_range(0, 100, 1) var scavenge_stamina_cost: int = 35
@export_range(1.0, 180.0, 1.0) var scavenge_duration: float = 60.0
@export_range(0, 100, 1) var lure_stamina_cost: int = 25
@export_range(1.0, 20.0, 0.5) var lure_duration: float = 8.0
@export_range(0.5, 5.0, 0.1) var lure_bark_interval: float = 1.0
@export_range(0.0, 400.0, 5.0) var lure_radius: float = 180.0
@export_range(0.0, 400.0, 5.0) var follow_speed: float = 150.0
@export_range(0.0, 500.0, 5.0) var lure_move_speed: float = 190.0
@export_range(0.0, 200.0, 5.0) var follow_distance: float = 42.0
@export_range(0.0, 300.0, 5.0) var teleport_distance: float = 180.0
@export_range(0.0, 300.0, 5.0) var home_interaction_radius: float = 160.0

var player
var poi_controller
var game_manager
var home_world_position: Vector2 = Vector2.ZERO
var current_stamina: int = max_stamina
var _state: int = DogState.FOLLOW
var _active_poi_id: StringName = StringName()
var _remaining_trip_time: float = 0.0
var _lure_target_position: Vector2 = Vector2.ZERO
var _lure_bark_remaining: float = 0.0
var _base_body_color: Color

@onready var body_shadow: Polygon2D = $BodyShadow
@onready var body: Polygon2D = $Body
@onready var ear_left: Polygon2D = $EarLeft
@onready var ear_right: Polygon2D = $EarRight
@onready var collar: Polygon2D = $Collar
@onready var state_ring: Polygon2D = $StateRing
@onready var label: Label = $Label
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("dog_companion")
	current_stamina = clampi(current_stamina, 0, max_stamina)
	_base_body_color = body.color
	_emit_state()
	_update_render_order()


func configure(config: Dictionary) -> void:
	player = config.get("player")
	poi_controller = config.get("poi_controller")
	game_manager = config.get("game_manager")
	home_world_position = config.get("home_world_position", home_world_position)


func _process(delta: float) -> void:
	match _state:
		DogState.FOLLOW:
			_update_follow_movement(delta)
		DogState.SCAVENGING:
			_remaining_trip_time = maxf(_remaining_trip_time - delta, 0.0)
			if _remaining_trip_time <= 0.0:
				_complete_scavenge_trip()
		DogState.LURING:
			_update_lure_state(delta)
	_update_visuals(delta)
	_update_render_order()


func get_interaction_label(interacting_player) -> String:
	if interacting_player == null or not is_instance_valid(interacting_player):
		return ""
	if _state == DogState.SCAVENGING:
		return ""
	if not _is_player_at_home(interacting_player):
		return ""
	if current_stamina >= max_stamina:
		return ""
	if int(interacting_player.resources.get("food", 0)) <= 0:
		return "Need 1 food to feed dog"
	return "Feed dog (1 food)"


func can_interact(interacting_player) -> bool:
	return not get_interaction_label(interacting_player).is_empty()


func get_interaction_priority(_interacting_player) -> int:
	return 35


func interact(interacting_player) -> void:
	if not can_interact(interacting_player):
		return
	if not interacting_player.spend_resource("food", 1):
		message_requested.emit("Not enough food")
		return
	current_stamina = max_stamina
	message_requested.emit("Dog rested and ate")
	_emit_state()
	autosave_requested.emit()


func issue_scavenge_command() -> bool:
	if _state != DogState.FOLLOW:
		message_requested.emit("Dog is busy")
		return false
	if game_manager == null or not is_instance_valid(game_manager):
		return false
	if int(game_manager.run_state) != int(game_manager.RunState.PRE_WAVE):
		message_requested.emit("Dog can only scavenge during the day")
		return false
	if current_stamina < scavenge_stamina_cost:
		message_requested.emit("Dog is too tired")
		return false
	if poi_controller == null or not is_instance_valid(poi_controller):
		return false
	var poi_id: StringName = poi_controller.get_best_known_poi_for_dog(_get_reference_position())
	if poi_id == StringName():
		message_requested.emit("No known POI for dog yet")
		return false
	current_stamina = max(current_stamina - scavenge_stamina_cost, 0)
	_state = DogState.SCAVENGING
	_active_poi_id = poi_id
	_remaining_trip_time = scavenge_duration
	visible = false
	monitoring = false
	monitorable = false
	if collision_shape != null:
		collision_shape.disabled = true
	message_requested.emit("Dog scavenging %s" % poi_controller.get_poi_display_name(poi_id))
	_emit_state()
	autosave_requested.emit()
	return true


func issue_lure_command(target_position: Vector2) -> bool:
	if _state != DogState.FOLLOW:
		message_requested.emit("Dog is busy")
		return false
	if game_manager == null or not is_instance_valid(game_manager):
		return false
	if int(game_manager.run_state) != int(game_manager.RunState.ACTIVE_WAVE):
		message_requested.emit("Dog lure is night only")
		return false
	if current_stamina < lure_stamina_cost:
		message_requested.emit("Dog is too tired")
		return false
	current_stamina = max(current_stamina - lure_stamina_cost, 0)
	_state = DogState.LURING
	_remaining_trip_time = lure_duration
	_lure_bark_remaining = 0.0
	_lure_target_position = target_position
	message_requested.emit("Dog is luring enemies")
	_emit_lure_bark()
	_emit_state()
	return true


func issue_context_command(target_position: Variant = null) -> bool:
	if game_manager == null or not is_instance_valid(game_manager):
		return false
	var run_state: int = int(game_manager.run_state)
	if run_state == int(game_manager.RunState.PRE_WAVE):
		return issue_scavenge_command()
	if run_state == int(game_manager.RunState.ACTIVE_WAVE):
		var resolved_target := _get_reference_position()
		if target_position is Vector2:
			resolved_target = target_position
		return issue_lure_command(resolved_target)
	message_requested.emit("Dog cannot help right now")
	return false


func get_save_state() -> Dictionary:
	return {
		"position": {
			"x": global_position.x,
			"y": global_position.y,
		},
		"current_stamina": current_stamina,
		"state": _state,
		"active_poi_id": String(_active_poi_id),
		"remaining_trip_time": _remaining_trip_time,
		"lure_target_position": {
			"x": _lure_target_position.x,
			"y": _lure_target_position.y,
		},
		"lure_bark_remaining": _lure_bark_remaining,
	}


func apply_save_state(save_state: Dictionary) -> void:
	var position_data: Dictionary = save_state.get("position", {})
	global_position = Vector2(
		float(position_data.get("x", global_position.x)),
		float(position_data.get("y", global_position.y))
	)
	current_stamina = clampi(int(save_state.get("current_stamina", current_stamina)), 0, max_stamina)
	_state = int(save_state.get("state", DogState.FOLLOW))
	_active_poi_id = StringName(save_state.get("active_poi_id", String(_active_poi_id)))
	_remaining_trip_time = maxf(float(save_state.get("remaining_trip_time", 0.0)), 0.0)
	var lure_target_data: Dictionary = save_state.get("lure_target_position", {})
	_lure_target_position = Vector2(
		float(lure_target_data.get("x", _lure_target_position.x)),
		float(lure_target_data.get("y", _lure_target_position.y))
	)
	_lure_bark_remaining = maxf(float(save_state.get("lure_bark_remaining", 0.0)), 0.0)
	_apply_state_visibility()
	_emit_state()


func debug_complete_active_scavenge() -> bool:
	if _state != DogState.SCAVENGING:
		return false
	_remaining_trip_time = 0.0
	_complete_scavenge_trip()
	return true


func reset_for_new_run() -> void:
	current_stamina = max_stamina
	_state = DogState.FOLLOW
	_active_poi_id = StringName()
	_remaining_trip_time = 0.0
	_lure_target_position = Vector2.ZERO
	_lure_bark_remaining = 0.0
	global_position = home_world_position + Vector2(-18.0, 20.0)
	_apply_state_visibility()
	_emit_state()


func _update_follow_movement(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var target_position: Vector2 = player.global_position + Vector2(-24.0, 18.0)
	var offset: Vector2 = target_position - global_position
	var distance: float = offset.length()
	if distance >= teleport_distance:
		global_position = target_position
		return
	if distance <= follow_distance:
		return
	global_position += offset.normalized() * minf(follow_speed * delta, distance - follow_distance)


func _complete_scavenge_trip() -> void:
	var rewards: Dictionary = {}
	if poi_controller != null and is_instance_valid(poi_controller):
		rewards = poi_controller.roll_dog_scavenge_reward(_active_poi_id)
	if player != null and is_instance_valid(player):
		for resource_id in rewards.keys():
			var amount := int(rewards.get(resource_id, 0))
			if amount > 0:
				player.add_resource(String(resource_id), amount, false)
	var summary: Array[String] = []
	for resource_id in rewards.keys():
		var amount := int(rewards.get(resource_id, 0))
		if amount > 0:
			summary.append("%s +%d" % [String(resource_id).capitalize(), amount])
	_state = DogState.FOLLOW
	_remaining_trip_time = 0.0
	var completed_poi_id: StringName = _active_poi_id
	_active_poi_id = StringName()
	_lure_target_position = Vector2.ZERO
	_lure_bark_remaining = 0.0
	global_position = _get_reference_position() + Vector2(-18.0, 20.0)
	_apply_state_visibility()
	if poi_controller != null and is_instance_valid(poi_controller):
		if summary.is_empty():
			message_requested.emit("Dog returned from %s with nothing" % poi_controller.get_poi_display_name(completed_poi_id))
		else:
			message_requested.emit("Dog returned from %s: %s" % [poi_controller.get_poi_display_name(completed_poi_id), ", ".join(summary)])
	_emit_state()
	autosave_requested.emit()


func _update_lure_state(delta: float) -> void:
	var offset: Vector2 = _lure_target_position - global_position
	var distance: float = offset.length()
	if distance > 12.0:
		global_position += offset.normalized() * minf(lure_move_speed * delta, distance)
	_update_facing_for_motion(offset)
	_remaining_trip_time = maxf(_remaining_trip_time - delta, 0.0)
	_lure_bark_remaining = maxf(_lure_bark_remaining - delta, 0.0)
	if _lure_bark_remaining <= 0.0:
		_emit_lure_bark()
		_lure_bark_remaining = lure_bark_interval
	if _remaining_trip_time <= 0.0:
		_complete_lure()


func _complete_lure() -> void:
	_state = DogState.FOLLOW
	_remaining_trip_time = 0.0
	_lure_target_position = Vector2.ZERO
	_lure_bark_remaining = 0.0
	message_requested.emit("Dog returned to follow")
	_apply_state_visibility()
	_emit_state()


func _emit_lure_bark() -> void:
	if player == null or not is_instance_valid(player):
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		var targeting_controller = enemy.get("targeting_controller")
		if targeting_controller == null:
			continue
		if enemy.global_position.distance_to(global_position) > lure_radius:
			continue
		targeting_controller.receive_noise_alert(player, global_position)


func _apply_state_visibility() -> void:
	var scavenging := _state == DogState.SCAVENGING
	visible = not scavenging
	monitoring = not scavenging
	monitorable = not scavenging
	if collision_shape != null:
		collision_shape.disabled = scavenging


func _emit_state() -> void:
	stamina_changed.emit(current_stamina, max_stamina)
	status_changed.emit(_build_status_text())


func _build_status_text() -> String:
	match _state:
		DogState.SCAVENGING:
			var poi_text := "Unknown"
			if poi_controller != null and is_instance_valid(poi_controller) and _active_poi_id != StringName():
				poi_text = poi_controller.get_poi_display_name(_active_poi_id)
			return "Dog %d/%d | Scavenging %s" % [current_stamina, max_stamina, poi_text]
		DogState.LURING:
			return "Dog %d/%d | Luring [G]" % [current_stamina, max_stamina]
		_:
			return "Dog %d/%d | Ready [G]" % [current_stamina, max_stamina]


func _get_reference_position() -> Vector2:
	if player != null and is_instance_valid(player):
		return player.global_position
	return home_world_position


func _is_player_at_home(interacting_player) -> bool:
	return interacting_player.global_position.distance_to(home_world_position) <= home_interaction_radius


func _update_visuals(delta: float) -> void:
	if not visible:
		return
	var motion := 0.0
	if player != null and is_instance_valid(player):
		motion = clampf(global_position.distance_to(player.global_position) / 160.0, 0.0, 1.0)
	if _state == DogState.LURING:
		motion = maxf(motion, 0.65)
	var time := Time.get_ticks_msec() / 1000.0
	body_shadow.scale = Vector2(1.0 - 0.06 * motion, 1.0 + 0.04 * motion)
	body.position.y = sin(time * 7.0) * 0.8 * motion
	ear_left.rotation = deg_to_rad(-8.0 - 4.0 * sin(time * 8.5))
	ear_right.rotation = deg_to_rad(8.0 + 4.0 * sin(time * 8.5))
	state_ring.visible = _state == DogState.SCAVENGING or _state == DogState.LURING
	if state_ring.visible:
		var ring_color := Color(0.85, 0.92, 0.42, 0.6)
		if _state == DogState.LURING:
			ring_color = Color(1.0, 0.48, 0.34, 0.72)
		state_ring.color = ring_color
		state_ring.modulate.a = 0.42 + 0.08 * sin(time * 5.0)
	label.text = "DOG"
	label.modulate.a = move_toward(label.modulate.a, 0.86, delta * 3.0)
	body.color = _base_body_color


func _update_facing_for_motion(offset: Vector2) -> void:
	if offset.length_squared() <= 1.0:
		return
	var facing_left: bool = offset.x < 0.0
	var horizontal_scale := absf(body.scale.x)
	body.scale.x = -horizontal_scale if facing_left else horizontal_scale
	ear_left.scale.x = body.scale.x
	ear_right.scale.x = body.scale.x
	collar.scale.x = body.scale.x


func _update_render_order() -> void:
	z_as_relative = false
	z_index = GAMEPLAY_Z_BASE + int(round(global_position.y))
