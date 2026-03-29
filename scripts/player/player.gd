extends CharacterBody2D
class_name Player

const RESOURCE_IDS := ["salvage", "parts", "medicine"]

signal health_changed(current: int, maximum: int)
signal energy_changed(current: int, maximum: int)
signal resources_changed(resources: Dictionary)
signal message_requested(text: String)
signal player_died()
signal interaction_prompt_changed(text: String)

@export var max_health: int = 100
@export var max_energy: int = 100
@export var move_speed: float = 180.0
@export var melee_damage: int = 25
@export var melee_damage_type: StringName = &"melee"
@export var melee_energy_cost: int = 5
@export var melee_cooldown: float = 0.45
@export var medicine_heal_amount: int = 35

var current_health: int
var current_energy: int
var resources: Dictionary = {
	"salvage": 0,
	"parts": 0,
	"medicine": 0,
}

var is_dead: bool = false
var is_busy: bool = false
var facing_direction: Vector2 = Vector2.UP
var attack_cooldown_remaining: float = 0.0
var _base_body_color: Color
var _nearby_interactables: Array[Node2D] = []
var _busy_label: String = ""
var _action_complete_callback: Callable
var _interaction_gate_callback: Callable

@onready var body_visual: Polygon2D = $Body
@onready var facing_marker: Polygon2D = $FacingMarker
@onready var attack_pivot: Node2D = $AttackPivot
@onready var attack_area: Area2D = $AttackPivot/AttackArea
@onready var pickup_detector: Area2D = $PickupDetector
@onready var interaction_detector: Area2D = $InteractionDetector
@onready var action_timer: Timer = $ActionTimer

var _spawn_position: Vector2


func _ready() -> void:
	add_to_group("player")
	_spawn_position = global_position
	current_health = max_health
	current_energy = max_energy
	_base_body_color = body_visual.color
	pickup_detector.area_entered.connect(_on_pickup_detector_area_entered)
	interaction_detector.area_entered.connect(_on_interaction_detector_area_entered)
	interaction_detector.area_exited.connect(_on_interaction_detector_area_exited)
	interaction_detector.body_entered.connect(_on_interaction_detector_body_entered)
	interaction_detector.body_exited.connect(_on_interaction_detector_body_exited)
	action_timer.timeout.connect(_on_action_timer_timeout)
	_emit_full_state()
	_update_interaction_prompt()
	_update_render_order()


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_render_order()
		return
	
	if is_busy:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_render_order()
		return

	attack_cooldown_remaining = max(attack_cooldown_remaining - delta, 0.0)
	_handle_movement()
	move_and_slide()
	_update_render_order()

	if Input.is_action_just_pressed("interact"):
		_attempt_interact()

	if Input.is_action_just_pressed("attack"):
		_attempt_attack()

	if Input.is_action_just_pressed("use_medicine"):
		_attempt_use_medicine()


func add_resource(resource_id: String, amount: int, show_message: bool = true) -> bool:
	if amount == 0:
		return false

	if not RESOURCE_IDS.has(resource_id):
		message_requested.emit("Invalid resource id: %s" % resource_id)
		return false

	var current_amount: int = int(resources.get(resource_id, 0))
	resources[resource_id] = max(current_amount + amount, 0)
	resources_changed.emit(resources.duplicate(true))
	if show_message:
		message_requested.emit("%s +%d" % [resource_id.capitalize(), amount])
	return true


func spend_resource(resource_id: String, amount: int) -> bool:
	if amount <= 0:
		return true

	if not RESOURCE_IDS.has(resource_id):
		message_requested.emit("Invalid resource id: %s" % resource_id)
		return false

	var current_amount: int = int(resources.get(resource_id, 0))
	if current_amount < amount:
		return false

	resources[resource_id] = current_amount - amount
	resources_changed.emit(resources.duplicate(true))
	_update_interaction_prompt()
	return true


func has_resources(costs: Dictionary) -> bool:
	for resource_id in costs.keys():
		var amount := int(costs[resource_id])
		if amount <= 0:
			continue

		if not RESOURCE_IDS.has(String(resource_id)):
			return false

		if int(resources.get(String(resource_id), 0)) < amount:
			return false

	return true


func spend_resources(costs: Dictionary) -> bool:
	if not has_resources(costs):
		return false

	for resource_id in costs.keys():
		var amount := int(costs[resource_id])
		if amount <= 0:
			continue
		spend_resource(String(resource_id), amount)

	_update_interaction_prompt()
	return true


func can_spend_energy(amount: int) -> bool:
	return current_energy >= amount


func spend_energy(amount: int) -> bool:
	if amount <= 0:
		return true

	if current_energy < amount:
		return false

	current_energy -= amount
	energy_changed.emit(current_energy, max_energy)
	_update_interaction_prompt()
	return true


func restore_energy(amount: int) -> void:
	if amount <= 0:
		return

	current_energy = min(current_energy + amount, max_energy)
	energy_changed.emit(current_energy, max_energy)
	_update_interaction_prompt()


func restore_full_energy() -> void:
	current_energy = max_energy
	energy_changed.emit(current_energy, max_energy)
	_update_interaction_prompt()


