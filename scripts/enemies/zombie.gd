extends CharacterBody2D
class_name Zombie

const EnemyDefinitionResource = preload("res://scripts/data/enemy_definition.gd")
const ResourcePickupScene = preload("res://scenes/world/ResourcePickup.tscn")

signal died(zombie: Zombie)

@export var definition: EnemyDefinitionResource
@export var enemy_id: StringName = &"zombie_basic"
@export var max_health: int = 50
@export var defense_flat_reduction: int = 0
@export_range(0.0, 4.0, 0.05) var defense_multiplier: float = 1.0
@export var move_speed: float = 70.0
@export var player_damage: int = 10
@export var structure_damage: int = 10
@export var structure_damage_type: StringName = &"impact"
@export var attack_cooldown: float = 1.0

var current_health: int
var _damage_cooldown_remaining: float = 0.0
var _base_color: Color
var _behavior_context: StringName = &"exploration"
var _wave_player
var _wave_sockets: Array = []
var _player_obstructing_this_frame: bool = false
var _preferred_socket_ids: PackedStringArray = []

@onready var body_visual: Polygon2D = $Body
@onready var damage_area: Area2D = $DamageArea


func _ready() -> void:
	add_to_group("enemies")
	_apply_definition()
	current_health = max_health
	_base_color = body_visual.color


func configure_wave_context(player_ref, defense_sockets: Array, preferred_socket_ids: PackedStringArray = PackedStringArray()) -> void:
	_behavior_context = &"wave"
	_wave_player = player_ref
	_wave_sockets = defense_sockets.duplicate()
	_preferred_socket_ids = preferred_socket_ids


func _physics_process(delta: float) -> void:
	_damage_cooldown_remaining = max(_damage_cooldown_remaining - delta, 0.0)
	var primary_target = _get_current_target()
	_player_obstructing_this_frame = false
	if primary_target != null and is_instance_valid(primary_target) and not _is_target_in_damage_range(primary_target):
		var target_offset: Vector2 = primary_target.global_position - global_position
		velocity = target_offset.normalized() * move_speed if not target_offset.is_zero_approx() else Vector2.ZERO
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	_player_obstructing_this_frame = _is_player_obstructing(primary_target)

	if _damage_cooldown_remaining > 0.0:
		return

	var attack_target = _get_attack_target(primary_target)
	if _try_damage_target(attack_target):
		_damage_cooldown_remaining = attack_cooldown


func take_damage(amount: int, _source: Variant = null) -> void:
	if amount <= 0:
		return

	var damage_amount := _resolve_damage_taken(amount, _source)
	if damage_amount <= 0:
		return

	current_health = max(current_health - damage_amount, 0)
	_flash_body(Color(1.0, 0.55, 0.55, 1.0))

	if current_health == 0:
		_spawn_death_drop()
		died.emit(self)
		queue_free()


func _get_current_target():
	if _behavior_context == &"wave":
		var socket = _get_closest_intact_socket()
		if socket != null:
			return socket

	if _wave_player != null and is_instance_valid(_wave_player) and not _wave_player.is_dead:
		return _wave_player

	return null


func _get_attack_target(primary_target):
	if primary_target == null:
		return null

	if _behavior_context == &"wave":
		if _player_obstructing_this_frame and _wave_player != null and is_instance_valid(_wave_player):
			return _wave_player

	return primary_target


func _get_closest_intact_socket():
	var preferred_sockets := _get_intact_preferred_sockets()
	if not preferred_sockets.is_empty():
		return _get_closest_socket_from_list(preferred_sockets)

	return _get_closest_socket_from_list(_wave_sockets)


func _get_intact_preferred_sockets() -> Array:
	var preferred_sockets: Array = []
	if _preferred_socket_ids.is_empty():
		return preferred_sockets

	for socket in _wave_sockets:
		if not is_instance_valid(socket):
			continue

		if not socket.is_in_group("defense_sockets"):
			continue

		if not _preferred_socket_ids.has(String(socket.socket_id)):
			continue

		if socket.has_method("is_breached") and socket.is_breached():
			continue

		preferred_sockets.append(socket)

	return preferred_sockets


