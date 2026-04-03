extends Node
class_name PlayerInteractionController

const RECYCLE_SEARCH_RADIUS := 72.0
const PLACEABLE_PROFILE_SCRIPT := preload("res://scripts/data/placeable_profile.gd")

signal prompt_changed(text: String)

var player
var _nearby_interactables: Array[Node2D] = []
var _interaction_gate_callback: Callable


func configure(player_ref) -> void:
	player = player_ref


func set_interaction_gate(callback: Callable) -> void:
	_interaction_gate_callback = callback
	refresh_prompt()


func refresh_prompt() -> void:
	if player == null or not is_instance_valid(player):
		return

	if player.is_dead:
		prompt_changed.emit("")
		return

	if player.is_busy:
		prompt_changed.emit(String(player._busy_label))
		return

	if player.is_build_mode_active():
		prompt_changed.emit("Build: E place | Q prev | Tab next | R rotate | C recycle")
		return

	var interactable := get_active_interactable()
	if interactable != null and interactable.has_method("get_interaction_label"):
		prompt_changed.emit(str(interactable.get_interaction_label(player)))
		return

	prompt_changed.emit("")


func register_interactable(interactable: Node2D) -> void:
	if interactable == null or not interactable.has_method("get_interaction_label"):
		return
	if interactable.has_method("is_direct_interactable") and not interactable.is_direct_interactable():
		return
	if _nearby_interactables.has(interactable):
		return
	_nearby_interactables.append(interactable)
	refresh_prompt()


func unregister_interactable(interactable: Node2D) -> void:
	_nearby_interactables.erase(interactable)
	refresh_prompt()


func clear_interactables() -> void:
	_nearby_interactables.clear()
	refresh_prompt()


func get_active_interactable() -> Node2D:
	if player == null or not is_instance_valid(player):
		return null

	var best_interactable: Node2D = null
	var best_priority := -INF
	var best_distance := INF

	for interactable in _nearby_interactables:
		if not is_instance_valid(interactable):
			continue
		if _interaction_gate_callback.is_valid() and not _interaction_gate_callback.call(interactable):
			continue
		if interactable.has_method("can_interact") and not interactable.can_interact(player):
			continue

		var priority := 0.0
		if interactable.has_method("get_interaction_priority"):
			priority = float(interactable.get_interaction_priority(player))

		var distance: float = player.global_position.distance_squared_to(interactable.global_position)
		if priority > best_priority or (is_equal_approx(priority, best_priority) and distance < best_distance):
			best_priority = priority
			best_distance = distance
			best_interactable = interactable

	return best_interactable


func attempt_interact() -> void:
	var interactable := get_active_interactable()
	if interactable == null:
		return
	if interactable.has_method("interact"):
		interactable.interact(player)


func attempt_recycle() -> void:
	var recyclable := get_active_interactable()
	if recyclable == null or not can_recycle_placeable(recyclable):
		recyclable = get_nearest_recyclable_placeable()
	if recyclable == null:
		return
	if recyclable.has_method("recycle"):
		recyclable.recycle(player)


func get_nearest_recyclable_placeable() -> Node2D:
	if player == null or not is_instance_valid(player):
		return null
	var best_placeable: Node2D = null
	var best_distance := INF
	for placeable in _get_placeables_in_scope():
		if placeable == null or not is_instance_valid(placeable):
			continue
		if not placeable.has_method("recycle"):
			continue
		if not placeable.has_method("can_interact") or not placeable.can_interact(player):
			continue
		var profile: PlaceableProfile = placeable.get("profile") as PlaceableProfile
		if profile == null or profile.get_script() != PLACEABLE_PROFILE_SCRIPT:
			continue
		if int(placeable.get("current_hp")) < int(profile.max_hp):
			continue
		var distance: float = player.global_position.distance_to(placeable.global_position)
		if distance > RECYCLE_SEARCH_RADIUS:
			continue
		if distance < best_distance:
			best_distance = distance
			best_placeable = placeable
	return best_placeable


func can_recycle_placeable(placeable: Node2D) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if placeable == null or not is_instance_valid(placeable):
		return false
	if not placeable.has_method("recycle"):
		return false
	if not placeable.has_method("can_interact") or not placeable.can_interact(player):
		return false
	var profile: PlaceableProfile = placeable.get("profile") as PlaceableProfile
	if profile == null or profile.get_script() != PLACEABLE_PROFILE_SCRIPT:
		return false
	return int(placeable.get("current_hp")) >= int(profile.max_hp)


func _get_placeables_in_scope() -> Array:
	if player == null or not is_instance_valid(player):
		return []
	var game_root: Node = player.get_parent()
	if game_root == null or not is_instance_valid(game_root):
		return []
	var placeables_root: Node = game_root.get_node_or_null("World/ConstructionPlaceables")
	if placeables_root == null or not is_instance_valid(placeables_root):
		return []
	return placeables_root.get_children()
