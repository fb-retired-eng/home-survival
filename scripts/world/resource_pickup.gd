extends Area2D
class_name ResourcePickup

@export_enum("salvage", "parts", "medicine") var resource_id: String = "salvage"
@export var amount: int = 1

@onready var visual: Polygon2D = $Visual
@onready var label: Label = $Label


func _ready() -> void:
	add_to_group("pickups")
	_sync_visuals()


func collect(player) -> void:
	if player == null:
		return

	player.add_resource(resource_id, amount)
	queue_free()


func _sync_visuals() -> void:
	label.text = "%s +%d" % [resource_id.capitalize(), amount]

	match resource_id:
		"parts":
			visual.color = Color(0.88, 0.63, 0.29, 1.0)
		"medicine":
			visual.color = Color(0.44, 0.78, 0.86, 1.0)
		_:
			visual.color = Color(0.91, 0.84, 0.39, 1.0)
