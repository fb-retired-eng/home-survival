extends Resource
class_name PlaceableProfile

@export var placeable_id: StringName = &"placeable"
@export var display_name: String = "Placeable"
@export_enum("barrier", "trap", "utility", "turret") var category: String = "barrier"
@export_enum("tactical", "utility", "structural") var placement_layer: String = "tactical"
@export var footprint_cells: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
@export var build_cost: Dictionary = {}
@export var repair_cost: Dictionary = {}
@export var max_hp: int = 100
@export var blocks_movement: bool = true
@export var blocks_projectiles: bool = false
@export var can_stack_with_other_placeables: bool = false
@export var interaction_priority: int = 9
@export var contact_damage: int = 0
@export_range(0.0, 1.0, 0.05) var slow_factor: float = 0.0
@export_range(0.0, 600.0, 5.0) var lure_radius: float = 0.0
@export_range(0.0, 600.0, 5.0) var fire_range: float = 0.0
@export_range(0.0, 360.0, 1.0) var fire_arc: float = 90.0
@export_range(0.05, 10.0, 0.05) var fire_interval: float = 1.0
@export var bullet_cost_per_shot: int = 0
@export_range(1, 20, 1) var burst_count: int = 1
@export_range(0.0, 3.0, 0.05) var burst_spacing: float = 0.1
@export_range(0.0, 5.0, 0.05) var reload_time: float = 0.0
@export var line_of_fire_required: bool = true
@export var visual_color: Color = Color(0.72, 0.74, 0.78, 1.0)


func is_valid_profile() -> bool:
	if placeable_id == StringName():
		return false
	if display_name.is_empty():
		return false
	if category != "barrier" and category != "trap" and category != "utility" and category != "turret":
		return false
	if placement_layer != "tactical" and placement_layer != "utility" and placement_layer != "structural":
		return false
	if max_hp <= 0:
		return false
	if burst_count <= 0:
		return false
	if fire_interval <= 0.0:
		return false
	if bullet_cost_per_shot < 0:
		return false
	return not footprint_cells.is_empty()


func get_footprint_dimensions() -> Vector2i:
	return get_rotated_footprint_dimensions(0)


func get_rotated_footprint_offsets(rotation_steps: int) -> PackedVector2Array:
	if footprint_cells.is_empty():
		return PackedVector2Array([Vector2.ZERO])

	var normalized_steps := posmod(rotation_steps, 4)
	var transformed_cells: Array[Vector2i] = []
	for raw_cell in footprint_cells:
		var cell := Vector2i(roundi(raw_cell.x), roundi(raw_cell.y))
		for _index in range(normalized_steps):
			cell = Vector2i(cell.y, -cell.x)
		transformed_cells.append(cell)

	var min_cell := Vector2i(0, 0)
	for cell in transformed_cells:
		min_cell.x = min(min_cell.x, cell.x)
		min_cell.y = min(min_cell.y, cell.y)

	var rotated_offsets := PackedVector2Array()
	for cell in transformed_cells:
		var normalized_cell := cell - min_cell
		rotated_offsets.append(Vector2(normalized_cell))
	return rotated_offsets


func get_rotated_footprint_dimensions(rotation_steps: int) -> Vector2i:
	var rotated_offsets := get_rotated_footprint_offsets(rotation_steps)
	if rotated_offsets.is_empty():
		return Vector2i.ONE

	var max_cell := Vector2i.ZERO
	for raw_cell in rotated_offsets:
		var cell := Vector2i(roundi(raw_cell.x), roundi(raw_cell.y))
		max_cell.x = max(max_cell.x, cell.x)
		max_cell.y = max(max_cell.y, cell.y)
	return Vector2i(max_cell.x + 1, max_cell.y + 1)


func get_footprint_center_offset() -> Vector2:
	return get_rotated_footprint_center_offset(0)


func get_rotated_footprint_center_offset(rotation_steps: int) -> Vector2:
	var rotated_offsets := get_rotated_footprint_offsets(rotation_steps)
	if rotated_offsets.is_empty():
		return Vector2.ZERO

	var min_cell := Vector2i.ZERO
	var max_cell := Vector2i.ZERO
	for raw_cell in rotated_offsets:
		var cell := Vector2i(roundi(raw_cell.x), roundi(raw_cell.y))
		min_cell.x = min(min_cell.x, cell.x)
		min_cell.y = min(min_cell.y, cell.y)
		max_cell.x = max(max_cell.x, cell.x)
		max_cell.y = max(max_cell.y, cell.y)

	return Vector2(
		float(min_cell.x + max_cell.x) * 0.5,
		float(min_cell.y + max_cell.y) * 0.5
	)
