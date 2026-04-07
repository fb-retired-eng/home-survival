extends Area2D
class_name ScavengeNode

const WEAPON_DEFINITION_SCRIPT := preload("res://scripts/data/weapon_definition.gd")

signal state_changed(node: ScavengeNode)

@export var node_id: StringName
@export var poi_id: StringName
@export var search_duration: float = 0.9
@export var search_energy_cost: int = 15
@export var reward_salvage: int = 0
@export var reward_parts: int = 0
@export var reward_medicine: int = 0
@export var reward_bullets: int = 0
@export var reward_food: int = 0
@export var reward_battery: int = 0
@export var weapon_reward: Resource
@export var bonus_table: Resource

var is_depleted: bool = false
var _is_searching: bool = false
var _reward_modifier_provider: Callable = Callable()
var _current_reward_salvage: int = 0
var _current_reward_parts: int = 0
var _current_reward_medicine: int = 0
var _current_reward_bullets: int = 0
var _current_reward_food: int = 0
var _current_reward_battery: int = 0

@onready var visual: Polygon2D = $Visual
@onready var label: Label = $Label


func _ready() -> void:
	add_to_group("scavenge_nodes")
	if weapon_reward != null and _get_valid_weapon_reward() == null:
		push_warning("ScavengeNode %s has invalid weapon_reward." % String(node_id))
	_reset_current_rewards_from_authored()
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
		"salvage": _current_reward_salvage,
		"parts": _current_reward_parts,
		"medicine": _current_reward_medicine,
		"bullets": _current_reward_bullets,
		"food": _current_reward_food,
		"battery": _current_reward_battery,
	}
	_zero_current_rewards()
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
	for resource_id in ["salvage", "parts", "medicine", "bullets", "food", "battery"]:
		rewards[resource_id] = int(rewards.get(resource_id, 0)) + int(rolled_rewards.get(resource_id, 0))


func _grant_rewards(player, rewards: Dictionary) -> void:
	var reward_summary: Array[String] = []
	for resource_id in ["salvage", "parts", "medicine", "bullets", "food", "battery"]:
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
	state_changed.emit(self)


func reset_for_new_run() -> void:
	is_depleted = false
	_is_searching = false
	_reset_current_rewards_from_authored()
	_refresh_visuals()


func get_save_state() -> Dictionary:
	return {
		"node_id": String(node_id),
		"poi_id": String(poi_id),
		"is_depleted": is_depleted,
		"current_rewards": get_remaining_rewards(),
	}


func apply_save_state(save_state: Dictionary) -> void:
	is_depleted = bool(save_state.get("is_depleted", is_depleted))
	_is_searching = false
	_reset_current_rewards_from_authored()
	var current_rewards: Dictionary = save_state.get("current_rewards", {})
	_current_reward_salvage = int(current_rewards.get("salvage", _current_reward_salvage))
	_current_reward_parts = int(current_rewards.get("parts", _current_reward_parts))
	_current_reward_medicine = int(current_rewards.get("medicine", _current_reward_medicine))
	_current_reward_bullets = int(current_rewards.get("bullets", _current_reward_bullets))
	_current_reward_food = int(current_rewards.get("food", _current_reward_food))
	_current_reward_battery = int(current_rewards.get("battery", _current_reward_battery))
	_sync_depletion_from_current_rewards()
	_refresh_visuals()


func is_eligible_for_daily_refill() -> bool:
	if _is_searching or not is_depleted:
		return false
	if _get_valid_weapon_reward() != null:
		return false
	return reward_salvage > 0 or reward_parts > 0 or reward_medicine > 0 or reward_bullets > 0 or reward_food > 0 or reward_battery > 0


func apply_daily_refill() -> bool:
	if not is_eligible_for_daily_refill():
		return false
	is_depleted = false
	_reset_current_rewards_from_authored()
	_refresh_visuals()
	return true


func configure_reward_modifier(provider: Callable) -> void:
	_reward_modifier_provider = provider


func get_remaining_rewards() -> Dictionary:
	return {
		"salvage": _current_reward_salvage,
		"parts": _current_reward_parts,
		"medicine": _current_reward_medicine,
		"bullets": _current_reward_bullets,
		"food": _current_reward_food,
		"battery": _current_reward_battery,
	}


func get_remaining_reward_total() -> int:
	return _current_reward_salvage + _current_reward_parts + _current_reward_medicine + _current_reward_bullets + _current_reward_food + _current_reward_battery


func has_weapon_reward() -> bool:
	return _get_valid_weapon_reward() != null


func consume_all_remaining_rewards() -> Dictionary:
	if is_depleted:
		return {
			"salvage": 0,
			"parts": 0,
			"medicine": 0,
			"bullets": 0,
			"food": 0,
			"battery": 0,
		}
	var consumed := get_remaining_rewards()
	_zero_current_rewards()
	_sync_depletion_from_current_rewards()
	_refresh_visuals()
	return consumed


func consume_remaining_reward(resource_id: String, amount: int) -> int:
	if amount <= 0 or is_depleted:
		return 0
	var consumed := 0
	match resource_id:
		"salvage":
			consumed = mini(_current_reward_salvage, amount)
			_current_reward_salvage -= consumed
		"parts":
			consumed = mini(_current_reward_parts, amount)
			_current_reward_parts -= consumed
		"medicine":
			consumed = mini(_current_reward_medicine, amount)
			_current_reward_medicine -= consumed
		"bullets":
			consumed = mini(_current_reward_bullets, amount)
			_current_reward_bullets -= consumed
		"food":
			consumed = mini(_current_reward_food, amount)
			_current_reward_food -= consumed
		"battery":
			consumed = mini(_current_reward_battery, amount)
			_current_reward_battery -= consumed
	_sync_depletion_from_current_rewards()
	_refresh_visuals()
	return consumed


func _reset_current_rewards_from_authored() -> void:
	_current_reward_salvage = reward_salvage
	_current_reward_parts = reward_parts
	_current_reward_medicine = reward_medicine
	_current_reward_bullets = reward_bullets
	_current_reward_food = reward_food
	_current_reward_battery = reward_battery


func _zero_current_rewards() -> void:
	_current_reward_salvage = 0
	_current_reward_parts = 0
	_current_reward_medicine = 0
	_current_reward_bullets = 0
	_current_reward_food = 0
	_current_reward_battery = 0


func _sync_depletion_from_current_rewards() -> void:
	if _get_valid_weapon_reward() != null:
		return
	var total_remaining := _current_reward_salvage + _current_reward_parts + _current_reward_medicine + _current_reward_bullets + _current_reward_food + _current_reward_battery
	if total_remaining <= 0:
		is_depleted = true
