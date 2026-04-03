extends Resource
class_name WeaponDefinition

@export var weapon_id: StringName = &"weapon"
@export var display_name: String = "Weapon"
@export var hud_trait_text: String = ""
@export var damage: int = 25
@export var damage_type: StringName = &"melee"
@export_enum("melee", "hitscan", "spread_hitscan") var attack_mode: String = "melee"
@export_range(0.0, 600.0, 5.0) var noise_radius: float = 0.0
@export_range(0.0, 12.0, 0.5) var noise_alert_budget: float = 0.0
@export var energy_cost: int = 1
@export var attack_cooldown: float = 0.45
@export var uses_magazine: bool = false
@export_range(1, 24, 1) var magazine_size: int = 6
@export_range(0.0, 3.0, 0.05) var reload_time: float = 1.0
@export_range(0.0, 1.0, 0.01) var miss_recovery_time: float = 0.12
@export_range(0.0, 2.0, 0.05) var attack_windup: float = 0.0
@export_range(0.0, 600.0, 5.0) var attack_range: float = 0.0
@export_range(0.0, 180.0, 1.0) var attack_cone_degrees: float = 0.0
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
@export_range(0, 50, 1) var isolated_bonus_damage: int = 0
@export var interrupt_attack_prep: bool = false
@export_range(0, 50, 1) var cluster_bonus_damage: int = 0
@export_range(0, 50, 1) var close_range_bonus_damage: int = 0
@export_range(0.0, 600.0, 5.0) var close_range_bonus_distance: float = 0.0
@export var attack_flash_color: Color = Color(1.0, 0.83, 0.42, 0.75)
@export var attack_flash_start_scale: Vector2 = Vector2(0.8, 0.8)
@export var attack_flash_peak_scale: Vector2 = Vector2(1.1, 1.1)
@export_range(0.01, 1.0, 0.01) var attack_flash_duration: float = 0.08
@export var muzzle_flash_color: Color = Color(1.0, 0.87, 0.55, 0.95)
@export var muzzle_flash_scale: Vector2 = Vector2(1.0, 1.0)
@export_range(0.01, 1.0, 0.01) var muzzle_flash_duration: float = 0.05
@export var uses_projectile: bool = false
@export_range(0.0, 2400.0, 10.0) var projectile_speed: float = 1000.0
@export_range(0.0, 64.0, 1.0) var projectile_hit_radius: float = 6.0
@export var projectile_polygon: PackedVector2Array = PackedVector2Array([
	Vector2(-2.0, -6.0),
	Vector2(2.0, -6.0),
	Vector2(3.0, 0.0),
	Vector2(0.0, 6.0),
	Vector2(-3.0, 0.0),
])
@export var projectile_color: Color = Color(1.0, 0.94, 0.74, 0.98)
@export var projectile_impact_color: Color = Color(1.0, 0.84, 0.54, 0.95)
@export var tracer_color: Color = Color(1.0, 0.95, 0.78, 0.9)
@export_range(1.0, 16.0, 0.5) var tracer_width: float = 2.0
@export_range(0.01, 1.0, 0.01) var tracer_duration: float = 0.05
@export var impact_hit_color: Color = Color(1.0, 0.84, 0.54, 0.95)
@export var impact_block_color: Color = Color(0.95, 0.94, 0.88, 0.88)
@export_range(0.2, 3.0, 0.05) var impact_flash_scale: float = 1.0
@export_range(0.01, 1.0, 0.01) var impact_flash_duration: float = 0.07
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
	if isolated_bonus_damage < 0 or cluster_bonus_damage < 0 or close_range_bonus_damage < 0:
		return false
	if close_range_bonus_distance < 0.0:
		return false
	if attack_mode != "melee" and attack_mode != "hitscan" and attack_mode != "spread_hitscan":
		return false
	if noise_radius < 0.0 or noise_alert_budget < 0.0:
		return false
	if energy_cost < 0:
		return false
	if attack_cooldown < 0.0:
		return false
	if uses_magazine and magazine_size <= 0:
		return false
	if uses_magazine and reload_time <= 0.0:
		return false
	if miss_recovery_time < 0.0:
		return false
	if attack_windup < 0.0:
		return false
	if (attack_mode == "hitscan" or attack_mode == "spread_hitscan") and attack_range <= 0.0:
		return false
	if attack_mode == "spread_hitscan" and attack_cone_degrees <= 0.0:
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
	if muzzle_flash_scale.x <= 0.0 or muzzle_flash_scale.y <= 0.0:
		return false
	if muzzle_flash_duration <= 0.0:
		return false
	if projectile_speed < 0.0:
		return false
	if projectile_hit_radius < 0.0:
		return false
	if uses_projectile and projectile_polygon.size() < 3:
		return false
	if tracer_width <= 0.0:
		return false
	if tracer_duration <= 0.0:
		return false
	if impact_flash_scale <= 0.0:
		return false
	if impact_flash_duration <= 0.0:
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
