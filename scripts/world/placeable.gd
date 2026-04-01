extends Node2D
class_name Placeable

const PLACEABLE_PROFILE_SCRIPT := preload("res://scripts/data/placeable_profile.gd")

signal state_changed(placeable: Placeable)

@export var profile: Resource
@export var current_hp: int = 100
@export var placed_this_run: bool = true
@export var is_dismantled: bool = false

@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	_refresh_from_profile()


func _refresh_from_profile() -> void:
	if profile == null or profile.get_script() != PLACEABLE_PROFILE_SCRIPT:
		return
	current_hp = clamp(current_hp, 0, int(profile.max_hp))
	visual.color = profile.visual_color
	state_changed.emit(self)


func get_placeable_id() -> StringName:
	if profile == null or profile.get_script() != PLACEABLE_PROFILE_SCRIPT:
		return StringName()
	return StringName(profile.placeable_id)


func get_display_name() -> String:
	if profile == null or profile.get_script() != PLACEABLE_PROFILE_SCRIPT:
		return "Placeable"
	return String(profile.display_name)


func get_build_cost() -> Dictionary:
	if profile == null or profile.get_script() != PLACEABLE_PROFILE_SCRIPT:
		return {}
	return profile.build_cost.duplicate(true)


func get_repair_cost() -> Dictionary:
	if profile == null or profile.get_script() != PLACEABLE_PROFILE_SCRIPT:
		return {}
	return profile.repair_cost.duplicate(true)
