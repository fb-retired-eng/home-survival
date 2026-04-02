extends Node2D
class_name ConstructionGrid

const CELL_OUTLINE_INSET := 4.0
const CELL_BORDER_INSET := 2.0

@export var cell_size: Vector2 = Vector2(48.0, 48.0)
@export var grid_min_cell: Vector2i = Vector2i.ZERO
@export var grid_max_cell: Vector2i = Vector2i.ZERO
@export var tactical_cells: PackedVector2Array = PackedVector2Array()
@export var reserved_cells: PackedVector2Array = PackedVector2Array()
@export var buildable_margin_cells: int = 3

var _build_mode_active: bool = false
var _preview_cell: Vector2i = Vector2i.ZERO
var _preview_reason: String = ""
var _preview_footprint_offsets: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
var _occupied_cells: Dictionary = {}
var _extra_reserved_cells: Dictionary = {}
var _buildable_bounds_min: Vector2i = Vector2i.ZERO
var _buildable_bounds_max: Vector2i = Vector2i.ZERO

@onready var buildable_overlay: Node2D = $BuildableOverlay
@onready var blocked_overlay: Node2D = $BlockedOverlay
@onready var reserved_overlay: Node2D = $ReservedOverlay
@onready var preview_footprint: Node2D = $PreviewFootprint
@onready var preview: Polygon2D = $Preview
@onready var preview_outline: Line2D = $PreviewOutline


func _ready() -> void:
	_recalculate_buildable_bounds()
	_rebuild_overlays()
	set_build_mode_active(false)


func set_build_mode_active(active: bool) -> void:
	_build_mode_active = active
	buildable_overlay.visible = active
	blocked_overlay.visible = active
	reserved_overlay.visible = active
	preview_footprint.visible = active
	preview.visible = active
	preview_outline.visible = active


func is_build_mode_active() -> bool:
	return _build_mode_active


func set_preview_world_position(world_position: Vector2) -> void:
	var local_position: Vector2 = to_local(world_position)
	var target_cell: Vector2i = _world_to_cell(local_position)
	_preview_cell = target_cell
	_update_preview_visual()


func set_preview_footprint_offsets(footprint_offsets: PackedVector2Array) -> void:
	if footprint_offsets.is_empty():
		_preview_footprint_offsets = PackedVector2Array([Vector2.ZERO])
	else:
		_preview_footprint_offsets = footprint_offsets.duplicate()
	_update_preview_visual()


func get_preview_cell() -> Vector2i:
	return _preview_cell


func get_preview_world_position() -> Vector2:
	return to_global(_cell_to_world(_preview_cell))


func get_preview_reason() -> String:
	return _preview_reason


func is_cell_buildable(cell: Vector2i) -> bool:
	return is_cell_tactical(cell)


func is_cell_tactical(cell: Vector2i) -> bool:
	if not is_cell_in_bounds(cell):
		return false
	if is_cell_reserved(cell):
		return false
	return (
		cell.x >= _buildable_bounds_min.x
		and cell.x <= _buildable_bounds_max.x
		and cell.y >= _buildable_bounds_min.y
		and cell.y <= _buildable_bounds_max.y
	)


func is_cell_in_bounds(cell: Vector2i) -> bool:
	return (
		cell.x >= grid_min_cell.x
		and cell.x <= grid_max_cell.x
		and cell.y >= grid_min_cell.y
		and cell.y <= grid_max_cell.y
	)


func is_cell_reserved(cell: Vector2i) -> bool:
	return _has_cell(reserved_cells, cell) or _extra_reserved_cells.has(cell)


func is_cell_occupied(cell: Vector2i) -> bool:
	return _occupied_cells.has(cell)


func is_cell_valid_for_basic_placeable(cell: Vector2i) -> bool:
	return is_footprint_valid_for_basic_placeable(cell, PackedVector2Array([Vector2.ZERO]))


func is_footprint_valid_for_basic_placeable(anchor_cell: Vector2i, footprint_offsets: PackedVector2Array) -> bool:
	var footprint_cells := get_footprint_cells(anchor_cell, footprint_offsets)
	if footprint_cells.is_empty():
		return false
	for cell in footprint_cells:
		if is_cell_reserved(cell):
			return false
		if not is_cell_tactical(cell):
			return false
		if is_cell_occupied(cell):
			return false
	return true


