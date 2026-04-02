extends StaticBody2D
class_name Placeable

const PLACEABLE_PROFILE_SCRIPT := preload("res://scripts/data/placeable_profile.gd")
const PLAYER_BLOCKING_LAYER := 2
const ZOMBIE_GROUP := "enemies"

signal state_changed(placeable: Placeable)

@export var profile: Resource
@export var current_hp: int = 100
@export var placed_this_run: bool = true
@export var is_dismantled: bool = false
@export var footprint_anchor_cell: Vector2i = Vector2i.ZERO
@export var placement_rotation_steps: int = 0

@onready var visual: Polygon2D = $Visual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var trap_hit_area: Area2D = $TrapHitArea
@onready var trap_hit_shape: CollisionShape2D = $TrapHitArea/CollisionShape2D
@onready var trap_hit_timer: Timer = $TrapHitTimer

var _collision_grace_player: Node = null
var _collision_grace_grid: Node = null
var _collision_grace_cells: Array[Vector2i] = []
var _collision_grace_radius_cells: int = 0
var _collision_grace_remaining: float = 0.0
var _trap_hit_cooldowns: Dictionary = {}
var _trap_tick_remaining: float = 0.0


func _ready() -> void:
	add_to_group("placeables")
	_refresh_from_profile()
	_configure_trap_nodes()
	_trap_tick_remaining = 0.0
	set_physics_process(not _collision_grace_cells.is_empty() or _is_trap_profile())


func _refresh_from_profile() -> void:
	if profile == null or profile.get_script() != PLACEABLE_PROFILE_SCRIPT:
		return
	current_hp = clamp(current_hp, 0, int(profile.max_hp))
	visual.color = profile.visual_color
	collision_layer = 2 if bool(profile.blocks_movement) else 0
	collision_mask = 0
	if collision_shape.shape != null:
		collision_shape.shape = collision_shape.shape.duplicate()
	if trap_hit_shape != null and trap_hit_shape.shape != null:
		trap_hit_shape.shape = trap_hit_shape.shape.duplicate()
	state_changed.emit(self)


func _configure_trap_nodes() -> void:
	if trap_hit_area == null or trap_hit_timer == null:
		return
	if profile == null or profile.get_script() != PLACEABLE_PROFILE_SCRIPT:
		return
	var is_trap: bool = profile.category == "trap"
	trap_hit_area.visible = false
	trap_hit_area.monitorable = false
	trap_hit_area.monitoring = is_trap
	if trap_hit_shape != null:
		trap_hit_shape.disabled = not is_trap
	trap_hit_timer.wait_time = 0.35
	trap_hit_timer.one_shot = false
	trap_hit_timer.autostart = false
	if is_trap and not trap_hit_timer.timeout.is_connected(_on_trap_hit_timer_timeout):
		trap_hit_timer.timeout.connect(_on_trap_hit_timer_timeout)
	if is_trap:
		trap_hit_timer.start()
	else:
		trap_hit_timer.stop()
	set_physics_process(not _collision_grace_cells.is_empty() or is_trap)


func get_placeable_id() -> StringName:
	if profile == null or profile.get_script() != PLACEABLE_PROFILE_SCRIPT:
		return StringName()
	return StringName(profile.placeable_id)


func get_display_name() -> String:
	if profile == null or profile.get_script() != PLACEABLE_PROFILE_SCRIPT:
		return "Placeable"
	return String(profile.display_name)


func get_build_cost() -> Dictionary:
	if profile == null or profile.get_script() != PLACEABLE_PROFILE_SCRIPT:
		return {}
	return profile.build_cost.duplicate(true)


func get_repair_cost() -> Dictionary:
	if profile == null or profile.get_script() != PLACEABLE_PROFILE_SCRIPT:
		return {}
	return profile.repair_cost.duplicate(true)


func get_footprint_cells() -> PackedVector2Array:
	if profile == null or profile.get_script() != PLACEABLE_PROFILE_SCRIPT:
		return PackedVector2Array()
	return profile.get_rotated_footprint_offsets(placement_rotation_steps)


func get_footprint_anchor_cell() -> Vector2i:
	return footprint_anchor_cell


func is_trap_active() -> bool:
	return _is_trap_profile() and trap_hit_timer != null and not trap_hit_timer.is_stopped()


func get_trap_overlap_count() -> int:
	if not _is_trap_profile():
		return 0
	return _get_trap_target_count()


func _is_trap_profile() -> bool:
	if profile == null or profile.get_script() != PLACEABLE_PROFILE_SCRIPT:
		return false
	return profile.category == "trap"


func is_breached() -> bool:
	return current_hp <= 0 or is_dismantled


func get_attack_aim_point(from_position: Vector2) -> Vector2:
	var half_size := Vector2(20.0, 20.0)
	var clamped_point := Vector2(
		clampf(from_position.x, global_position.x - half_size.x, global_position.x + half_size.x),
		clampf(from_position.y, global_position.y - half_size.y, global_position.y + half_size.y)
	)
	return clamped_point


