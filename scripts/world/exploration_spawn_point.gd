extends Marker2D
class_name ExplorationSpawnPoint

const ENEMY_DEFINITION_SCRIPT := preload("res://scripts/data/enemy_definition.gd")

@export var spawn_id: StringName
@export var poi_id: StringName
@export var enemy_definition: Resource
@export_range(1, 12, 1) var min_count: int = 1
@export_range(1, 12, 1) var max_count: int = 5
@export_range(0.0, 256.0, 1.0) var scatter_radius: float = 36.0
@export var use_initial_facing: bool = false
@export_range(0.0, 360.0, 1.0) var initial_facing_degrees: float = 270.0


func is_valid_spawn_point() -> bool:
	if spawn_id == StringName():
		return false
	if enemy_definition == null or enemy_definition.get_script() != ENEMY_DEFINITION_SCRIPT:
		return false
	if min_count <= 0 or max_count < min_count:
		return false
	if scatter_radius < 0.0:
		return false
	return enemy_definition.is_valid_definition()


func get_initial_facing_vector() -> Vector2:
	if not use_initial_facing:
		return Vector2.ZERO
	return Vector2.RIGHT.rotated(deg_to_rad(initial_facing_degrees))


func get_anchor_position() -> Vector2:
	return global_position
