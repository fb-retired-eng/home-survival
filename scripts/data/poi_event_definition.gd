extends Resource
class_name PoiEventDefinition

@export var event_id: StringName = &"poi_event"
@export var display_name: String = "POI Event"
@export var description: String = ""
@export var reward_bonus: Dictionary = {}
@export_range(-3, 6, 1) var guard_count_delta: int = 0
@export var forces_elite: bool = false
@export var eligible_reward_roles: Array[StringName] = []
@export var eligible_poi_ids: Array[StringName] = []
@export var event_tint: Color = Color(0.92, 0.82, 0.4, 1.0)


func is_valid_definition() -> bool:
	return event_id != StringName() and not display_name.strip_edges().is_empty()