func would_overlap_player_buffer(player_cell: Vector2i, extra_blocked_cells: Array, buffer_radius_cells: int = 1) -> bool:
	if buffer_radius_cells < 0:
		return false
	if not is_cell_in_bounds(player_cell):
		return false
	for raw_cell in extra_blocked_cells:
		var cell: Vector2i = raw_cell
		if cell == player_cell:
			continue
		if abs(cell.x - player_cell.x) <= buffer_radius_cells and abs(cell.y - player_cell.y) <= buffer_radius_cells:
			return true
	return false


func would_cramp_player_with_existing_occupancy(player_cell: Vector2i, extra_blocked_cells: Array, buffer_radius_cells: int = 1) -> bool:
	if buffer_radius_cells < 0:
		return false
	if not is_cell_in_bounds(player_cell):
		return false

	var candidate_near_player := false
	for raw_cell in extra_blocked_cells:
		var cell: Vector2i = raw_cell
		if abs(cell.x - player_cell.x) <= buffer_radius_cells and abs(cell.y - player_cell.y) <= buffer_radius_cells:
			candidate_near_player = true
			break

	if not candidate_near_player:
		return false

	for existing_cell in _occupied_cells.keys():
		var cell: Vector2i = existing_cell
		if cell == player_cell:
			continue
		var occupant_id: StringName = StringName(_occupied_cells.get(cell, StringName()))
		if not _is_runtime_placeable_occupant_id(occupant_id):
			continue
		if abs(cell.x - player_cell.x) <= buffer_radius_cells and abs(cell.y - player_cell.y) <= buffer_radius_cells:
			return true
	return false


func would_reduce_player_escape_routes(player_cell: Vector2i, extra_blocked_cells: Array, minimum_open_neighbors: int = 3) -> bool:
	if minimum_open_neighbors < 0:
		return false
	if not is_cell_in_bounds(player_cell):
		return false

	var blocked_cells := {}
	for cell in _occupied_cells.keys():
		blocked_cells[cell] = true
	for raw_cell in reserved_cells:
		blocked_cells[Vector2i(roundi(raw_cell.x), roundi(raw_cell.y))] = true
	for cell in _extra_reserved_cells.keys():
		blocked_cells[cell] = true
	for cell in extra_blocked_cells:
		blocked_cells[cell] = true

	var open_neighbors := 0
	for neighbor in _get_cardinal_neighbors(player_cell):
		if not is_cell_in_bounds(neighbor):
			continue
		if blocked_cells.has(neighbor):
			continue
		open_neighbors += 1
		if open_neighbors >= minimum_open_neighbors:
			return false
	return true


func would_trap_player_local(player_cell: Vector2i, extra_blocked_cells: Array, local_radius: int = 2) -> bool:
	if local_radius < 1:
		return false
	if not is_cell_in_bounds(player_cell):
		return false

	var blocked_cells := {}
	for cell in _occupied_cells.keys():
		blocked_cells[cell] = true
	for raw_cell in reserved_cells:
		blocked_cells[Vector2i(roundi(raw_cell.x), roundi(raw_cell.y))] = true
	for cell in _extra_reserved_cells.keys():
		blocked_cells[cell] = true
	for cell in extra_blocked_cells:
		blocked_cells[cell] = true

	var visited := {}
	var queue: Array[Vector2i] = [player_cell]
	visited[player_cell] = true

	while not queue.is_empty():
		var current_cell: Vector2i = queue.pop_front()
		var dx: int = abs(current_cell.x - player_cell.x)
		var dy: int = abs(current_cell.y - player_cell.y)
		if max(dx, dy) == local_radius and not blocked_cells.has(current_cell):
			return false

		for neighbor in _get_cardinal_neighbors(current_cell):
			if visited.has(neighbor):
				continue
			if not is_cell_in_bounds(neighbor):
				continue
			if abs(neighbor.x - player_cell.x) > local_radius or abs(neighbor.y - player_cell.y) > local_radius:
				continue
			if neighbor != player_cell and blocked_cells.has(neighbor):
				continue
			visited[neighbor] = true
			queue.append(neighbor)

	return true


func get_cell_for_world_position(world_position: Vector2) -> Vector2i:
	return _world_to_cell(to_local(world_position))


