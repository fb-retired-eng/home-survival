extends Area2D
class_name SleepPoint

@export var interaction_label: String = "Sleep"


func get_interaction_label(_player) -> String:
	return interaction_label


func can_interact(_player) -> bool:
	return true


func interact(player) -> void:
	player.message_requested.emit("Sleep flow not implemented yet")