func begin_timed_action(duration: float, label: String, on_complete: Callable) -> bool:
	if is_dead or is_busy:
		return false

	is_busy = true
	_busy_label = label
	_action_complete_callback = on_complete
	action_timer.start(duration)
	_update_interaction_prompt()
	return true


func cancel_timed_action() -> void:
	if not is_busy:
		return

	action_timer.stop()
	is_busy = false
	_busy_label = ""
	_action_complete_callback = Callable()
	_update_interaction_prompt()


func set_interaction_gate(callback: Callable) -> void:
	_interaction_gate_callback = callback
	_update_interaction_prompt()


func refresh_interaction_prompt() -> void:
	_update_interaction_prompt()


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

	var hit_targets: Array = []
	for body in attack_area.get_overlapping_bodies():
		if body == self:
			continue

		if not body.is_in_group("enemies"):
			continue

		if not body.has_method("take_damage"):
			continue

		hit_targets.append(body)

	if hit_targets.is_empty():
		return
	
	if not spend_energy(melee_energy_cost):
		message_requested.emit("Too tired")
		return
	
	attack_cooldown_remaining = melee_cooldown
	_flash_body(Color(1.0, 0.82, 0.54, 1.0))
	
	for body in hit_targets:
		if is_instance_valid(body):
			body.take_damage(melee_damage, {
				"attacker": self,
				"damage_type": melee_damage_type,
			})


func _attempt_use_medicine() -> void:
	var medicine_count: int = int(resources.get("medicine", 0))
	if medicine_count <= 0:
		message_requested.emit("No medicine")
		return

	if current_health >= max_health:
		message_requested.emit("Health full")
		return

	if not spend_resource("medicine", 1):
		message_requested.emit("No medicine")
		return

	heal(medicine_heal_amount)
	message_requested.emit("Used medicine")
	_update_interaction_prompt()


func _attempt_interact() -> void:
	var interactable := _get_active_interactable()
	if interactable == null:
		return

	if interactable.has_method("interact"):
		interactable.interact(self)


func _die() -> void:
	is_dead = true
	cancel_timed_action()
	velocity = Vector2.ZERO
	message_requested.emit("You died")
	player_died.emit()
	_update_interaction_prompt()


func reset_for_new_run() -> void:
	is_dead = false
	cancel_timed_action()
	current_health = max_health
	current_energy = max_energy
	resources = {
		"salvage": 0,
		"parts": 0,
		"medicine": 0,
	}
	attack_cooldown_remaining = 0.0
	velocity = Vector2.ZERO
	_nearby_interactables.clear()
	global_position = _spawn_position
	_emit_full_state()
	_update_interaction_prompt()
	_update_render_order()


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


func _on_interaction_detector_area_entered(area: Area2D) -> void:
	_register_interactable(area)


func _on_interaction_detector_area_exited(area: Area2D) -> void:
	_unregister_interactable(area)


func _on_interaction_detector_body_entered(body: Node2D) -> void:
	_register_interactable(body)


func _on_interaction_detector_body_exited(body: Node2D) -> void:
	_unregister_interactable(body)


func _on_action_timer_timeout() -> void:
	is_busy = false
	var callback := _action_complete_callback
	_action_complete_callback = Callable()
	_busy_label = ""
	if callback.is_valid() and not is_dead:
		callback.call()
	_update_interaction_prompt()


func _get_active_interactable() -> Node2D:
	var best_interactable: Node2D = null
	var best_priority := -INF
	var best_distance := INF

	for interactable in _nearby_interactables:
		if not is_instance_valid(interactable):
			continue

		if _interaction_gate_callback.is_valid() and not _interaction_gate_callback.call(interactable):
			continue

		if interactable.has_method("can_interact") and not interactable.can_interact(self):
			continue

		var priority := 0.0
		if interactable.has_method("get_interaction_priority"):
			priority = float(interactable.get_interaction_priority(self))

		var distance := global_position.distance_squared_to(interactable.global_position)
		if priority > best_priority or (is_equal_approx(priority, best_priority) and distance < best_distance):
			best_priority = priority
			best_distance = distance
			best_interactable = interactable

	return best_interactable


func _update_interaction_prompt() -> void:
	if is_dead:
		interaction_prompt_changed.emit("")
		return

	if is_busy:
		interaction_prompt_changed.emit(_busy_label)
		return

	var interactable := _get_active_interactable()
	if interactable != null and interactable.has_method("get_interaction_label"):
		interaction_prompt_changed.emit(str(interactable.get_interaction_label(self)))
		return

	interaction_prompt_changed.emit("")


func _register_interactable(interactable: Node2D) -> void:
	if interactable == null or not interactable.has_method("get_interaction_label"):
		return

	if interactable.has_method("is_direct_interactable") and not interactable.is_direct_interactable():
		return
	
	if _nearby_interactables.has(interactable):
		return

	_nearby_interactables.append(interactable)
	_update_interaction_prompt()


func _unregister_interactable(interactable: Node2D) -> void:
	_nearby_interactables.erase(interactable)
	_update_interaction_prompt()


func _update_render_order() -> void:
	z_index = int(round(global_position.y))