func get_footprint_cells(anchor_cell: Vector2i, footprint_offsets: PackedVector2Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if footprint_offsets.is_empty():
		return cells
	for raw_offset in footprint_offsets:
		cells.append(anchor_cell + Vector2i(roundi(raw_offset.x), roundi(raw_offset.y)))
	return cells


func get_cells_for_world_rect(world_position: Vector2, size: Vector2) -> Array[Vector2i]:
	var local_center := to_local(world_position)
	var half_size := size * 0.5
	var min_cell := _world_to_cell(local_center - half_size)
	var max_cell := _world_to_cell(local_center + half_size)
	var cells: Array[Vector2i] = []
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			cells.append(Vector2i(x, y))
	return cells


func clear_runtime_occupancy() -> void:
	_occupied_cells.clear()


func clear_runtime_reserved_cells() -> void:
	_extra_reserved_cells.clear()


func register_reserved_cells(cells: Array[Vector2i]) -> void:
	for cell in cells:
		if not is_cell_in_bounds(cell):
			continue
		_extra_reserved_cells[cell] = true


func register_occupied_cells(cells: Array[Vector2i], occupant_id: StringName) -> void:
	for cell in cells:
		if not is_cell_in_bounds(cell):
			continue
		_occupied_cells[cell] = occupant_id


func register_occupied_footprint(anchor_cell: Vector2i, footprint_offsets: PackedVector2Array, occupant_id: StringName) -> void:
	register_occupied_cells(get_footprint_cells(anchor_cell, footprint_offsets), occupant_id)


func get_cell_occupant_id(cell: Vector2i) -> StringName:
	return StringName(_occupied_cells.get(cell, StringName()))


func _world_to_cell(local_position: Vector2) -> Vector2i:
	return Vector2i(
		floori((local_position.x + cell_size.x * 0.5) / cell_size.x),
		floori((local_position.y + cell_size.y * 0.5) / cell_size.y)
	)


func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x) * cell_size.x, float(cell.y) * cell_size.y)


func _update_preview_visual() -> void:
	for child in preview_footprint.get_children():
		child.queue_free()

	var center: Vector2 = _cell_to_world(_preview_cell)
	preview.position = center
	preview_outline.position = center
	var footprint_offsets := _preview_footprint_offsets
	if footprint_offsets.is_empty():
		footprint_offsets = PackedVector2Array([Vector2.ZERO])
	var footprint_cells := get_footprint_cells(_preview_cell, footprint_offsets)
	for footprint_cell in footprint_cells:
		_add_preview_footprint_cell(footprint_cell)

	var preview_reason := _get_footprint_preview_reason(_preview_cell, footprint_offsets)
	if preview_reason.is_empty():
		preview.color = Color(0.36, 0.9, 0.48, 0.58)
		preview_outline.default_color = Color(0.92, 1.0, 0.94, 0.96)
		_preview_reason = ""
	else:
		preview.color = Color(0.92, 0.34, 0.3, 0.58)
		preview_outline.default_color = Color(1.0, 0.92, 0.9, 0.96)
		_preview_reason = preview_reason

	_update_preview_footprint_color(is_footprint_valid_for_basic_placeable(_preview_cell, footprint_offsets))


func _rebuild_overlays() -> void:
	for child in blocked_overlay.get_children():
		child.queue_free()
	for child in buildable_overlay.get_children():
		child.queue_free()
	for child in reserved_overlay.get_children():
		child.queue_free()

	for x in range(grid_min_cell.x, grid_max_cell.x + 1):
		for y in range(grid_min_cell.y, grid_max_cell.y + 1):
			var cell := Vector2i(x, y)
			if is_cell_reserved(cell):
				continue
			if is_cell_tactical(cell):
				_add_overlay_cell(
					buildable_overlay,
					cell,
					Color(0.26, 0.58, 0.36, 0.28),
					Color(0.76, 0.96, 0.82, 0.62)
				)
	for raw_cell in reserved_cells:
		_add_overlay_cell(
			reserved_overlay,
			Vector2i(roundi(raw_cell.x), roundi(raw_cell.y)),
			Color(0.78, 0.28, 0.24, 0.28),
			Color(1.0, 0.82, 0.78, 0.62)
		)