func can_interact(_player) -> bool:
	return profile != null and profile.get_script() == PLACEABLE_PROFILE_SCRIPT and not is_dismantled


func get_interaction_priority(_player) -> int:
	return int(profile.interaction_priority) if profile != null and profile.get_script() == PLACEABLE_PROFILE_SCRIPT else 9


func get_interaction_label(player) -> String:
	if profile == null or profile.get_script() != PLACEABLE_PROFILE_SCRIPT or is_dismantled:
		return ""
	if current_hp < int(profile.max_hp):
		var repair_cost := get_repair_cost()
		if player != null and not player.has_resources(repair_cost):
			return "Repair (need %s)" % _format_cost(repair_cost)
		return "Repair (%s)" % _format_cost(repair_cost)

	var refund := _get_recycle_cost()
	return "Recycle (%s)" % _format_cost(refund)


func interact(player) -> void:
	if profile == null or profile.get_script() != PLACEABLE_PROFILE_SCRIPT or is_dismantled:
		return
	if current_hp < int(profile.max_hp):
		var repair_cost := get_repair_cost()
		if not player.spend_resources(repair_cost):
			player.message_requested.emit("Not enough resources")
			return
		current_hp = int(profile.max_hp)
		player.message_requested.emit("%s repaired" % get_display_name())
		state_changed.emit(self)
		return


func recycle(player) -> void:
	if profile == null or profile.get_script() != PLACEABLE_PROFILE_SCRIPT or is_dismantled:
		return
	if current_hp < int(profile.max_hp):
		return
	var refund := _get_recycle_cost()
	_apply_refund(player, refund)
	is_dismantled = true
	player.message_requested.emit("%s recycled" % get_display_name())
	state_changed.emit(self)
	queue_free()


func dismantle(player) -> void:
	if profile == null or profile.get_script() != PLACEABLE_PROFILE_SCRIPT or is_dismantled:
		return
	var refund := _get_refund_cost()
	_apply_refund(player, refund)
	is_dismantled = true
	player.message_requested.emit("%s dismantled" % get_display_name())
	state_changed.emit(self)
	queue_free()


func reset_for_new_run() -> void:
	current_hp = int(profile.max_hp) if profile != null and profile.get_script() == PLACEABLE_PROFILE_SCRIPT else current_hp
	is_dismantled = false
	placed_this_run = true
	_trap_hit_cooldowns.clear()
	state_changed.emit(self)


func get_save_state() -> Dictionary:
	var saved_profile_id := String(get_placeable_id())
	return {
		"placeable_id": saved_profile_id,
		"current_hp": current_hp,
		"placed_this_run": placed_this_run,
		"is_dismantled": is_dismantled,
		"anchor_cell": {
			"x": int(footprint_anchor_cell.x),
			"y": int(footprint_anchor_cell.y),
		},
		"rotation_steps": placement_rotation_steps,
		"position": {
			"x": global_position.x,
			"y": global_position.y,
		},
	}


func apply_save_state(save_state: Dictionary) -> void:
	current_hp = clampi(int(save_state.get("current_hp", current_hp)), 0, int(profile.max_hp) if profile != null and profile.get_script() == PLACEABLE_PROFILE_SCRIPT else current_hp)
	placed_this_run = bool(save_state.get("placed_this_run", placed_this_run))
	is_dismantled = bool(save_state.get("is_dismantled", is_dismantled))
	var anchor_data: Dictionary = save_state.get("anchor_cell", {})
	footprint_anchor_cell = Vector2i(
		int(anchor_data.get("x", footprint_anchor_cell.x)),
		int(anchor_data.get("y", footprint_anchor_cell.y))
	)
	placement_rotation_steps = int(save_state.get("rotation_steps", placement_rotation_steps))
	var position_data: Dictionary = save_state.get("position", {})
	global_position = Vector2(
		float(position_data.get("x", global_position.x)),
		float(position_data.get("y", global_position.y))
	)
	_refresh_from_profile()
	_configure_trap_nodes()
	state_changed.emit(self)


func begin_player_collision_grace(player: Node2D, construction_grid: Node, footprint_cells: Array[Vector2i], grace_radius_cells: int = 1) -> void:
	if player == null or not is_instance_valid(player):
		return
	if construction_grid == null or not is_instance_valid(construction_grid):
		return
	if footprint_cells.is_empty():
		return
	if grace_radius_cells < 0:
		return
	_collision_grace_player = player
	_collision_grace_grid = construction_grid
	_collision_grace_cells = footprint_cells.duplicate()
	_collision_grace_radius_cells = grace_radius_cells
	_collision_grace_remaining = 0.35
	if player.has_method("push_collision_mask_exemption"):
		player.push_collision_mask_exemption(PLAYER_BLOCKING_LAYER)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	var trap_active := _is_trap_profile()
	var has_collision_grace := _collision_grace_player != null and is_instance_valid(_collision_grace_player) and _collision_grace_grid != null and is_instance_valid(_collision_grace_grid)
	if not has_collision_grace:
		_clear_collision_grace()
		if trap_active:
			_process_trap_tick(_delta)
		set_physics_process(trap_active)
		return

	_collision_grace_remaining = maxf(_collision_grace_remaining - _delta, 0.0)
	if trap_active:
		_process_trap_tick(_delta)
	var player_cell: Vector2i = _collision_grace_grid.get_cell_for_world_position(_collision_grace_player.global_position)
	for grace_cell in _collision_grace_cells:
		var cell: Vector2i = grace_cell
		if abs(cell.x - player_cell.x) <= _collision_grace_radius_cells and abs(cell.y - player_cell.y) <= _collision_grace_radius_cells:
			return

	if _collision_grace_remaining > 0.0:
		return

	_clear_collision_grace()
	set_physics_process(trap_active)


