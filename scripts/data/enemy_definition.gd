extends Resource
class_name EnemyDefinition

const DAMAGE_TYPE_MODIFIER_SCRIPT := preload("res://scripts/data/damage_type_modifier.gd")
const WEAPON_DEFINITION_SCRIPT := preload("res://scripts/data/weapon_definition.gd")

enum WaveTargetMode {
	SOCKET_THEN_PLAYER,
	PLAYER_THEN_SOCKET,
	SOCKET_ONLY,
	PLAYER_ONLY,
}

@export var enemy_id: StringName = &"enemy"
@export var body_color: Color = Color(0.39, 0.68, 0.38, 1.0)
@export var shadow_polygon: PackedVector2Array = PackedVector2Array([
	Vector2(-12.0, -6.0),
	Vector2(12.0, -6.0),
	Vector2(16.0, 0.0),
	Vector2(12.0, 6.0),
	Vector2(-12.0, 6.0),
	Vector2(-16.0, 0.0),
])
@export var body_polygon: PackedVector2Array = PackedVector2Array([
	Vector2(-10.0, -12.0),
	Vector2(10.0, -12.0),
	Vector2(12.0, 4.0),
	Vector2(0.0, 12.0),
	Vector2(-12.0, 4.0),
])
@export var facing_marker_polygon: PackedVector2Array = PackedVector2Array([
	Vector2(0.0, -18.0),
	Vector2(6.0, -6.0),
	Vector2(-6.0, -6.0),
])
@export var attack_flash_polygon: PackedVector2Array = PackedVector2Array([
	Vector2(-10.0, -26.0),
	Vector2(10.0, -26.0),
	Vector2(16.0, -8.0),
	Vector2(0.0, 6.0),
	Vector2(-16.0, -8.0),
])
@export var max_health: int = 50
@export var defense_flat_reduction: int = 0
@export_range(0.0, 4.0, 0.05) var defense_multiplier: float = 1.0
@export var damage_taken_modifiers: Array[Resource] = []
@export var move_speed: float = 70.0
@export var player_damage: int = 10
@export_range(0.0, 1200.0, 10.0) var player_knockback_force: float = 90.0
@export var structure_damage: int = 10
@export var structure_damage_type: StringName = &"impact"
@export_range(0.0, 240.0, 1.0) var attack_range_override: float = 0.0
@export_range(0.0, 240.0, 1.0) var structure_attack_range_override: float = 0.0
@export_range(0.0, 2.0, 0.05) var knockback_multiplier: float = 1.0
@export_range(0.0, 4000.0, 10.0) var knockback_decay: float = 900.0
@export var attack_interval: float = 1.0
@export_range(0.0, 2.0, 0.05) var attack_prep_time: float = 0.25
@export_enum("socket_then_player", "player_then_socket", "socket_only", "player_only") var wave_target_mode: int = WaveTargetMode.SOCKET_THEN_PLAYER
@export_enum("socket_then_player", "player_then_socket", "socket_only", "player_only") var exploration_target_mode: int = WaveTargetMode.PLAYER_ONLY
@export var chase_player_when_nearby: bool = true
@export var chase_overrides_target_mode: bool = false
@export var idle_until_player_detected: bool = false
@export var alert_nearby_enemies: bool = true
@export var ally_alert_radius: float = 84.0
@export_range(0.0, 12.0, 0.5) var noise_alert_weight: float = 1.0
@export var player_detection_radius: float = 88.0
@export var player_chase_break_radius: float = 128.0
@export var fallback_to_player_when_no_sockets: bool = true
@export var attack_player_when_obstructing: bool = true
@export var attack_player_on_contact: bool = true
@export var obstruction_width: float = 18.0
@export var separation_radius: float = 30.0
@export_range(0.0, 4.0, 0.05) var separation_weight: float = 1.0
@export_range(0.0, 4.0, 0.05) var sidestep_weight: float = 0.9
@export_range(-1.0, 1.0, 0.05) var detection_facing_dot_threshold: float = 0.0
@export_range(-1.0, 1.0, 0.05) var attack_facing_dot_threshold: float = 0.25
@export var presentation_scale: Vector2 = Vector2.ONE
@export_range(0.0, 8.0, 0.05) var visual_bob_height: float = 1.2
@export_range(0.0, 0.2, 0.001) var visual_breathe_scale: float = 0.016
@export_range(0.0, 40.0, 0.1) var visual_turn_speed: float = 10.0
@export_range(0.0, 0.2, 0.001) var visual_move_stretch_x: float = 0.03
@export_range(0.0, 0.2, 0.001) var visual_move_stretch_y: float = 0.022
@export var prep_pose_offset: Vector2 = Vector2.ZERO
@export var prep_pose_scale: Vector2 = Vector2.ONE
@export_range(-45.0, 45.0, 0.5) var prep_pose_tilt_degrees: float = 0.0
@export var attack_tell_color: Color = Color(1.0, 0.82, 0.42, 0.72)
@export var attack_tell_start_scale: Vector2 = Vector2(0.62, 0.62)
@export var attack_tell_ready_scale: Vector2 = Vector2(0.98, 0.98)
@export_range(0.0, 2.0, 0.05) var attack_tell_lead_time: float = 0.3
@export_range(0.0, 1.0, 0.01) var attack_tell_start_alpha: float = 0.18
@export_range(0.0, 1.0, 0.01) var attack_tell_ready_alpha: float = 0.72
@export var attack_strike_color: Color = Color(1.0, 0.98, 0.86, 0.98)
@export var attack_flash_start_scale: Vector2 = Vector2(0.78, 0.78)
@export var attack_flash_peak_scale: Vector2 = Vector2(1.08, 1.08)
@export_range(0.01, 1.0, 0.01) var attack_flash_duration: float = 0.08
@export_range(0.0, 16.0, 0.1) var damage_feedback_distance: float = 4.0
@export var damage_feedback_scale: Vector2 = Vector2(1.06, 0.94)
@export_range(0.01, 0.5, 0.01) var damage_feedback_duration: float = 0.12
@export var is_elite: bool = false
@export var drop_salvage: int = 1
@export var drop_parts: int = 0
@export var drop_bullets: int = 0
@export var drop_food: int = 0
@export var bonus_salvage: int = 1
@export_range(0.0, 1.0, 0.01) var bonus_salvage_chance: float = 0.2
@export var weapon_drop: Resource
@export_range(0.0, 1.0, 0.01) var weapon_drop_chance: float = 0.0


