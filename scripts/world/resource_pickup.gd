extends Area2D
class_name ResourcePickup

signal collected(pickup: ResourcePickup, player)

@export_enum("salvage", "parts", "medicine", "bullets", "food", "battery") var resource_id: String = "salvage"
@export var amount: int = 1
@export var is_weapon_drop: bool = false
@export var weapon_reward: Resource

@onready var visual: Polygon2D = $Visual
@onready var label: Label = $Label


func _ready() -> void:
	add_to_group("pickups")
	_sync_visuals()


func collect(player) -> void:
	if player == null:
		return

	if is_weapon_drop and weapon_reward != null and player.has_method("obtain_weapon"):
		if not player.obtain_weapon(weapon_reward, true, false):
			if bool(weapon_reward.uses_magazine):
				player.add_resource("bullets", 6, false)
				player.add_resource("parts", 1, false)
			else:
				player.add_resource("salvage", 2, false)
				player.add_resource("parts", 1, false)
		if player.has_method("play_feedback_sound"):
			player.play_feedback_sound(&"pickup_weapon", randf_range(0.98, 1.03), -3.0)
		collected.emit(self, player)
		queue_free()
		return

	if not player.add_resource(resource_id, amount):
		return

	if player.has_method("play_feedback_sound"):
		player.play_feedback_sound(&"pickup_resource", randf_range(0.98, 1.05), -4.0)
	collected.emit(self, player)
	queue_free()


func _sync_visuals() -> void:
	if is_weapon_drop and weapon_reward != null:
		label.text = "%s" % weapon_reward.display_name
		visual.color = Color(0.98, 0.78, 0.28, 1.0)
		visual.scale = Vector2(1.35, 1.35)
		return

	visual.scale = Vector2.ONE
	label.text = "%s +%d" % [resource_id.capitalize(), amount]

	match resource_id:
		"parts":
			visual.color = Color(0.88, 0.63, 0.29, 1.0)
		"medicine":
			visual.color = Color(0.44, 0.78, 0.86, 1.0)
		"bullets":
			visual.color = Color(0.93, 0.78, 0.42, 1.0)
		"food":
			visual.color = Color(0.84, 0.43, 0.28, 1.0)
		"battery":
			visual.color = Color(0.54, 0.86, 0.57, 1.0)
		_:
			visual.color = Color(0.91, 0.84, 0.39, 1.0)
