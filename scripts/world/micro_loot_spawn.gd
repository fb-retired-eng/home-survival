extends Marker2D
class_name MicroLootSpawn

@export var spawn_id: StringName
@export_enum("salvage", "parts", "medicine", "bullets", "food") var resource_id: String = "salvage"
@export_range(1, 10, 1) var amount: int = 1


func is_valid_spawn() -> bool:
	return spawn_id != StringName() and amount > 0 and not resource_id.is_empty()
