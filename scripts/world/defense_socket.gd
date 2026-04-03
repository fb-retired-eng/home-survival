extends StaticBody2D
class_name DefenseSocket

const WALL_BLOCKER_LAYER := 2
const DOOR_BLOCKER_LAYER := 4
const STRUCTURE_PROFILE_SCRIPT := preload("res://scripts/data/structure_profile.gd")
const GAMEPLAY_Z_BASE := 1000

signal state_changed(socket: DefenseSocket)

@export var socket_id: StringName
@export_enum("wall", "door") var socket_type: String = "wall"
@export_enum("damaged", "reinforced", "fortified") var tier: String = "damaged"
@export var current_hp: int = 90
@export var max_hp: int = 90
@export var structure_profile: Resource
@export var socket_size: Vector2 = Vector2(48, 16)
@export var interaction_area_offset: Vector2 = Vector2.ZERO
@export var interaction_area_size: Vector2 = Vector2(48, 24)
@export var show_label: bool = false

@onready var visual: Polygon2D = $Visual
@onready var label: Label = $Label
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var interaction_shape: CollisionShape2D = $InteractionArea/CollisionShape2D
@onready var combat_audio = $CombatAudio

var _initial_tier: String = "damaged"
var _initial_hp: int = 90
var _context_label_visible: bool = false
var _damage_feedback_tween: Tween


func _ready() -> void:
	add_to_group("defense_sockets")
	if collision_shape.shape != null:
		collision_shape.shape = collision_shape.shape.duplicate()
	if interaction_shape.shape != null:
		interaction_shape.shape = interaction_shape.shape.duplicate()
	_initial_tier = tier
	max_hp = _get_max_hp_for_tier(tier)
	_initial_hp = clamp(current_hp, 0, max_hp)
	current_hp = clamp(current_hp, 0, max_hp)
	z_as_relative = false
	z_index = GAMEPLAY_Z_BASE + int(round(global_position.y))
	_refresh_visuals()


func get_interaction_label(player) -> String:
	if not _has_structure_profile():
		return ""

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
		"fortify":
			var fortify_cost := _get_fortify_cost()
			if player != null and not player.has_resources(fortify_cost):
				return "Fortify (need %s)" % _format_cost(fortify_cost)
			return "Fortify (%s)" % _format_cost(fortify_cost)
		_:
			return ""


func can_interact(_player) -> bool:
	if not _has_structure_profile():
		return false
	return _get_available_action() != ""


func get_interaction_priority(_player) -> int:
	if _has_structure_profile():
		return int(structure_profile.interaction_priority)
	return 10


func is_direct_interactable() -> bool:
	return false


func set_context_label_visible(visible: bool) -> void:
	if _context_label_visible == visible:
		return

	_context_label_visible = visible
	label.visible = show_label or _context_label_visible


func interact(player) -> void:
	if not _has_structure_profile():
		player.message_requested.emit("Socket config missing")
		return

	var action := _get_available_action()
	if action.is_empty():
		return

	if action == "repair":
		var repair_cost := _get_repair_cost()
		if not player.spend_resources(repair_cost):
			player.message_requested.emit("Not enough resources")
			return
		current_hp = _get_max_hp_for_tier(tier)
		if player != null and player.has_method("play_feedback_sound"):
			player.play_feedback_sound(&"build_repair", randf_range(0.98, 1.04), -3.0)
		player.message_requested.emit("Base repaired")
	elif action == "strengthen":
		var strengthen_cost := _get_strengthen_cost()
		if not player.spend_resources(strengthen_cost):
			player.message_requested.emit("Not enough resources")
			return
		tier = "reinforced"
		max_hp = _get_max_hp_for_tier(tier)
		current_hp = max_hp
		if player != null and player.has_method("play_feedback_sound"):
			player.play_feedback_sound(&"build_upgrade", randf_range(0.98, 1.03), -2.5)
		player.message_requested.emit("Base strengthened")
	elif action == "fortify":
		var fortify_cost := _get_fortify_cost()
		if not player.spend_resources(fortify_cost):
			player.message_requested.emit("Not enough resources")
			return
		tier = "fortified"
		max_hp = _get_max_hp_for_tier(tier)
		current_hp = max_hp
		if player != null and player.has_method("play_feedback_sound"):
			player.play_feedback_sound(&"build_upgrade", randf_range(0.94, 0.99), -2.0)
		player.message_requested.emit("Base fortified")

	_refresh_visuals()


