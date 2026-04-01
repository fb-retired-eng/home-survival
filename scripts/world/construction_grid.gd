extends Node2D
class_name ConstructionGrid

const CELL_OUTLINE_INSET := 4.0
const CELL_BORDER_INSET := 2.0

@export var cell_size: Vector2 = Vector2(48.0, 48.0)
@export var grid_min_cell: Vector2i = Vector2i.ZERO
@export var grid_max_cell: Vector2i = Vector2i.ZERO
@export var tactical_cells: PackedVector2Array = PackedVector2Array()
@export var reserved_cells: PackedVector2Array = PackedVector2Array()

var _build_mode_active: bool = false
var _preview_cell: Vector2i = Vector2i.ZERO
var _preview_reason: String = ""
var _occupied_cells: Dictionary = {}

@onready var buildable_overlay: Node2D = $BuildableOverlay
@onready var reserved_overlay: Node2D = $ReservedOverlay
@onready var preview: Polygon2D = $Preview
@onready var preview_outline: Line2D = $PreviewOutline


func _ready() -> void:
	_rebuild_overlays()
	set_build_mode_active(false)


func set_build_mode_active(active: bool) -> void:
	_build_mode_active = active
	buildable_overlay.visible = active
	reserved_overlay.visible = active
	preview.visible = active
	preview_outline.visible = active


func is_build_mode_active() -> bool:
	return _build_mode_active


func set_preview_world_position(world_position: Vector2) -> void:
	var local_position: Vector2 = to_local(world_position)
	var target_cell: Vector2i = _world_to_cell(local_position)
	_preview_cell = target_cell
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
	if tactical_cells.is_empty():
		return true
	return _has_cell(tactical_cells, cell)


func is_cell_in_bounds(cell: Vector2i) -> bool:
	return (
		cell.x >= grid_min_cell.x
		and cell.x <= grid_max_cell.x
		and cell.y >= grid_min_cell.y
		and cell.y <= grid_max_cell.y
	)


func is_cell_reserved(cell: Vector2i) -> bool:
	return _has_cell(reserved_cells, cell)


func is_cell_occupied(cell: Vector2i) -> bool:
	return _occupied_cells.has(cell)


func is_cell_valid_for_basic_placeable(cell: Vector2i) -> bool:
	return is_footprint_valid_for_basic_placeable(cell, PackedVector2Array([Vector2.ZERO]))


func is_footprint_valid_for_basic_placeable(anchor_cell: Vector2i, footprint_offsets: PackedVector2Array) -> bool:
	var footprint_cells := get_footprint_cells(anchor_cell, footprint_offsets)
	if footprint_cells.is_empty():
		return false
	for cell in footprint_cells:
		if not is_cell_tactical(cell):
			return false
		if is_cell_reserved(cell):
			return false
		if is_cell_occupied(cell):
			return false
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
	var center: Vector2 = _cell_to_world(_preview_cell)
	preview.position = center
	preview_outline.position = center
	if is_cell_valid_for_basic_placeable(_preview_cell):
		preview.color = Color(0.36, 0.9, 0.48, 0.58)
		preview_outline.default_color = Color(0.92, 1.0, 0.94, 0.96)
		_preview_reason = ""
	elif is_cell_reserved(_preview_cell):
		preview.color = Color(0.92, 0.34, 0.3, 0.58)
		preview_outline.default_color = Color(1.0, 0.92, 0.9, 0.96)
		_preview_reason = "Reserved"
	elif is_cell_occupied(_preview_cell):
		preview.color = Color(0.92, 0.34, 0.3, 0.58)
		preview_outline.default_color = Color(1.0, 0.92, 0.9, 0.96)
		_preview_reason = "Blocked"
	else:
		preview.color = Color(0.92, 0.34, 0.3, 0.58)
		preview_outline.default_color = Color(1.0, 0.92, 0.9, 0.96)
		_preview_reason = "Blocked"


func _rebuild_overlays() -> void:
	for child in buildable_overlay.get_children():
		child.queue_free()
	for child in reserved_overlay.get_children():
		child.queue_free()

	if tactical_cells.is_empty():
		for x in range(grid_min_cell.x, grid_max_cell.x + 1):
			for y in range(grid_min_cell.y, grid_max_cell.y + 1):
				var cell := Vector2i(x, y)
				if is_cell_reserved(cell):
					continue
				_add_overlay_cell(
					buildable_overlay,
					cell,
					Color(0.26, 0.58, 0.36, 0.18),
					Color(0.76, 0.96, 0.82, 0.42)
				)
	else:
		for raw_cell in tactical_cells:
			_add_overlay_cell(
				buildable_overlay,
				Vector2i(roundi(raw_cell.x), roundi(raw_cell.y)),
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
