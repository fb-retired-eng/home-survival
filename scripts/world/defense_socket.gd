extends Area2D
class_name DefenseSocket

@export var socket_id: StringName
@export_enum("wall", "door") var socket_type: String = "wall"
@export_enum("damaged", "reinforced") var tier: String = "damaged"
@export var current_hp: int = 90
@export var max_hp: int = 90
