extends Marker2D
class_name RoamingSpawnZone

@export var zone_id: StringName
@export_range(0.0, 320.0, 1.0) var scatter_radius: float = 120.0
@export_range(0.1, 10.0, 0.1) var spawn_weight: float = 1.0


func is_valid_spawn_zone() -> bool:
	return zone_id != StringName() and scatter_radius >= 0.0 and spawn_weight > 0.0
