extends Resource
class_name DamageTypeModifier

@export var damage_type: StringName = &"impact"
@export var flat_reduction: int = 0
@export_range(0.0, 4.0, 0.05) var multiplier: float = 1.0
