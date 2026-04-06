extends Resource
class_name DailyMutatorDefinition

@export var mutator_id: StringName = &"daily_mutator"
@export var display_name: String = "Daily Mutator"
@export var description: String = ""
@export_range(0, 6, 1) var patrol_count_bonus: int = 0
@export_range(0, 4, 1) var poi_guard_bonus: int = 0
@export_range(0, 3, 1) var salvage_bonus: int = 0
@export_range(0.0, 0.5, 0.01) var floodlight_slow_bonus: float = 0.0
@export_range(0.0, 1.0, 0.01) var enemy_speed_multiplier_bonus: float = 0.0


func is_valid_definition() -> bool:
	return mutator_id != StringName() and not display_name.strip_edges().is_empty()
