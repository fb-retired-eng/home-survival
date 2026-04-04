extends Resource
class_name LegacyPerkDefinition

@export var perk_id: StringName = &"max_energy"
@export var display_name: String = "+10 Max Energy"
@export var description: String = ""
@export_range(0, 100, 1) var max_energy_bonus: int = 0
@export_range(0, 100, 1) var stash_battery_bonus: int = 0
@export_range(0, 200, 1) var stash_bullets_bonus: int = 0
@export_range(0, 100, 1) var dog_max_stamina_bonus: int = 0


func is_valid_definition() -> bool:
	return perk_id != StringName() and not display_name.is_empty()
