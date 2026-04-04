extends Area2D
class_name GeneratorPoint

signal upgrade_requested(player)

@export var interaction_label: String = "Upgrade Generator"

var _availability_callback: Callable
var _label_callback: Callable


func configure(availability_callback: Callable, label_callback: Callable) -> void:
	_availability_callback = availability_callback
	_label_callback = label_callback


func get_interaction_label(player) -> String:
	if _label_callback.is_valid():
		return str(_label_callback.call(player))
	return interaction_label


func can_interact(player) -> bool:
	if _availability_callback.is_valid():
		return bool(_availability_callback.call(player))
	return true


func get_interaction_priority(_player) -> int:
	return 97


func interact(player) -> void:
	if not can_interact(player):
		return
	upgrade_requested.emit(player)
