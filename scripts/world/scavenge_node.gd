extends Area2D
class_name ScavengeNode

const WEAPON_DEFINITION_SCRIPT := preload("res://scripts/data/weapon_definition.gd")

@export var node_id: StringName
@export var poi_id: StringName
@export var search_duration: float = 0.9
@export var search_energy_cost: int = 15
@export var reward_salvage: int = 0
@export var reward_parts: int = 0
@export var reward_medicine: int = 0
@export var reward_bullets: int = 0
@export var reward_food: int = 0
@export var weapon_reward: Resource
@export var bonus_table: Resource

var is_depleted: bool = false
var _is_searching: bool = false
var _reward_modifier_provider: Callable = Callable()

@onready var visual: Polygon2D = $Visual
@onready var label: Label = $Label


func _ready() -> void:
	add_to_group("scavenge_nodes")
	if weapon_reward != null and _get_valid_weapon_reward() == null:
		push_warning("ScavengeNode %s has invalid weapon_reward." % String(node_id))
	_refresh_visuals()


func get_interaction_label(player) -> String:
	if is_depleted:
		return ""

	if _is_searching:
		return "Searching..."

	if player != null and not player.can_spend_energy(search_energy_cost):
		return "Too tired to search"

	return "Search (%d energy)" % search_energy_cost


func can_interact(_player) -> bool:
	return not is_depleted and not _is_searching


func get_interaction_priority(_player) -> int:
	return 20


func interact(player) -> void:
	if is_depleted or _is_searching:
		return

	if not player.can_spend_energy(search_energy_cost):
		player.message_requested.emit("Too tired")
		return

	if not player.spend_energy(search_energy_cost):
		player.message_requested.emit("Too tired")
		return

	_is_searching = true
	_refresh_visuals()
	if not player.begin_timed_action(search_duration, "Searching...", Callable(self, "_complete_search").bind(player)):
		_is_searching = false
		player.restore_energy(search_energy_cost)
		_refresh_visuals()


func _complete_search(player) -> void:
	_is_searching = false
	is_depleted = true
	var rewards := {
		"salvage": reward_salvage,
		"parts": reward_parts,
		"medicine": reward_medicine,
		"bullets": reward_bullets,
		"food": reward_food,
	}
	if _reward_modifier_provider.is_valid():
		rewards = _reward_modifier_provider.call(self, rewards)
	_apply_bonus_reward(rewards)
	_grant_rewards(player, rewards)
	_refresh_visuals()


func _apply_bonus_reward(rewards: Dictionary) -> void:
	if bonus_table == null:
		return

	if not bonus_table.has_method("roll_bonus"):
		return

	var rolled_rewards: Dictionary = bonus_table.roll_bonus()
	for resource_id in ["salvage", "parts", "medicine", "bullets", "food"]:
		rewards[resource_id] = int(rewards.get(resource_id, 0)) + int(rolled_rewards.get(resource_id, 0))


func _grant_rewards(player, rewards: Dictionary) -> void:
	var reward_summary: Array[String] = []
	for resource_id in ["salvage", "parts", "medicine", "bullets", "food"]:
		var amount := int(rewards.get(resource_id, 0))
		if amount <= 0:
			continue

		player.add_resource(resource_id, amount, false)
		reward_summary.append("%s +%d" % [resource_id.capitalize(), amount])

	var granted_weapon := _get_valid_weapon_reward()
	if granted_weapon != null:
		if player.has_method("obtain_weapon"):
			if player.obtain_weapon(granted_weapon, true, false):
				reward_summary.append("%s obtained" % granted_weapon.display_name)
		elif player.has_method("equip_weapon"):
			if player.equip_weapon(granted_weapon, false):
				reward_summary.append("%s equipped" % granted_weapon.display_name)

	if reward_summary.is_empty():
		player.message_requested.emit("Searched node")
	else:
		player.message_requested.emit(", ".join(reward_summary))


func _get_valid_weapon_reward() -> Resource:
	if weapon_reward == null:
		return null
	if weapon_reward.get_script() != WEAPON_DEFINITION_SCRIPT and not weapon_reward.is_class("WeaponDefinition"):
		return null
	if not weapon_reward.has_method("is_valid_definition"):
		return null
	if not weapon_reward.is_valid_definition():
		return null
	return weapon_reward


func _refresh_visuals() -> void:
	if is_depleted:
		visual.color = Color(0.33, 0.33, 0.35, 1.0)
		label.text = "Depleted"
	elif _is_searching:
		visual.color = Color(0.98, 0.9, 0.48, 1.0)
		label.text = "Searching..."
	else:
		visual.color = Color(0.93, 0.79, 0.35, 1.0)
		label.text = "Search"


func reset_for_new_run() -> void:
	is_depleted = false
	_is_searching = false
	_refresh_visuals()


func is_eligible_for_daily_refill() -> bool:
	if _is_searching or not is_depleted:
		return false
	if _get_valid_weapon_reward() != null:
		return false
	return reward_salvage > 0 or reward_parts > 0 or reward_medicine > 0 or reward_bullets > 0 or reward_food > 0


func apply_daily_refill() -> bool:
	if not is_eligible_for_daily_refill():
		return false
	is_depleted = false
	_refresh_visuals()
	return true


func configure_reward_modifier(provider: Callable) -> void:
	_reward_modifier_provider = provider
