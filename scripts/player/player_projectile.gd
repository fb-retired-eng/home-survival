extends Node2D
class_name PlayerProjectile

const IMPACT_DURATION := 0.08

@onready var visual: Polygon2D = $Visual
@onready var impact_flash: Polygon2D = $ImpactFlash

var _attacker = null
var _velocity: Vector2 = Vector2.ZERO
var _direction: Vector2 = Vector2.ZERO
var _remaining_distance: float = 0.0
var _hit_radius: float = 0.0
var _damage: int = 0
var _weapon_id: StringName = &"weapon"
var _damage_type: StringName = &"ballistic"
var _knockback_force: float = 0.0
var _impact_kind: String = "miss"
var _impact_color: Color = Color(1.0, 0.84, 0.54, 0.95)
var _is_impacting: bool = false


func _ready() -> void:
	add_to_group("player_projectiles")


func configure(config: Dictionary) -> void:
	_attacker = config.get("attacker")
	global_position = config.get("origin", global_position)
	_direction = config.get("direction", Vector2.UP)
	if _direction.is_zero_approx():
		_direction = Vector2.UP
	_direction = _direction.normalized()
	_velocity = _direction * maxf(float(config.get("speed", 1000.0)), 1.0)
	_remaining_distance = maxf(float(config.get("range", 0.0)), 0.0)
	_hit_radius = maxf(float(config.get("hit_radius", 0.0)), 0.0)
	_damage = int(config.get("damage", 0))
	_weapon_id = StringName(config.get("weapon_id", &"weapon"))
	_damage_type = StringName(config.get("damage_type", &"ballistic"))
	_knockback_force = float(config.get("knockback_force", 0.0))
	var projectile_polygon: PackedVector2Array = config.get("polygon", PackedVector2Array())
	var projectile_color: Color = config.get("color", Color(1.0, 0.94, 0.74, 0.98))
	_impact_color = config.get("impact_color", Color(1.0, 0.84, 0.54, 0.95))
	if projectile_polygon.size() >= 3:
		visual.polygon = projectile_polygon
		impact_flash.polygon = projectile_polygon
	visual.color = projectile_color
	impact_flash.color = _impact_color
	rotation = _direction.angle() + PI / 2.0
	impact_flash.visible = false
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _is_impacting:
		return
	var move_distance: float = minf(_velocity.length() * delta, _remaining_distance)
	var next_position: Vector2 = global_position + _direction * move_distance
	var hit := _intersect_segment(global_position, next_position)
	if not hit.is_empty():
		global_position = hit.get("position", next_position)
		_handle_hit(hit.get("collider"))
		return
	global_position = next_position
	_remaining_distance -= move_distance
	if _remaining_distance <= 0.001:
		_handle_hit(null)


func _intersect_segment(from_position: Vector2, to_position: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from_position, to_position)
	query.exclude = [self]
	query.collide_with_areas = false
	if _attacker != null and is_instance_valid(_attacker):
		query.exclude.append(_attacker)
	var world := get_world_2d()
	if world == null:
		return {}
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit
	if _hit_radius <= 0.0:
		return {}
	var shape := CircleShape2D.new()
	shape.radius = _hit_radius
	var shape_query := PhysicsShapeQueryParameters2D.new()
	shape_query.shape = shape
	shape_query.transform = Transform2D(0.0, to_position)
	shape_query.exclude = query.exclude
	shape_query.collide_with_areas = false
	for result in world.direct_space_state.intersect_shape(shape_query):
		var collider = result.get("collider")
		if collider == null or not is_instance_valid(collider):
			continue
		if collider.is_in_group("enemies"):
			return {
				"collider": collider,
				"position": to_position,
			}
	return {}


func _handle_hit(collider) -> void:
	if _is_impacting:
		return
	_is_impacting = true
	set_physics_process(false)
	if collider != null and is_instance_valid(collider) and collider.is_in_group("enemies") and collider.has_method("take_damage"):
		_impact_kind = "enemy"
		collider.take_damage(_damage, {
			"attacker": _attacker,
			"weapon_id": _weapon_id,
			"damage_amount": _damage,
			"damage_type": _damage_type,
			"knockback_force": _knockback_force,
			"knockback_direction": _direction,
			"interrupt_attack_prep": true,
		})
	elif collider != null and is_instance_valid(collider) and (collider.is_in_group("defense_sockets") or collider.is_in_group("placeables")):
		_impact_kind = "structure"
	if _attacker != null and is_instance_valid(_attacker) and _attacker.has_method("_play_combat_sound"):
		_attacker._play_combat_sound(
			_attacker._get_attack_impact_sound_id(_impact_kind),
			randf_range(0.98, 1.04),
			_attacker._get_attack_impact_volume(_impact_kind)
		)
		if _attacker.has_method("_play_shot_impact"):
			_attacker._play_shot_impact(global_position, _impact_kind)
	visual.visible = false
	impact_flash.visible = true
	impact_flash.scale = Vector2(0.72, 0.72)
	impact_flash.modulate = Color(_impact_color.r, _impact_color.g, _impact_color.b, 1.0)
	var tween := create_tween()
	tween.parallel().tween_property(impact_flash, "scale", Vector2.ONE, IMPACT_DURATION)
	tween.parallel().tween_property(impact_flash, "modulate:a", 0.0, IMPACT_DURATION)
	tween.finished.connect(queue_free)
