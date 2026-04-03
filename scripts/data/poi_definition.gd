extends Resource
class_name PoiDefinition

const SCAVENGE_BONUS_TABLE_SCRIPT := preload("res://scripts/data/scavenge_bonus_table.gd")
const ENEMY_DEFINITION_SCRIPT := preload("res://scripts/data/enemy_definition.gd")
const EMPTY_POI_ID: StringName = &""

@export var poi_id: StringName
@export var display_name: String = ""
@export var reward_role: StringName = &"mixed"
@export var bonus_table: Resource
@export var elite_modifier_eligible: bool = false
@export var daily_elite_definition: Resource


func is_valid_definition() -> bool:
	if poi_id == EMPTY_POI_ID:
		return false
	if display_name.strip_edges().is_empty():
		return false
	if get_reward_role_label().is_empty():
		return false
	if bonus_table != null and bonus_table.get_script() != SCAVENGE_BONUS_TABLE_SCRIPT:
		return false
	if daily_elite_definition != null:
		if daily_elite_definition.get_script() != ENEMY_DEFINITION_SCRIPT:
			return false
		if not daily_elite_definition.is_valid_definition():
			return false
		if not bool(daily_elite_definition.is_elite):
			return false
	return true


func get_reward_role_label() -> String:
	match reward_role:
		&"salvage_parts":
			return "Salvage / Parts"
		&"parts":
			return "Parts"
		&"food_medicine":
			return "Food / Medicine"
		&"ammo":
			return "Ammo"
		&"mixed":
			return "Mixed"
	return ""


func get_default_micro_loot_resource_id() -> String:
	match reward_role:
		&"salvage_parts":
			return "salvage"
		&"parts":
			return "parts"
		&"food_medicine":
			return "food"
		&"ammo":
			return "bullets"
		&"mixed":
			return "salvage"
	return "salvage"


func get_default_micro_loot_amount() -> int:
	match reward_role:
		&"salvage_parts":
			return 2
		&"parts":
			return 2
		&"food_medicine":
			return 1
		&"ammo":
			return 2
		&"mixed":
			return 1
	return 1


func get_bonus_table_alignment_warnings() -> Array[String]:
	var warnings: Array[String] = []
	if bonus_table == null or bonus_table.get_script() != SCAVENGE_BONUS_TABLE_SCRIPT:
		return warnings

	var expected_resources := _get_expected_primary_resources()
	if expected_resources.is_empty():
		return warnings

	var supported_weight := 0.0
	var best_resource_id := ""
	var best_weight := -1.0
	for resource_id in ["salvage", "parts", "medicine", "bullets", "food"]:
		var weight := _get_bonus_weight(resource_id)
		if expected_resources.has(resource_id):
			supported_weight += weight
		if weight > best_weight:
			best_weight = weight
			best_resource_id = resource_id

	if supported_weight <= 0.0:
		warnings.append("%s role expects %s rewards, but bonus table has no matching weight." % [display_name, ", ".join(expected_resources)])
	elif not expected_resources.has(best_resource_id):
		warnings.append("%s role expects %s rewards, but bonus table is led by %s." % [display_name, ", ".join(expected_resources), best_resource_id])
	return warnings


func _get_expected_primary_resources() -> Array[String]:
	match reward_role:
		&"salvage_parts":
			return ["salvage", "parts"]
		&"parts":
			return ["parts"]
		&"food_medicine":
			return ["food", "medicine"]
		&"ammo":
			return ["bullets"]
	return []


func _get_bonus_weight(resource_id: String) -> float:
	match resource_id:
		"salvage":
			return float(bonus_table.salvage_weight)
		"parts":
			return float(bonus_table.parts_weight)
		"medicine":
			return float(bonus_table.medicine_weight)
		"bullets":
			return float(bonus_table.bullets_weight)
		"food":
			return float(bonus_table.food_weight)
	return 0.0