func _process_trap_tick(delta: float) -> void:
	if profile == null or profile.get_script() != PLACEABLE_PROFILE_SCRIPT:
		return
	if profile.category != "trap":
		return
	if current_hp <= 0 or is_dismantled:
		return
	_trap_tick_remaining = maxf(_trap_tick_remaining - delta, 0.0)
	if _trap_tick_remaining > 0.0:
		return
	_on_trap_hit_timer_timeout()
	_trap_tick_remaining = 0.35


func _clear_collision_grace() -> void:
	if _collision_grace_player != null and is_instance_valid(_collision_grace_player) and _collision_grace_player.has_method("pop_collision_mask_exemption"):
		_collision_grace_player.pop_collision_mask_exemption(PLAYER_BLOCKING_LAYER)
	_collision_grace_player = null
	_collision_grace_grid = null
	_collision_grace_cells.clear()
	_collision_grace_radius_cells = 0
	_collision_grace_remaining = 0.0


func _exit_tree() -> void:
	_clear_collision_grace()


func take_damage(amount: int, _source: Variant = null) -> void:
	if amount <= 0 or is_dismantled:
		return
	current_hp = max(current_hp - amount, 0)
	state_changed.emit(self)
	if current_hp <= 0:
		is_dismantled = true
		queue_free()


func _on_trap_hit_timer_timeout() -> void:
	if profile == null or profile.get_script() != PLACEABLE_PROFILE_SCRIPT:
		return
	if profile.category != "trap":
		return
	if current_hp <= 0 or is_dismantled:
		return

	var zombies: Array = _get_trap_targets()

	if zombies.is_empty():
		return

	var contact_damage: int = max(int(profile.contact_damage), 0)
	if contact_damage <= 0:
		return

	for zombie in zombies:
		var zombie_id: int = int(zombie.get_instance_id())
		var cooldown_remaining := float(_trap_hit_cooldowns.get(zombie_id, 0.0))
		if cooldown_remaining > 0.0:
			_trap_hit_cooldowns[zombie_id] = maxf(cooldown_remaining - trap_hit_timer.wait_time, 0.0)
			continue
		zombie.take_damage(contact_damage, {
			"attacker": self,
			"damage_type": &"trap",
			"slow_factor": profile.slow_factor,
			"slow_duration": 1.1,
		})
		current_hp = max(current_hp - 1, 0)
		_trap_hit_cooldowns[zombie_id] = 0.35
		if current_hp <= 0:
			is_dismantled = true
			queue_free()
			return


func _get_trap_target_count() -> int:
	return _get_trap_targets().size()


func _get_trap_targets() -> Array:
	var targets: Array = []
	if profile == null or profile.get_script() != PLACEABLE_PROFILE_SCRIPT:
		return targets
	if profile.category != "trap":
		return targets

	var footprint: Vector2i = profile.get_rotated_footprint_dimensions(placement_rotation_steps)
	var half_extents := Vector2(
		maxf(float(footprint.x), 1.0) * 24.0 + 8.0,
		maxf(float(footprint.y), 1.0) * 24.0 + 8.0
	)
	for body in get_tree().get_nodes_in_group(ZOMBIE_GROUP):
		if body == null or not is_instance_valid(body) or not body.has_method("take_damage"):
			continue
		if absf(body.global_position.x - global_position.x) > half_extents.x:
			continue
		if absf(body.global_position.y - global_position.y) > half_extents.y:
			continue
		targets.append(body)

	return targets


func _get_recycle_cost() -> Dictionary:
	return get_build_cost()


func _get_refund_cost() -> Dictionary:
	var build_cost := get_build_cost()
	var refund: Dictionary = {}
	for resource_id in build_cost.keys():
		var amount := int(build_cost[resource_id])
		if amount <= 0:
			continue
		refund[resource_id] = max(int(floor(float(amount) * 0.5)), 1)
	return refund


func _apply_refund(player, refund: Dictionary) -> void:
	if player == null or not is_instance_valid(player):
		return
	if refund.is_empty():
		return
	for resource_id in refund.keys():
		var amount := int(refund[resource_id])
		if amount > 0:
			player.add_resource(String(resource_id), amount, false)


func _format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in ["salvage", "parts", "medicine", "food", "bullets"]:
		var amount := int(cost.get(resource_id, 0))
		if amount <= 0:
			continue
		parts.append("%d %s" % [amount, resource_id.capitalize()])
	return ", ".join(parts)
