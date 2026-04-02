extends StaticBody2D
class_name Placeable

const PLACEABLE_PROFILE_SCRIPT := preload("res://scripts/data/placeable_profile.gd")
const PLAYER_BLOCKING_LAYER := 2

signal state_changed(placeable: Placeable)

@export var profile: Resource
@export var current_hp: int = 100
@export var placed_this_run: bool = true
@export var is_dismantled: bool = false
@export var footprint_anchor_cell: Vector2i = Vector2i.ZERO
@export var placement_rotation_steps: int = 0

@onready var visual: Polygon2D = $Visual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _collision_grace_player: Node = null
var _collision_grace_grid: Node = null
var _collision_grace_cells: Array[Vector2i] = []
var _collision_grace_radius_cells: int = 0
var _collision_grace_remaining: float = 0.0


func _ready() -> void:
	add_to_group("placeables")
	_refresh_from_profile()
	set_physics_process(not _collision_grace_cells.is_empty())


func _refresh_from_profile() -> void:
	if profile == null or profile.get_script() != PLACEABLE_PROFILE_SCRIPT:
		return
	current_hp = clamp(current_hp, 0, int(profile.max_hp))
	visual.color = profile.visual_color
	collision_layer = 2 if bool(profile.blocks_movement) else 0
	collision_mask = 0
	if collision_shape.shape != null:
		collision_shape.shape = collision_shape.shape.duplicate()
	state_changed.emit(self)


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
	if _collision_grace_player == null or not is_instance_valid(_collision_grace_player):
		_clear_collision_grace()
		set_physics_process(false)
		return
	if _collision_grace_grid == null or not is_instance_valid(_collision_grace_grid):
		_clear_collision_grace()
		set_physics_process(false)
		return

	_collision_grace_remaining = maxf(_collision_grace_remaining - _delta, 0.0)
	var player_cell: Vector2i = _collision_grace_grid.get_cell_for_world_position(_collision_grace_player.global_position)
	for grace_cell in _collision_grace_cells:
		var cell: Vector2i = grace_cell
		if abs(cell.x - player_cell.x) <= _collision_grace_radius_cells and abs(cell.y - player_cell.y) <= _collision_grace_radius_cells:
			return

	if _collision_grace_remaining > 0.0:
		return

	_clear_collision_grace()
	set_physics_process(false)


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