func take_damage(amount: int, _source: Variant = null) -> void:
	if amount <= 0:
		return

	var damage_amount := _resolve_damage_taken(amount, _source)
	if damage_amount <= 0:
		return

	current_hp = max(current_hp - damage_amount, 0)
	_refresh_visuals()
	_flash_damage_feedback()
	_play_combat_sound(&"structure_hit", randf_range(0.95, 1.02), -3.5)


func is_breached() -> bool:
	return current_hp <= 0


func get_attack_aim_point(from_position: Vector2) -> Vector2:
	var half_size := socket_size * 0.5
	var clamped_point := Vector2(
		clampf(from_position.x, global_position.x - half_size.x, global_position.x + half_size.x),
		clampf(from_position.y, global_position.y - half_size.y, global_position.y + half_size.y)
	)
	var to_center := global_position - clamped_point
	if to_center.is_zero_approx():
		return clamped_point

	var inset_distance: float = min(2.0, min(half_size.x, half_size.y) * 0.25)
	return clamped_point + to_center.normalized() * inset_distance


func reset_for_new_run() -> void:
	tier = _initial_tier
	max_hp = _get_max_hp_for_tier(tier)
	current_hp = clamp(_initial_hp, 0, max_hp)
	_refresh_visuals()


func get_save_state() -> Dictionary:
	return {
		"socket_id": String(socket_id),
		"socket_type": socket_type,
		"tier": tier,
		"current_hp": current_hp,
	}


func apply_save_state(save_state: Dictionary) -> void:
	var saved_tier := String(save_state.get("tier", tier))
	if saved_tier != "damaged" and saved_tier != "reinforced" and saved_tier != "fortified":
		saved_tier = _initial_tier
	tier = saved_tier
	max_hp = _get_max_hp_for_tier(tier)
	current_hp = clampi(int(save_state.get("current_hp", max_hp)), 0, max_hp)
	_refresh_visuals()


func _get_available_action() -> String:
	if not _has_structure_profile():
		return ""

	if tier == "damaged":
		if current_hp < _get_max_hp_for_tier("damaged"):
			return "repair"
		return "strengthen"

	if tier == "reinforced" and current_hp < _get_max_hp_for_tier("reinforced"):
		return "repair"
	if tier == "reinforced":
		return "fortify"

	if tier == "fortified" and current_hp < _get_max_hp_for_tier("fortified"):
		return "repair"

	return ""


func _get_max_hp_for_tier(target_tier: String) -> int:
	if _has_structure_profile():
		return int(structure_profile.get_max_hp_for_tier(target_tier))
	push_warning("DefenseSocket %s is missing structure_profile for max HP lookup" % socket_id)
	return max_hp


func _get_repair_cost() -> Dictionary:
	if _has_structure_profile():
		return structure_profile.get_repair_cost(tier)
	push_warning("DefenseSocket %s is missing structure_profile for repair cost lookup" % socket_id)
	return {}


func _get_strengthen_cost() -> Dictionary:
	if _has_structure_profile():
		return structure_profile.get_strengthen_cost()
	push_warning("DefenseSocket %s is missing structure_profile for strengthen cost lookup" % socket_id)
	return {}


func _get_fortify_cost() -> Dictionary:
	if _has_structure_profile():
		return structure_profile.get_fortify_cost()
	push_warning("DefenseSocket %s is missing structure_profile for fortify cost lookup" % socket_id)
	return {}


func _format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in ["salvage", "parts", "medicine", "food", "bullets"]:
		var amount := int(cost.get(resource_id, 0))
		if amount <= 0:
			continue
		parts.append("%d %s" % [amount, resource_id.capitalize()])
	return ", ".join(parts)


