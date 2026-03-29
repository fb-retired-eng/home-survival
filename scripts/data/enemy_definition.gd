extends Resource
class_name EnemyDefinition

@export var enemy_id: StringName = &"enemy"
@export var max_health: int = 50
@export var defense_flat_reduction: int = 0
@export_range(0.0, 4.0, 0.05) var defense_multiplier: float = 1.0
@export var damage_taken_modifiers: Array[Resource] = []
@export var move_speed: float = 70.0
@export var player_damage: int = 10
@export var structure_damage: int = 10
@export var structure_damage_type: StringName = &"impact"
@export var attack_interval: float = 1.0
@export var drop_salvage: int = 1
@export var bonus_salvage: int = 1
@export_range(0.0, 1.0, 0.01) var bonus_salvage_chance: float = 0.2


func compute_damage_taken(base_damage: int, damage_type: StringName = &"melee") -> int:
	if base_damage <= 0:
		return 0

	var flat_reduction: int = defense_flat_reduction
	var multiplier: float = defense_multiplier

	for modifier in damage_taken_modifiers:
		if modifier == null:
			continue
		if StringName(modifier.get("damage_type")) != damage_type:
			continue

		flat_reduction = int(modifier.get("flat_reduction"))
		multiplier = float(modifier.get("multiplier"))
		break

	var reduced_damage: int = max(base_damage - flat_reduction, 0)
	return max(int(round(reduced_damage * multiplier)), 0)