func is_valid_definition() -> bool:
	if enemy_id == StringName():
		return false
	if shadow_polygon.size() < 3:
		return false
	if body_polygon.size() < 3:
		return false
	if facing_marker_polygon.size() < 3:
		return false
	if attack_flash_polygon.size() < 3:
		return false
	if max_health <= 0:
		return false
	if move_speed < 0.0:
		return false
	if player_damage < 0 or structure_damage < 0:
		return false
	if attack_range_override < 0.0:
		return false
	if structure_attack_range_override < 0.0:
		return false
	if player_knockback_force < 0.0:
		return false
	if knockback_multiplier < 0.0:
		return false
	if knockback_decay < 0.0:
		return false
	if attack_interval <= 0.0:
		return false
	if attack_prep_time < 0.0:
		return false
	if wave_target_mode < WaveTargetMode.SOCKET_THEN_PLAYER or wave_target_mode > WaveTargetMode.PLAYER_ONLY:
		return false
	if exploration_target_mode < WaveTargetMode.SOCKET_THEN_PLAYER or exploration_target_mode > WaveTargetMode.PLAYER_ONLY:
		return false
	if ally_alert_radius < 0.0:
		return false
	if noise_alert_weight < 0.0:
		return false
	if player_detection_radius < 0.0:
		return false
	if player_chase_break_radius < player_detection_radius:
		return false
	if obstruction_width < 0.0:
		return false
	if separation_radius < 0.0:
		return false
	if separation_weight < 0.0 or sidestep_weight < 0.0:
		return false
	if detection_facing_dot_threshold < -1.0 or detection_facing_dot_threshold > 1.0:
		return false
	if attack_facing_dot_threshold < -1.0 or attack_facing_dot_threshold > 1.0:
		return false
	if presentation_scale.x <= 0.0 or presentation_scale.y <= 0.0:
		return false
	if visual_bob_height < 0.0:
		return false
	if visual_breathe_scale < 0.0:
		return false
	if visual_turn_speed < 0.0:
		return false
	if visual_move_stretch_x < 0.0 or visual_move_stretch_y < 0.0:
		return false
	if prep_pose_scale.x <= 0.0 or prep_pose_scale.y <= 0.0:
		return false
	if prep_pose_tilt_degrees < -45.0 or prep_pose_tilt_degrees > 45.0:
		return false
	if attack_tell_start_scale.x <= 0.0 or attack_tell_start_scale.y <= 0.0:
		return false
	if attack_tell_ready_scale.x <= 0.0 or attack_tell_ready_scale.y <= 0.0:
		return false
	if attack_tell_lead_time < 0.0:
		return false
	if attack_tell_start_alpha < 0.0 or attack_tell_start_alpha > 1.0:
		return false
	if attack_tell_ready_alpha < 0.0 or attack_tell_ready_alpha > 1.0:
		return false
	if attack_flash_start_scale.x <= 0.0 or attack_flash_start_scale.y <= 0.0:
		return false
	if attack_flash_peak_scale.x <= 0.0 or attack_flash_peak_scale.y <= 0.0:
		return false
	if attack_flash_duration <= 0.0:
		return false
	if damage_feedback_distance < 0.0:
		return false
	if damage_feedback_scale.x <= 0.0 or damage_feedback_scale.y <= 0.0:
		return false
	if damage_feedback_duration <= 0.0:
		return false
	if drop_parts < 0 or drop_bullets < 0 or drop_food < 0:
		return false
	if weapon_drop_chance < 0.0 or weapon_drop_chance > 1.0:
		return false
	if not is_elite and (weapon_drop != null or weapon_drop_chance > 0.0):
		return false
	if weapon_drop_chance > 0.0 and weapon_drop == null:
		return false
	if weapon_drop != null:
		if weapon_drop.get_script() != WEAPON_DEFINITION_SCRIPT and not weapon_drop.is_class("WeaponDefinition"):
			return false
		if not weapon_drop.has_method("is_valid_definition") or not weapon_drop.is_valid_definition():
			return false

	for modifier in damage_taken_modifiers:
		if modifier == null:
			return false
		if modifier.get_script() != DAMAGE_TYPE_MODIFIER_SCRIPT:
			return false

	return true


func compute_damage_taken(base_damage: int, damage_type: StringName = &"melee") -> int:
	if base_damage <= 0:
		return 0

	var flat_reduction: int = defense_flat_reduction
	var multiplier: float = defense_multiplier

	for modifier in damage_taken_modifiers:
		if modifier == null:
			continue
		if modifier.get_script() != DAMAGE_TYPE_MODIFIER_SCRIPT:
			continue
		if StringName(modifier.get("damage_type")) != damage_type:
			continue

		flat_reduction = int(modifier.get("flat_reduction"))
		multiplier = float(modifier.get("multiplier"))
		break

	var reduced_damage: int = max(base_damage - flat_reduction, 0)
	return max(int(round(reduced_damage * multiplier)), 0)