func _refresh_visuals() -> void:
	var target_max_hp := _get_max_hp_for_tier(tier)
	max_hp = target_max_hp
	current_hp = clamp(current_hp, 0, max_hp)
	collision_shape.disabled = current_hp <= 0
	collision_layer = _get_collision_layer_for_state()
	_apply_socket_geometry()

	visual.color = _get_visual_color()

	label.text = "%s %d/%d" % [socket_id, current_hp, max_hp]
	label.visible = show_label or _context_label_visible
	state_changed.emit(self)


func _apply_socket_geometry() -> void:
	var half_size := socket_size * 0.5
	var rectangle_shape := collision_shape.shape as RectangleShape2D
	if rectangle_shape != null:
		rectangle_shape.size = socket_size

	var interaction_rectangle := interaction_shape.shape as RectangleShape2D
	if interaction_rectangle != null:
		interaction_rectangle.size = interaction_area_size
	interaction_area.position = interaction_area_offset

	visual.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])
	_apply_label_layout(half_size)


func _apply_label_layout(half_size: Vector2) -> void:
	var label_width: float = max(socket_size.x + 48.0, 120.0)
	var label_height: float = 24.0
	var margin: float = 10.0

	if socket_size.x >= socket_size.y:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.offset_left = -label_width * 0.5
		label.offset_right = label.offset_left + label_width
		if global_position.y <= 360.0:
			label.offset_top = -half_size.y - label_height - margin
		else:
			label.offset_top = half_size.y + margin
		label.offset_bottom = label.offset_top + label_height
		return

	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if global_position.x <= 640.0:
		label.offset_left = half_size.x + margin
	else:
		label.offset_left = -label_width - half_size.x - margin
	label.offset_top = -label_height * 0.5
	label.offset_right = label.offset_left + label_width
	label.offset_bottom = label.offset_top + label_height


func _get_collision_layer_for_state() -> int:
	if current_hp <= 0:
		return 0

	if socket_type == "door":
		return DOOR_BLOCKER_LAYER
	
	return WALL_BLOCKER_LAYER


func _resolve_damage_taken(base_damage: int, source: Variant) -> int:
	var damage_type := StringName(&"impact")
	if source is Dictionary:
		damage_type = StringName(source.get("damage_type", &"impact"))

	if _has_structure_profile():
		return int(structure_profile.compute_damage_taken(base_damage, damage_type, tier))

	return base_damage


func _has_structure_profile() -> bool:
	return structure_profile != null and structure_profile.get_script() == STRUCTURE_PROFILE_SCRIPT


func _get_visual_color() -> Color:
	if not _has_structure_profile():
		return Color(0.57, 0.45, 0.35, 1.0)

	if current_hp <= 0:
		return structure_profile.breached_color

	if tier == "fortified":
		return structure_profile.fortified_color

	if tier == "reinforced":
		return structure_profile.reinforced_color

	return structure_profile.damaged_color


func _flash_damage_feedback() -> void:
	if current_hp <= 0:
		return

	var settled_color := visual.color
	visual.color = Color(1.0, 0.56, 0.42, 1.0)
	if _damage_feedback_tween != null and is_instance_valid(_damage_feedback_tween):
		_damage_feedback_tween.kill()

	var pulse_scale := Vector2(1.08, 1.08)
	if socket_size.x >= socket_size.y:
		pulse_scale = Vector2(1.02, 1.16)
	else:
		pulse_scale = Vector2(1.16, 1.02)

	visual.scale = pulse_scale
	visual.position = Vector2.ZERO
	_damage_feedback_tween = create_tween()
	_damage_feedback_tween.parallel().tween_property(visual, "color", settled_color, 0.16)
	_damage_feedback_tween.parallel().tween_property(visual, "scale", Vector2.ONE, 0.16)


func _play_combat_sound(sound_id: StringName, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	if combat_audio != null and is_instance_valid(combat_audio) and combat_audio.has_method("play_sound"):
		combat_audio.play_sound(sound_id, pitch_scale, volume_db)
