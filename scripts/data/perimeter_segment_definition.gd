extends Resource
class_name PerimeterSegmentDefinition

@export var socket_id: StringName
@export_enum("wall", "door") var socket_type: String = "wall"
@export_enum("damaged", "reinforced", "fortified") var tier: String = "damaged"
@export var position: Vector2 = Vector2.ZERO
@export var current_hp: int = 90
@export var structure_profile: Resource
@export var socket_size: Vector2 = Vector2(48, 16)
@export var interaction_area_offset: Vector2 = Vector2.ZERO
@export var interaction_area_size: Vector2 = Vector2(48, 24)