func _add_preview_footprint_cell(cell: Vector2i) -> void:
	var fill_color := Color(0.36, 0.9, 0.48, 0.28)
	var border_color := Color(0.92, 1.0, 0.94, 0.72)
	_add_overlay_cell(preview_footprint, cell, fill_color, border_color)


func _get_footprint_preview_reason(anchor_cell: Vector2i, footprint_offsets: PackedVector2Array) -> String:
	var footprint_cells := get_footprint_cells(anchor_cell, footprint_offsets)
	if footprint_cells.is_empty():
		return "Blocked"

	for cell in footprint_cells:
		if not is_cell_in_bounds(cell):
			return "Outside grid"
		if is_cell_reserved(cell):
			return "Reserved"
		if not is_cell_tactical(cell):
			return "Not buildable"
		if is_cell_occupied(cell):
			return "Occupied"

	return ""


func _update_preview_footprint_color(is_valid: bool) -> void:
	for child in preview_footprint.get_children():
		var polygon := child as Polygon2D
		if polygon != null:
			polygon.color = Color(0.36, 0.9, 0.48, 0.28) if is_valid else Color(0.92, 0.34, 0.3, 0.28)
		var border := child as Line2D
		if border != null:
			border.default_color = Color(0.92, 1.0, 0.94, 0.72) if is_valid else Color(1.0, 0.92, 0.9, 0.72)


func _add_overlay_cell(parent_node: Node, cell: Vector2i, fill_color: Color, border_color: Color) -> void:
	var half_size := cell_size * 0.5 - Vector2(CELL_OUTLINE_INSET, CELL_OUTLINE_INSET)
	var polygon := Polygon2D.new()
	polygon.position = _cell_to_world(cell)
	polygon.color = fill_color
	polygon.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])
	parent_node.add_child(polygon)

	var border_half_size := cell_size * 0.5 - Vector2(CELL_BORDER_INSET, CELL_BORDER_INSET)
	var border := Line2D.new()
	border.position = _cell_to_world(cell)
	border.width = 2.0
	border.default_color = border_color
	border.closed = true
	border.points = PackedVector2Array([
		Vector2(-border_half_size.x, -border_half_size.y),
		Vector2(border_half_size.x, -border_half_size.y),
		Vector2(border_half_size.x, border_half_size.y),
		Vector2(-border_half_size.x, border_half_size.y),
	])
	parent_node.add_child(border)


func _has_cell(cells: PackedVector2Array, target: Vector2i) -> bool:
	for raw_cell in cells:
		if Vector2i(roundi(raw_cell.x), roundi(raw_cell.y)) == target:
			return true
	return false


func _get_cardinal_neighbors(cell: Vector2i) -> Array[Vector2i]:
	return [
		Vector2i(cell.x + 1, cell.y),
		Vector2i(cell.x - 1, cell.y),
		Vector2i(cell.x, cell.y + 1),
		Vector2i(cell.x, cell.y - 1),
	]


func _is_runtime_placeable_occupant_id(occupant_id: StringName) -> bool:
	if occupant_id == StringName():
		return false
	match occupant_id:
		&"sleep_point", &"food_table", &"wall_n", &"wall_s", &"door_e", &"door_w":
			return false
		_:
			return true


func _recalculate_buildable_bounds() -> void:
	if reserved_cells.is_empty():
		_buildable_bounds_min = grid_min_cell
		_buildable_bounds_max = grid_max_cell
		return

	var min_cell := Vector2i(2147483647, 2147483647)
	var max_cell := Vector2i(-2147483648, -2147483648)
	for raw_cell in reserved_cells:
		var cell := Vector2i(roundi(raw_cell.x), roundi(raw_cell.y))
		min_cell.x = min(min_cell.x, cell.x)
		min_cell.y = min(min_cell.y, cell.y)
		max_cell.x = max(max_cell.x, cell.x)
		max_cell.y = max(max_cell.y, cell.y)

	_buildable_bounds_min = Vector2i(max(min_cell.x - buildable_margin_cells, grid_min_cell.x), max(min_cell.y - buildable_margin_cells, grid_min_cell.y))
	_buildable_bounds_max = Vector2i(min(max_cell.x + buildable_margin_cells, grid_max_cell.x), min(max_cell.y + buildable_margin_cells, grid_max_cell.y))
