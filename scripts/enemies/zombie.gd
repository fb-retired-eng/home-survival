extends CharacterBody2D
class_name Zombie

signal died(zombie: Zombie)

@export var enemy_id: StringName = &"zombie_basic"
@export var max_health: int = 50
@export var move_speed: float = 70.0
@export var contact_damage: int = 10
@export var contact_cooldown: float = 1.0

var current_health: int
var _damage_cooldown_remaining: float = 0.0
var _base_color: Color

@onready var body_visual: Polygon2D = $Body
@onready var damage_area: Area2D = $DamageArea


func _ready() -> void:
	current_health = max_health
	_base_color = body_visual.color


func _physics_process(delta: float) -> void:
	_damage_cooldown_remaining = max(_damage_cooldown_remaining - delta, 0.0)
	if _damage_cooldown_remaining > 0.0:
		return

	for body in damage_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(contact_damage, self)
			_damage_cooldown_remaining = contact_cooldown
			return


func take_damage(amount: int, _source: Variant = null) -> void:
	if amount <= 0:
		return

	current_health = max(current_health - amount, 0)
	_flash_body(Color(1.0, 0.55, 0.55, 1.0))

	if current_health == 0:
		died.emit(self)
		queue_free()


func _flash_body(flash_color: Color) -> void:
	body_visual.color = flash_color
	var tween := create_tween()
	tween.tween_property(body_visual, "color", _base_color, 0.12)
