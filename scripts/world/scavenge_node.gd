extends Area2D
class_name ScavengeNode

@export var node_id: StringName
@export var poi_id: StringName
@export var search_duration: float = 0.9
@export var search_energy_cost: int = 15

var is_depleted: bool = false
