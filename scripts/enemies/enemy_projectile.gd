extends Node2D
class_name EnemyProjectile

const IMPACT_DURATION := 0.12

@onready var shadow: Polygon2D = $Shadow
@onready var visual: Polygon2D = $Visual
@onready var impact_flash: Polygon2D = $ImpactFlash
@onready var combat_audio = $CombatAudio

var _attacker = null
var _target = null
var _velocity: Vector2 = Vector2.ZERO
var _remaining_distance: float = 0.0
var _damage: int = 0
var _damage_type: StringName = &"impact"
var _knockback_force: float = 0.0
var _hit_radius: float = 10.0
var _source_direction: Vector2 = Vector2.ZERO
var _is_impacting: bool = false


func _ready() -> void:
	add_to_group("enemy_projectiles")


func configure(config: Dictionary) -> void:
	_attacker = config.get("attacker")
	_target = config.get("target")
	global_position = config.get("origin", global_position)
	var destination: Vector2 = config.get("destination", global_position)
	_damage = int(config.get("damage", 0))
	_damage_type = StringName(config.get("damage_type", &"impact"))
	_knockback_force = float(config.get("knockback_force", 0.0))
	_hit_radius = maxf(float(config.get("hit_radius", 10.0)), 0.0)
	var color: Color = config.get("color", Color(0.72, 0.98, 0.56, 0.96))
	var impact_color: Color = config.get("impact_color", Color(0.9, 1.0, 0.86, 0.92))
	var polygon: PackedVector2Array = config.get("polygon", PackedVector2Array())
	var speed: float = maxf(float(config.get("speed", 220.0)), 1.0)
	if polygon.size() >= 3:
		visual.polygon = polygon
		impact_flash.polygon = polygon
		shadow.polygon = polygon
	visual.color = color
	impact_flash.color = impact_color
	var offset: Vector2 = destination - global_position
	if offset.is_zero_approx():
		offset = Vector2.RIGHT
	_source_direction = offset.normalized()
	_velocity = _source_direction * speed
	_remaining_distance = offset.length()
	rotation = _source_direction.angle() + PI / 2.0
	shadow.rotation = 0.0
	visual.rotation = 0.0
	impact_flash.rotation = 0.0
	impact_flash.visible = false
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _is_impacting:
		return
	var move_distance: float = minf(_velocity.length() * delta, _remaining_distance)
	var next_position: Vector2 = global_position + _source_direction * move_distance
	if _is_target_within_hit_radius(next_position):
		global_position = next_position
		_handle_hit(_target)
		return
	var hit := _intersect_segment(global_position, next_position)
	if not hit.is_empty():
		_handle_hit(hit.get("collider"))
		return
	global_position = next_position
	_remaining_distance -= move_distance
	if _remaining_distance <= 0.001:
		_handle_hit(_target)


func _intersect_segment(from_position: Vector2, to_position: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from_position, to_position)
	query.exclude = [self]
	query.collide_with_areas = false
	if _attacker != null and is_instance_valid(_attacker):
		query.exclude.append(_attacker)
	var world := get_world_2d()
	if world == null:
		return {}
	return world.direct_space_state.intersect_ray(query)


func _handle_hit(collider) -> void:
	if _is_impacting:
		return
	_is_impacting = true
	set_physics_process(false)
	if collider != null and is_instance_valid(collider) and _can_damage_target(collider):
		collider.take_damage(_damage, {
			"attacker": _attacker,
			"damage_type": _damage_type,
			"knockback_force": _knockback_force,
			"knockback_direction": _source_direction,
		})
	combat_audio.play_sound(&"enemy_attack_hit", randf_range(0.97, 1.04), -2.0)
	shadow.visible = false
	visual.visible = false
	impact_flash.visible = true
	impact_flash.scale = Vector2(0.72, 0.72)
	var tween := create_tween()
	tween.parallel().tween_property(impact_flash, "scale", Vector2(1.18, 1.18), IMPACT_DURATION)
	tween.parallel().tween_property(impact_flash, "modulate:a", 0.0, IMPACT_DURATION)
	tween.finished.connect(queue_free)


func _is_target_within_hit_radius(position: Vector2) -> bool:
	if _hit_radius <= 0.0:
		return false
	if _target == null or not is_instance_valid(_target):
		return false
	if not (_target is Node2D):
		return false
	return position.distance_to(_target.global_position) <= _hit_radius


func _can_damage_target(collider) -> bool:
	if collider == null or not is_instance_valid(collider):
		return false
	if _target != null and is_instance_valid(_target) and collider == _target:
		return true
	if collider.is_in_group("player"):
		return true
	if collider.is_in_group("placeables") or collider.is_in_group("defense_sockets"):
		return true
	return false
