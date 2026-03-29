extends Resource
class_name ScavengeBonusTable

@export var empty_weight: float = 0.0
@export var salvage_weight: float = 0.0
@export var parts_weight: float = 0.0
@export var medicine_weight: float = 0.0

@export var salvage_amount: int = 1
@export var parts_amount: int = 1
@export var medicine_amount: int = 1


func roll_bonus() -> Dictionary:
	var rewards := {
		"salvage": 0,
		"parts": 0,
		"medicine": 0,
	}
	var total_weight: float = max(empty_weight, 0.0) + max(salvage_weight, 0.0) + max(parts_weight, 0.0) + max(medicine_weight, 0.0)
	if total_weight <= 0.0:
		return rewards

	var roll: float = randf() * total_weight
	roll -= max(empty_weight, 0.0)
	if roll < 0.0:
		return rewards

	roll -= max(salvage_weight, 0.0)
	if roll < 0.0:
		rewards["salvage"] = max(salvage_amount, 0)
		return rewards

	roll -= max(parts_weight, 0.0)
	if roll < 0.0:
		rewards["parts"] = max(parts_amount, 0)
		return rewards

	rewards["medicine"] = max(medicine_amount, 0)
	return rewards
