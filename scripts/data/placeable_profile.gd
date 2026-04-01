extends Resource
class_name PlaceableProfile

@export var placeable_id: StringName = &"placeable"
@export var display_name: String = "Placeable"
@export_enum("barrier", "trap", "utility", "turret") var category: String = "barrier"
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
	if max_hp <= 0:
		return false
	if burst_count <= 0:
		return false
	if fire_interval <= 0.0:
		return false
	if bullet_cost_per_shot < 0:
		return false
	return not footprint_cells.is_empty()
