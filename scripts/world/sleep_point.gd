extends Area2D
class_name SleepPoint

signal sleep_requested(player)

@export var interaction_label: String = "Sleep"

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


func interact(player) -> void:
	if not can_interact(player):
		return
	sleep_requested.emit(player)
