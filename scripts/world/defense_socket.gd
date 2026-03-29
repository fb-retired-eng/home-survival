extends Area2D
class_name DefenseSocket

@export var socket_id: StringName
@export_enum("wall", "door") var socket_type: String = "wall"
@export_enum("damaged", "reinforced") var tier: String = "damaged"
@export var current_hp: int = 90
@export var max_hp: int = 90

@onready var visual: Polygon2D = $Visual
@onready var label: Label = $Label


func _ready() -> void:
	max_hp = _get_max_hp_for_tier(tier)
	current_hp = clamp(current_hp, 0, max_hp)
	_refresh_visuals()


func get_interaction_label(player) -> String:
	var action := _get_available_action()
	match action:
		"repair":
			var cost := _get_repair_cost()
			if player != null and not player.has_resources(cost):
				return "Repair (need %s)" % _format_cost(cost)
			return "Repair (%s)" % _format_cost(cost)
		"strengthen":
			var strengthen_cost := _get_strengthen_cost()
			if player != null and not player.has_resources(strengthen_cost):
				return "Strengthen (need %s)" % _format_cost(strengthen_cost)
			return "Strengthen (%s)" % _format_cost(strengthen_cost)
		_:
			return ""


func can_interact(_player) -> bool:
	return _get_available_action() != ""


func interact(player) -> void:
	var action := _get_available_action()
	if action.is_empty():
		return

	if action == "repair":
		var repair_cost := _get_repair_cost()
		if not player.spend_resources(repair_cost):
			player.message_requested.emit("Not enough resources")
			return
		current_hp = _get_max_hp_for_tier(tier)
		player.message_requested.emit("Base repaired")
	elif action == "strengthen":
		var strengthen_cost := _get_strengthen_cost()
		if not player.spend_resources(strengthen_cost):
			player.message_requested.emit("Not enough resources")
			return
		tier = "reinforced"
		max_hp = _get_max_hp_for_tier(tier)
		current_hp = max_hp
		player.message_requested.emit("Base strengthened")

	_refresh_visuals()


func take_damage(amount: int, _source: Variant = null) -> void:
	if amount <= 0:
		return

	current_hp = max(current_hp - amount, 0)
	_refresh_visuals()


func _get_available_action() -> String:
	if tier == "damaged":
		if current_hp < _get_max_hp_for_tier("damaged"):
			return "repair"
		return "strengthen"

	if tier == "reinforced" and current_hp < _get_max_hp_for_tier("reinforced"):
		return "repair"

	return ""


func _get_max_hp_for_tier(target_tier: String) -> int:
	if socket_type == "door":
		if target_tier == "reinforced":
			return 130
		return 60

	if target_tier == "reinforced":
		return 180
	return 90


func _get_repair_cost() -> Dictionary:
	if tier == "reinforced":
		if socket_type == "door":
			return {"salvage": 2}
		return {"salvage": 3}

	if socket_type == "door":
		return {"salvage": 1}
	return {"salvage": 2}


func _get_strengthen_cost() -> Dictionary:
	if socket_type == "door":
		return {
			"salvage": 4,
			"parts": 1,
		}

	return {
		"salvage": 6,
		"parts": 2,
	}


func _format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in ["salvage", "parts", "medicine"]:
		var amount := int(cost.get(resource_id, 0))
		if amount <= 0:
			continue
		parts.append("%d %s" % [amount, resource_id.capitalize()])
	return ", ".join(parts)


func _refresh_visuals() -> void:
	var target_max_hp := _get_max_hp_for_tier(tier)
	max_hp = target_max_hp
	current_hp = clamp(current_hp, 0, max_hp)

	if current_hp <= 0:
		visual.color = Color(0.24, 0.18, 0.18, 1.0)
	elif tier == "reinforced":
		visual.color = Color(0.48, 0.68, 0.72, 1.0)
	elif socket_type == "door":
		visual.color = Color(0.74, 0.49, 0.26, 1.0)
	else:
		visual.color = Color(0.57, 0.45, 0.35, 1.0)

	label.text = "%s %d/%d" % [socket_id, current_hp, max_hp]
