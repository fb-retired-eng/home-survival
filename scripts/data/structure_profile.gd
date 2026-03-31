extends Resource
class_name StructureProfile

const DAMAGE_TYPE_MODIFIER_SCRIPT := preload("res://scripts/data/damage_type_modifier.gd")

@export var profile_id: StringName = &"structure"
@export var damaged_max_hp: int = 90
@export var reinforced_max_hp: int = 180
@export var fortified_max_hp: int = 320
@export var damaged_repair_salvage_cost: int = 2
@export var reinforced_repair_salvage_cost: int = 3
@export var fortified_repair_salvage_cost: int = 5
@export var fortified_repair_parts_cost: int = 1
@export var strengthen_salvage_cost: int = 6
@export var strengthen_parts_cost: int = 2
@export var fortify_salvage_cost: int = 8
@export var fortify_parts_cost: int = 4
@export var default_flat_reduction: int = 0
@export_range(0.0, 4.0, 0.05) var default_multiplier: float = 1.0
@export var reinforced_flat_reduction_bonus: int = 0
@export var fortified_flat_reduction_bonus: int = 0
@export_range(0.0, 4.0, 0.05) var reinforced_tier_multiplier: float = 1.0
@export_range(0.0, 4.0, 0.05) var fortified_tier_multiplier: float = 1.0
@export var damage_modifiers: Array[Resource] = []
@export var interaction_priority: int = 10
@export var damaged_color: Color = Color(0.57, 0.45, 0.35, 1.0)
@export var reinforced_color: Color = Color(0.48, 0.68, 0.72, 1.0)
@export var fortified_color: Color = Color(0.76, 0.84, 0.92, 1.0)
@export var breached_color: Color = Color(0.24, 0.18, 0.18, 1.0)


func is_valid_profile(expected_profile_id: StringName = &"") -> bool:
	if expected_profile_id != StringName() and profile_id != expected_profile_id:
		return false

	for modifier in damage_modifiers:
		if modifier == null:
			return false
		if modifier.get_script() != DAMAGE_TYPE_MODIFIER_SCRIPT:
			return false

	return true


func get_max_hp_for_tier(tier: String) -> int:
	if tier == "fortified":
		return fortified_max_hp
	if tier == "reinforced":
		return reinforced_max_hp
	return damaged_max_hp


func get_repair_cost(tier: String) -> Dictionary:
	if tier == "fortified":
		return {
			"salvage": fortified_repair_salvage_cost,
			"parts": fortified_repair_parts_cost,
		}
	if tier == "reinforced":
		return {"salvage": reinforced_repair_salvage_cost}
	return {"salvage": damaged_repair_salvage_cost}


func get_strengthen_cost() -> Dictionary:
	return {
		"salvage": strengthen_salvage_cost,
		"parts": strengthen_parts_cost,
	}


func get_fortify_cost() -> Dictionary:
	return {
		"salvage": fortify_salvage_cost,
		"parts": fortify_parts_cost,
	}


func compute_damage_taken(base_damage: int, damage_type: StringName = &"impact", tier: String = "damaged") -> int:
	if base_damage <= 0:
		return 0

	var flat_reduction: int = default_flat_reduction
	var multiplier: float = default_multiplier

	for modifier in damage_modifiers:
		if modifier == null:
			continue
		if modifier.get_script() != DAMAGE_TYPE_MODIFIER_SCRIPT:
			continue
		if StringName(modifier.get("damage_type")) != damage_type:
			continue

		flat_reduction = int(modifier.get("flat_reduction"))
		multiplier = float(modifier.get("multiplier"))
		break

	match tier:
		"fortified":
			flat_reduction += fortified_flat_reduction_bonus
			multiplier *= fortified_tier_multiplier
		"reinforced":
			flat_reduction += reinforced_flat_reduction_bonus
			multiplier *= reinforced_tier_multiplier

	var reduced_damage: int = max(base_damage - flat_reduction, 0)
	return max(int(round(reduced_damage * multiplier)), 0)
