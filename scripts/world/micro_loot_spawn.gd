extends Marker2D
class_name MicroLootSpawn

@export var spawn_id: StringName
@export var poi_id: StringName
@export var use_poi_role_defaults: bool = false
@export_enum("salvage", "parts", "medicine", "bullets", "food") var resource_id: String = "salvage"
@export_range(1, 10, 1) var amount: int = 1


func is_valid_spawn() -> bool:
	if spawn_id == StringName():
		return false
	if use_poi_role_defaults:
		return poi_id != StringName()
	return amount > 0 and not resource_id.is_empty()
