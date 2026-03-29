extends CharacterBody2D
class_name Player

signal health_changed(current: int, maximum: int)
signal energy_changed(current: int, maximum: int)
signal resources_changed(resources: Dictionary)
signal message_requested(text: String)
signal player_died()

@export var max_health: int = 100
@export var max_energy: int = 100
@export var move_speed: float = 180.0
@export var melee_damage: int = 25
@export var melee_energy_cost: int = 5
@export var melee_cooldown: float = 0.45

var current_health: int
var current_energy: int
var resources: Dictionary = {
	"salvage": 0,
	"parts": 0,
	"medicine": 0,
}

var is_dead: bool = false
var facing_direction: Vector2 = Vector2.UP
var attack_cooldown_remaining: float = 0.0
var _base_body_color: Color

@onready var body_visual: Polygon2D = $Body
@onready var facing_marker: Polygon2D = $FacingMarker
@onready var attack_pivot: Node2D = $AttackPivot
@onready var attack_area: Area2D = $AttackPivot/AttackArea
@onready var pickup_detector: Area2D = $PickupDetector


func _ready() -> void:
	current_health = max_health
	current_energy = max_energy
	_base_body_color = body_visual.color
	pickup_detector.area_entered.connect(_on_pickup_detector_area_entered)
	_emit_full_state()


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	attack_cooldown_remaining = max(attack_cooldown_remaining - delta, 0.0)
	_handle_movement()
	move_and_slide()

	if Input.is_action_just_pressed("attack"):
		_attempt_attack()

	if Input.is_action_just_pressed("use_medicine"):
		_attempt_use_medicine()


func add_resource(resource_id: String, amount: int) -> void:
	if amount == 0:
		return

	var current_amount: int = int(resources.get(resource_id, 0))
	resources[resource_id] = max(current_amount + amount, 0)
	resources_changed.emit(resources.duplicate(true))
	message_requested.emit("%s +%d" % [resource_id.capitalize(), amount])


func take_damage(amount: int, _source: Variant = null) -> void:
	if is_dead or amount <= 0:
		return

	current_health = max(current_health - amount, 0)
	health_changed.emit(current_health, max_health)
	_flash_body(Color(1.0, 0.45, 0.45, 1.0))

	if current_health == 0:
		_die()


func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return

	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)
	_flash_body(Color(0.52, 0.87, 0.62, 1.0))


func _handle_movement() -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_vector * move_speed

	if input_vector.is_zero_approx():
		return

	facing_direction = input_vector.normalized()
	attack_pivot.rotation = facing_direction.angle() + PI / 2.0
	facing_marker.rotation = attack_pivot.rotation


func _attempt_attack() -> void:
	if attack_cooldown_remaining > 0.0:
		return

	if current_energy < melee_energy_cost:
		message_requested.emit("Too tired")
		return

	current_energy -= melee_energy_cost
	energy_changed.emit(current_energy, max_energy)
	attack_cooldown_remaining = melee_cooldown
	_flash_body(Color(1.0, 0.82, 0.54, 1.0))

	for body in attack_area.get_overlapping_bodies():
		if body == self:
			continue

		if body.has_method("take_damage"):
			body.take_damage(melee_damage, self)


func _attempt_use_medicine() -> void:
	var medicine_count: int = int(resources.get("medicine", 0))
	if medicine_count <= 0:
		message_requested.emit("No medicine")
		return

	if current_health >= max_health:
		message_requested.emit("Health full")
		return

	resources["medicine"] = medicine_count - 1
	resources_changed.emit(resources.duplicate(true))
	heal(35)
	message_requested.emit("Used medicine")


func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	message_requested.emit("You died")
	player_died.emit()


func _emit_full_state() -> void:
	health_changed.emit(current_health, max_health)
	energy_changed.emit(current_energy, max_energy)
	resources_changed.emit(resources.duplicate(true))


func _flash_body(flash_color: Color) -> void:
	body_visual.color = flash_color
	var tween := create_tween()
	tween.tween_property(body_visual, "color", _base_body_color, 0.12)


func _on_pickup_detector_area_entered(area: Area2D) -> void:
	if area.has_method("collect"):
		area.collect(self)
