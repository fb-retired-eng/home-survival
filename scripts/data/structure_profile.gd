extends Resource
class_name StructureProfile

@export var profile_id: StringName = &"structure"
@export var damaged_max_hp: int = 90
@export var reinforced_max_hp: int = 180
@export var damaged_repair_salvage_cost: int = 2
@export var reinforced_repair_salvage_cost: int = 3
@export var strengthen_salvage_cost: int = 6
@export var strengthen_parts_cost: int = 2
@export var default_flat_reduction: int = 0
@export_range(0.0, 4.0, 0.05) var default_multiplier: float = 1.0
@export var damage_modifiers: Array[Resource] = []
@export var interaction_priority: int = 10
@export var damaged_color: Color = Color(0.57, 0.45, 0.35, 1.0)
@export var reinforced_color: Color = Color(0.48, 0.68, 0.72, 1.0)
@export var breached_color: Color = Color(0.24, 0.18, 0.18, 1.0)


func get_max_hp_for_tier(tier: String) -> int:
	if tier == "reinforced":
		return reinforced_max_hp
	return damaged_max_hp


func get_repair_cost(tier: String) -> Dictionary:
	if tier == "reinforced":
		return {"salvage": reinforced_repair_salvage_cost}
	return {"salvage": damaged_repair_salvage_cost}


func get_strengthen_cost() -> Dictionary:
	return {
		"salvage": strengthen_salvage_cost,
		"parts": strengthen_parts_cost,
	}


func compute_damage_taken(base_damage: int, damage_type: StringName = &"impact") -> int:
	if base_damage <= 0:
		return 0

	var flat_reduction: int = default_flat_reduction
	var multiplier: float = default_multiplier

	for modifier in damage_modifiers:
		if modifier == null:
			continue
		if StringName(modifier.get("damage_type")) != damage_type:
			continue

		flat_reduction = int(modifier.get("flat_reduction"))
		multiplier = float(modifier.get("multiplier"))
		break

	var reduced_damage: int = max(base_damage - flat_reduction, 0)
	return max(int(round(reduced_damage * multiplier)), 0)
