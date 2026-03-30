extends Resource
class_name WeaponDefinition

@export var weapon_id: StringName = &"weapon"
@export var display_name: String = "Weapon"
@export var damage: int = 25
@export var damage_type: StringName = &"melee"
@export var energy_cost: int = 1
@export var attack_cooldown: float = 0.45
@export_range(0.0, 1.0, 0.01) var miss_recovery_time: float = 0.12
@export_range(0.0, 2.0, 0.05) var attack_windup: float = 0.0
@export var attack_area_size: Vector2 = Vector2(28, 18)
@export var attack_area_offset: Vector2 = Vector2(0, -24)
@export var held_visual_offset: Vector2 = Vector2(10, -10)
@export var held_visual_polygon: PackedVector2Array = PackedVector2Array([
	Vector2(-2, -10),
	Vector2(2, -10),
	Vector2(2, 8),
	Vector2(-2, 8),
])
@export var held_visual_color: Color = Color(0.86, 0.86, 0.9, 1.0)
@export_range(0.0, 1200.0, 10.0) var knockback_force: float = 0.0
@export var attack_flash_color: Color = Color(1.0, 0.83, 0.42, 0.75)
@export var attack_flash_start_scale: Vector2 = Vector2(0.8, 0.8)
@export var attack_flash_peak_scale: Vector2 = Vector2(1.1, 1.1)
@export_range(0.01, 1.0, 0.01) var attack_flash_duration: float = 0.08
@export var attack_indicator_windup_color: Color = Color(1.0, 0.9, 0.62, 0.22)
@export var attack_indicator_strike_color: Color = Color(1.0, 0.98, 0.88, 0.9)
@export var attack_indicator_windup_start_scale: Vector2 = Vector2(0.82, 0.82)
@export var attack_indicator_strike_peak_scale: Vector2 = Vector2(1.05, 1.05)
@export_range(0.0, 2.0, 0.05) var attack_indicator_lead_time: float = 0.12
@export_range(0.0, 1.0, 0.01) var attack_indicator_windup_start_alpha: float = 0.45
@export_range(0.0, 1.0, 0.01) var attack_indicator_windup_end_alpha: float = 1.0
@export_range(0.0, 1.0, 0.01) var attack_indicator_strike_alpha: float = 0.95
@export_range(0.01, 1.0, 0.01) var attack_indicator_strike_fade_duration: float = 0.10


func is_valid_definition() -> bool:
	if weapon_id == StringName():
		return false
	if display_name.is_empty():
		return false
	if damage < 0:
		return false
	if energy_cost < 0:
		return false
	if attack_cooldown < 0.0:
		return false
	if miss_recovery_time < 0.0:
		return false
	if attack_windup < 0.0:
		return false
	if attack_area_size.x <= 0.0 or attack_area_size.y <= 0.0:
		return false
	if held_visual_polygon.size() < 3:
		return false
	if knockback_force < 0.0:
		return false
	if attack_flash_start_scale.x <= 0.0 or attack_flash_start_scale.y <= 0.0:
		return false
	if attack_flash_peak_scale.x <= 0.0 or attack_flash_peak_scale.y <= 0.0:
		return false
	if attack_flash_duration <= 0.0:
		return false
	if attack_indicator_windup_start_scale.x <= 0.0 or attack_indicator_windup_start_scale.y <= 0.0:
		return false
	if attack_indicator_strike_peak_scale.x <= 0.0 or attack_indicator_strike_peak_scale.y <= 0.0:
		return false
	if attack_indicator_lead_time < 0.0:
		return false
	if attack_indicator_windup_start_alpha < 0.0 or attack_indicator_windup_start_alpha > 1.0:
		return false
	if attack_indicator_windup_end_alpha < 0.0 or attack_indicator_windup_end_alpha > 1.0:
		return false
	if attack_indicator_strike_alpha < 0.0 or attack_indicator_strike_alpha > 1.0:
		return false
	if attack_indicator_strike_fade_duration <= 0.0:
		return false

	return true
