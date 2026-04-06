extends Marker2D
class_name PatrolRoutePoint

@export var patrol_id: StringName
@export_range(0, 32, 1) var order_index: int = 0
@export_range(0.0, 96.0, 1.0) var arrival_radius: float = 18.0


func is_valid_route_point() -> bool:
	return patrol_id != StringName() and order_index >= 0 and arrival_radius >= 0.0