func _get_closest_socket_from_list(socket_list: Array):
	var closest_socket = null
	var best_distance := INF

	for socket in socket_list:
		if not is_instance_valid(socket):
			continue

		if not socket.is_in_group("defense_sockets"):
			continue

		if socket.has_method("is_breached") and socket.is_breached():
			continue

		var distance := global_position.distance_squared_to(socket.global_position)
		if distance < best_distance:
			best_distance = distance
			closest_socket = socket

	return closest_socket


func _is_target_in_damage_range(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	if target is PhysicsBody2D:
		return damage_area.overlaps_body(target)

	if target is Area2D:
		return damage_area.overlaps_area(target)

	return false


func _try_damage_target(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	if not target.has_method("take_damage"):
		return false

	if not _is_target_in_damage_range(target):
		return false

	var damage_amount := _get_damage_amount_for_target(target)
	if target.is_in_group("defense_sockets"):
		target.take_damage(damage_amount, {
			"attacker": self,
			"damage_type": structure_damage_type,
		})
	else:
		target.take_damage(damage_amount, self)
	return true


func _is_player_obstructing(primary_target) -> bool:
	if _wave_player == null or not is_instance_valid(_wave_player) or _wave_player.is_dead:
		return false

	if primary_target == _wave_player:
		return true

	if not _is_target_in_damage_range(_wave_player):
		return false

	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		if collision == null:
			continue

		if collision.get_collider() == _wave_player:
			return true

	return _is_player_between_target(primary_target)


func _get_damage_amount_for_target(target) -> int:
	if target != null and target.is_in_group("player"):
		return player_damage

	return structure_damage


func _apply_definition() -> void:
	if definition == null:
		return

	enemy_id = definition.enemy_id
	max_health = definition.max_health
	defense_flat_reduction = definition.defense_flat_reduction
	defense_multiplier = definition.defense_multiplier
	move_speed = definition.move_speed
	player_damage = definition.player_damage
	structure_damage = definition.structure_damage
	structure_damage_type = definition.structure_damage_type
	attack_cooldown = definition.attack_interval


func _resolve_damage_taken(base_damage: int, source: Variant) -> int:
	var damage_type := StringName(&"melee")
	if source is Dictionary:
		damage_type = StringName(source.get("damage_type", &"melee"))

	if definition != null:
		return int(definition.compute_damage_taken(base_damage, damage_type))

	var reduced_damage: int = max(base_damage - defense_flat_reduction, 0)
	return max(int(round(reduced_damage * defense_multiplier)), 0)


func _is_player_between_target(primary_target) -> bool:
	if primary_target == null or not is_instance_valid(primary_target):
		return false

	var target_vector: Vector2 = primary_target.global_position - global_position
	var player_vector: Vector2 = _wave_player.global_position - global_position
	var target_length := target_vector.length()
	if target_length <= 0.001:
		return false

	var target_direction := target_vector / target_length
	var projection := player_vector.dot(target_direction)
	if projection < 0.0 or projection > target_length:
		return false

	var closest_point := global_position + target_direction * projection
	if closest_point.distance_to(_wave_player.global_position) > 18.0:
		return false

	return _has_clear_line_to_player()


func _has_clear_line_to_player() -> bool:
	if _wave_player == null or not is_instance_valid(_wave_player):
		return false

	var query := PhysicsRayQueryParameters2D.create(global_position, _wave_player.global_position)
	query.exclude = [self]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true

	return hit.get("collider") == _wave_player


func _spawn_death_drop() -> void:
	if definition == null or definition.drop_salvage <= 0:
		return

	var drop_parent: Node = get_parent()
	var world_node := get_tree().current_scene.get_node_or_null("World")
	if world_node != null:
		drop_parent = world_node

	if drop_parent == null:
		return

	var pickup = ResourcePickupScene.instantiate()
	var salvage_amount := definition.drop_salvage
	if definition.bonus_salvage > 0 and randf() < definition.bonus_salvage_chance:
		salvage_amount += definition.bonus_salvage

	pickup.resource_id = "salvage"
	pickup.amount = salvage_amount
	drop_parent.add_child(pickup)
	pickup.global_position = global_position


func _flash_body(flash_color: Color) -> void:
	body_visual.color = flash_color
	var tween := create_tween()
	tween.tween_property(body_visual, "color", _base_color, 0.12)
