extends Node
class_name PoiController

const EXPLORATION_SPAWN_POINT_SCRIPT := preload("res://scripts/world/exploration_spawn_point.gd")
const ENEMY_DEFINITION_SCRIPT := preload("res://scripts/data/enemy_definition.gd")
const POI_DEFINITION_SCRIPT := preload("res://scripts/data/poi_definition.gd")
const POI_EVENT_DEFINITION_SCRIPT := preload("res://scripts/data/poi_event_definition.gd")
const EMPTY_POI_ID: StringName = &""
const DOG_HIDDEN_STOCK_RATIO := 0.25

const POSITIVE_POI_MODIFIERS: Array[StringName] = [&"bountiful_food", &"extra_parts"]
const NEGATIVE_POI_MODIFIERS: Array[StringName] = [&"disturbed", &"elite_present"]

signal autosave_requested
signal poi_discovered(poi_id: StringName)

var game_manager
var player
var world_root
var exploration_spawn_points_root
var exploration_enemy_scene: PackedScene
var exploration_enemy_layer
var default_daily_elite_enemy: Resource
var poi_definitions: Array[Resource] = []
var poi_event_definitions: Array[Resource] = []
var mvp2_run_controller = null
var get_local_scavenge_nodes_callback: Callable = Callable()
var daily_poi_refill_base_nodes: int = 1
var daily_poi_refill_bonus_chance: float = 0.3
var daily_poi_refill_bonus_nodes: int = 1

var _daily_poi_modifiers: Dictionary = {}
var _poi_visuals_by_id: Dictionary = {}
var _poi_definitions_by_id: Dictionary = {}
var _poi_event_definitions_by_id: Dictionary = {}
var _daily_poi_events: Dictionary = {}
var _debug_forced_next_daily_poi_modifiers: Dictionary = {}
var _last_daily_refilled_pois: Array[StringName] = []
var _visited_poi_ids: Dictionary = {}
var _poi_hidden_stock_defaults: Dictionary = {}
var _poi_hidden_stock_remaining: Dictionary = {}


func configure(config: Dictionary) -> void:
	game_manager = config.get("game_manager")
	player = config.get("player")
	world_root = config.get("world_root")
	exploration_spawn_points_root = config.get("exploration_spawn_points_root")
	exploration_enemy_scene = config.get("exploration_enemy_scene")
	exploration_enemy_layer = config.get("exploration_enemy_layer")
	default_daily_elite_enemy = config.get("default_daily_elite_enemy")
	poi_definitions = config.get("poi_definitions", [])
	poi_event_definitions = config.get("poi_event_definitions", [])
	get_local_scavenge_nodes_callback = config.get("get_local_scavenge_nodes_callback", Callable())
	daily_poi_refill_base_nodes = int(config.get("daily_poi_refill_base_nodes", daily_poi_refill_base_nodes))
	daily_poi_refill_bonus_chance = float(config.get("daily_poi_refill_bonus_chance", daily_poi_refill_bonus_chance))
	daily_poi_refill_bonus_nodes = int(config.get("daily_poi_refill_bonus_nodes", daily_poi_refill_bonus_nodes))
	_cache_poi_definitions()
	_cache_poi_event_definitions()
	cache_poi_visuals()
	_rebuild_poi_hidden_stock_defaults()
	_reset_poi_hidden_stock_remaining()
	_connect_poi_discovery_areas()
	refresh_player_poi_discovery_from_current_position()


func configure_scavenge_nodes() -> void:
	for node in _get_local_scavenge_nodes():
		_apply_poi_definition_to_scavenge_node(node)
		if node.has_method("configure_reward_modifier"):
			node.configure_reward_modifier(Callable(self, "apply_daily_poi_reward_modifier"))
		if node.has_signal("state_changed") and not node.state_changed.is_connected(_on_scavenge_node_state_changed):
			node.state_changed.connect(_on_scavenge_node_state_changed)
	_rebuild_poi_hidden_stock_defaults()
	if _poi_hidden_stock_remaining.is_empty():
		_reset_poi_hidden_stock_remaining()


func reset_for_new_run() -> void:
	_daily_poi_modifiers.clear()
	_daily_poi_events.clear()
	_last_daily_refilled_pois.clear()
	_visited_poi_ids.clear()
	_reset_poi_hidden_stock_remaining()


func apply_daily_poi_reward_modifier(node, rewards: Dictionary) -> Dictionary:
	var modified_rewards: Dictionary = rewards.duplicate(true)
	if node == null:
		return modified_rewards
	var poi_id := StringName(node.poi_id)
	var modifier_id := get_daily_poi_modifier(poi_id)
	match modifier_id:
		&"bountiful_food":
			modified_rewards["food"] = int(modified_rewards.get("food", 0)) + 1
		&"extra_parts":
			modified_rewards["parts"] = int(modified_rewards.get("parts", 0)) + 1
	var event_id := get_daily_poi_event(poi_id)
	var poi_event = _get_poi_event_definition(event_id)
	if poi_event != null:
		for resource_id in poi_event.reward_bonus.keys():
			modified_rewards[String(resource_id)] = int(modified_rewards.get(String(resource_id), 0)) + int(poi_event.reward_bonus.get(resource_id, 0))
	if mvp2_run_controller != null:
		var salvage_bonus: int = int(mvp2_run_controller.get_mutator_salvage_bonus())
		if salvage_bonus > 0:
			modified_rewards["salvage"] = int(modified_rewards.get("salvage", 0)) + salvage_bonus
	return modified_rewards


func roll_daily_poi_events(mvp2_controller = null) -> void:
	_daily_poi_events.clear()
	if mvp2_controller != null:
		mvp2_run_controller = mvp2_controller
	if _poi_event_definitions_by_id.is_empty():
		return
	var available_pois: Array[StringName] = []
	for poi_id_variant in _poi_visuals_by_id.keys():
		var poi_id := StringName(poi_id_variant)
		if not _is_poi_depleted(poi_id):
			available_pois.append(poi_id)
	if available_pois.is_empty():
		return
	var available_events: Array = _poi_event_definitions_by_id.keys()
	var assignment_count := mini(2, mini(available_pois.size(), available_events.size()))
	for _i in range(assignment_count):
		var poi_id: StringName = available_pois[randi() % available_pois.size()]
		var candidate_events: Array[StringName] = _get_eligible_event_ids_for_poi(poi_id)
		if candidate_events.is_empty():
			available_pois.erase(poi_id)
			continue
		var event_id := candidate_events[randi() % candidate_events.size()]
		_daily_poi_events[poi_id] = event_id
		available_pois.erase(poi_id)


func roll_daily_poi_modifiers() -> void:
	_daily_poi_modifiers.clear()
	if _poi_visuals_by_id.is_empty():
		return
	if not _debug_forced_next_daily_poi_modifiers.is_empty():
		_daily_poi_modifiers = _debug_forced_next_daily_poi_modifiers.duplicate(true)
		_debug_forced_next_daily_poi_modifiers.clear()
		return

	var used_pois := {}
	_assign_random_daily_modifier(POSITIVE_POI_MODIFIERS, used_pois)
	_assign_random_daily_modifier(NEGATIVE_POI_MODIFIERS, used_pois)


func apply_daily_poi_refills() -> void:
	_last_daily_refilled_pois.clear()
	var refill_budget: int = max(daily_poi_refill_base_nodes, 0)
	if daily_poi_refill_bonus_nodes > 0 and randf() <= daily_poi_refill_bonus_chance:
		refill_budget += daily_poi_refill_bonus_nodes
	if refill_budget <= 0:
		return

	var candidates: Array = []
	for node in _get_local_scavenge_nodes():
		if node == null or not node.has_method("is_eligible_for_daily_refill"):
			continue
		if not bool(node.is_eligible_for_daily_refill()):
			continue
		candidates.append(node)

	while refill_budget > 0 and not candidates.is_empty():
		var index := randi() % candidates.size()
		var node = candidates[index]
		candidates.remove_at(index)
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_method("apply_daily_refill"):
			continue
		if not bool(node.apply_daily_refill()):
			continue
		refill_budget -= 1
		var poi_id := StringName(node.poi_id)
		if poi_id != StringName() and not _last_daily_refilled_pois.has(poi_id):
			_last_daily_refilled_pois.append(poi_id)


func cache_poi_visuals() -> void:
	_poi_visuals_by_id.clear()
	if world_root == null or not is_instance_valid(world_root):
		return
	for child in world_root.get_children():
		var poi_id := _get_poi_id_for_world_poi_root(child)
		if poi_id == StringName():
			continue
		var label: Label = child.get_node_or_null("Label")
		var marker: Polygon2D = child.get_node_or_null("Marker")
		if label == null or marker == null:
			continue
		label.offset_left = -56.0
		label.offset_right = 84.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var poi_definition = _get_poi_definition(poi_id)
		if poi_definition != null:
			label.text = poi_definition.display_name
			label.tooltip_text = "%s\nRole: %s" % [poi_definition.display_name, poi_definition.get_reward_role_label()]
		else:
			label.tooltip_text = label.text
		_poi_visuals_by_id[poi_id] = {
			"root": child,
			"label": label,
			"marker": marker,
			"base_text": label.text,
			"base_tooltip_text": label.tooltip_text,
			"base_marker_color": marker.color,
			"base_marker_scale": marker.scale,
			"base_label_color": label.get_theme_color("font_color"),
		}


func refresh_poi_modifier_visuals() -> void:
	for poi_id_variant in _poi_visuals_by_id.keys():
		var poi_id := StringName(poi_id_variant)
		var visual_data: Dictionary = _poi_visuals_by_id[poi_id]
		var label: Label = visual_data.get("label")
		var marker: Polygon2D = visual_data.get("marker")
		var base_text := String(visual_data.get("base_text", ""))
		var base_marker_color: Color = visual_data.get("base_marker_color", Color.WHITE)
		var base_marker_scale: Vector2 = visual_data.get("base_marker_scale", Vector2.ONE)
		var base_label_color: Color = visual_data.get("base_label_color", Color.WHITE)
		var modifier_id := get_daily_poi_modifier(poi_id)
		var event_id := get_daily_poi_event(poi_id)
		var poi_event = _get_poi_event_definition(event_id)
		if modifier_id == StringName():
			label.text = base_text
			label.tooltip_text = String(visual_data.get("base_tooltip_text", base_text))
			if poi_event != null:
				label.text = "%s [%s]" % [base_text, poi_event.display_name]
				label.tooltip_text = "%s\nEvent: %s" % [String(visual_data.get("base_tooltip_text", base_text)), poi_event.display_name]
			label.add_theme_color_override("font_color", base_label_color)
			marker.color = poi_event.event_tint.lerp(base_marker_color, 0.4) if poi_event != null else base_marker_color
			marker.scale = base_marker_scale
			continue
		label.text = "%s %s" % [base_text, _get_modifier_label_text(modifier_id)]
		label.tooltip_text = "%s\nModifier: %s" % [String(visual_data.get("base_tooltip_text", base_text)), _get_modifier_label_text(modifier_id)]
		var modifier_tint := _get_modifier_tint(modifier_id)
		if poi_event != null:
			label.text = "%s %s [%s]" % [base_text, _get_modifier_label_text(modifier_id), poi_event.display_name]
			label.tooltip_text = "%s\nModifier: %s\nEvent: %s" % [String(visual_data.get("base_tooltip_text", base_text)), _get_modifier_label_text(modifier_id), poi_event.display_name]
			modifier_tint = modifier_tint.lerp(poi_event.event_tint, 0.3)
		label.add_theme_color_override("font_color", modifier_tint)
		marker.color = base_marker_color.lerp(modifier_tint, 0.48)
		marker.scale = base_marker_scale * _get_modifier_marker_scale(modifier_id)


func get_daily_modifier_summary() -> String:
	var clauses: Array[String] = []
	for poi_id_variant in _daily_poi_modifiers.keys():
		var poi_id := StringName(poi_id_variant)
		var modifier_id := StringName(_daily_poi_modifiers[poi_id])
		var poi_name := get_poi_display_name_with_role(poi_id)
		match modifier_id:
			&"bountiful_food":
				clauses.append("%s has extra food." % poi_name)
			&"extra_parts":
				clauses.append("%s has extra parts." % poi_name)
			&"disturbed":
				clauses.append("%s is disturbed." % poi_name)
			&"elite_present":
				clauses.append("%s has an elite guard." % poi_name)
	for poi_id_variant in _daily_poi_events.keys():
		var poi_id := StringName(poi_id_variant)
		var poi_event = _get_poi_event_definition(StringName(_daily_poi_events[poi_id]))
		if poi_event != null:
			clauses.append("%s is affected by %s." % [get_poi_display_name_with_role(poi_id), poi_event.display_name])
	if not _last_daily_refilled_pois.is_empty():
		var restocked_names: Array[String] = []
		for poi_id in _last_daily_refilled_pois:
			restocked_names.append(get_poi_display_name_with_role(poi_id))
		clauses.append("%s restocked." % ", ".join(restocked_names))
	return " ".join(clauses)


func get_poi_display_name(poi_id: StringName) -> String:
	var poi_definition = _get_poi_definition(poi_id)
	if poi_definition != null:
		return poi_definition.display_name
	if not _poi_visuals_by_id.has(poi_id):
		return String(poi_id)
	return String(_poi_visuals_by_id[poi_id].get("base_text", String(poi_id)))


func get_poi_display_name_with_role(poi_id: StringName) -> String:
	var display_name := get_poi_display_name(poi_id)
	var role_label := debug_get_poi_reward_role_label(poi_id)
	if role_label.is_empty():
		return display_name
	return "%s (%s)" % [display_name, role_label]


func get_daily_poi_modifier(poi_id: StringName) -> StringName:
	return StringName(_daily_poi_modifiers.get(poi_id, StringName()))


func get_daily_poi_event(poi_id: StringName) -> StringName:
	return StringName(_daily_poi_events.get(poi_id, StringName()))


func get_all_poi_ids() -> Array[StringName]:
	var poi_ids: Array[StringName] = []
	for poi_id_variant in _poi_visuals_by_id.keys():
		poi_ids.append(StringName(poi_id_variant))
	return poi_ids


func get_known_poi_ids() -> Array[StringName]:
	var poi_ids: Array[StringName] = []
	for poi_id_variant in _poi_visuals_by_id.keys():
		var poi_id := StringName(poi_id_variant)
		if is_poi_known(poi_id):
			poi_ids.append(poi_id)
	return poi_ids


func is_poi_depleted(poi_id: StringName) -> bool:
	return _is_poi_depleted(poi_id)


func get_adjusted_exploration_spawn_count(spawn_point, current_target_counts: Dictionary, exploration_spawn_counts: Dictionary) -> int:
	var spawn_id := String(spawn_point.spawn_id)
	var target_count := _get_or_roll_exploration_spawn_count(spawn_point, exploration_spawn_counts)
	var poi_id := get_poi_id_for_exploration_spawn(spawn_point)
	if poi_id == StringName():
		current_target_counts[spawn_id] = target_count
		return target_count
	if get_daily_poi_modifier(poi_id) == &"disturbed":
		target_count += 1
	var event_id := get_daily_poi_event(poi_id)
	var poi_event = _get_poi_event_definition(event_id)
	if poi_event != null:
		target_count += int(poi_event.guard_count_delta)
	if mvp2_run_controller != null:
		target_count += int(mvp2_run_controller.get_mutator_poi_guard_bonus())
	current_target_counts[spawn_id] = target_count
	return target_count


func sync_daily_modifier_enemies() -> void:
	if game_manager == null or game_manager.run_state != game_manager.RunState.PRE_WAVE:
		return
	for poi_id_variant in _daily_poi_modifiers.keys():
		var poi_id := StringName(poi_id_variant)
		if get_daily_poi_modifier(poi_id) != &"elite_present":
			continue
		if _has_active_special_poi_elite(poi_id):
			continue
		var guard_spawn = _get_poi_guard_spawn_point(poi_id)
		if guard_spawn == null:
			continue
		_spawn_special_poi_elite(poi_id, guard_spawn, &"daily_modifier_elite")
	for poi_id_variant in _daily_poi_events.keys():
		var poi_id := StringName(poi_id_variant)
		var poi_event = _get_poi_event_definition(get_daily_poi_event(poi_id))
		if poi_event == null or not bool(poi_event.forces_elite):
			continue
		if _has_active_special_poi_elite(poi_id):
			continue
		var guard_spawn = _get_poi_guard_spawn_point(poi_id)
		if guard_spawn == null:
			continue
		_spawn_special_poi_elite(poi_id, guard_spawn, &"daily_event_elite")


func clear_stale_daily_modifier_enemies() -> void:
	if exploration_enemy_layer == null:
		return
	for child in exploration_enemy_layer.get_children():
		if not is_instance_valid(child):
			continue
		if child.is_queued_for_deletion():
			continue
		var spawn_kind := String(child.get_meta("spawn_kind", ""))
		if spawn_kind != "daily_modifier_elite" and spawn_kind != "daily_event_elite":
			continue
		var poi_id := StringName(child.get_meta("daily_modifier_poi_id", StringName()))
		var modifier_active := get_daily_poi_modifier(poi_id) == &"elite_present"
		var poi_event = _get_poi_event_definition(get_daily_poi_event(poi_id))
		var event_active := poi_event != null and bool(poi_event.forces_elite)
		if modifier_active or event_active:
			continue
		child.queue_free()


func get_save_state() -> Dictionary:
	var saved_daily_modifiers := {}
	for poi_id_variant in _daily_poi_modifiers.keys():
		saved_daily_modifiers[String(poi_id_variant)] = String(_daily_poi_modifiers[poi_id_variant])
	var saved_refilled_pois: Array[String] = []
	for poi_id in _last_daily_refilled_pois:
		saved_refilled_pois.append(String(poi_id))
	return {
		"daily_poi_modifiers": saved_daily_modifiers,
		"daily_poi_events": _get_saved_daily_poi_events(),
		"last_daily_refilled_pois": saved_refilled_pois,
		"visited_poi_ids": _get_saved_visited_poi_ids(),
		"hidden_stock_remaining": _get_saved_hidden_stock_remaining(),
	}


func apply_game_state(game_state: Dictionary) -> void:
	_daily_poi_modifiers = _duplicate_stringname_dictionary(game_state.get("daily_poi_modifiers", {}))
	_daily_poi_events = _duplicate_stringname_dictionary(game_state.get("daily_poi_events", {}))
	_last_daily_refilled_pois.clear()
	for raw_poi_id in game_state.get("last_daily_refilled_pois", []):
		_last_daily_refilled_pois.append(StringName(raw_poi_id))
	_visited_poi_ids.clear()
	for raw_poi_id in game_state.get("visited_poi_ids", []):
		var poi_id := StringName(raw_poi_id)
		if poi_id != StringName():
			_visited_poi_ids[poi_id] = true
	_restore_hidden_stock_remaining(game_state.get("hidden_stock_remaining", {}))
	refresh_player_poi_discovery_from_current_position()


func debug_get_daily_poi_modifiers() -> Dictionary:
	return _daily_poi_modifiers.duplicate(true)


func debug_set_daily_poi_modifiers(modifiers: Dictionary) -> void:
	_daily_poi_modifiers = modifiers.duplicate(true)
	refresh_poi_modifier_visuals()


func debug_queue_forced_next_daily_poi_modifiers(modifiers: Dictionary) -> void:
	_debug_forced_next_daily_poi_modifiers = modifiers.duplicate(true)


func debug_get_poi_label_text(poi_id: StringName) -> String:
	if not _poi_visuals_by_id.has(poi_id):
		return ""
	var visual_data: Dictionary = _poi_visuals_by_id[poi_id]
	var label: Label = visual_data.get("label")
	return label.text if label != null else ""


func debug_get_poi_base_label_text(poi_id: StringName) -> String:
	if not _poi_visuals_by_id.has(poi_id):
		return ""
	var visual_data: Dictionary = _poi_visuals_by_id[poi_id]
	return String(visual_data.get("base_text", ""))


func debug_get_poi_reward_role_label(poi_id: StringName) -> String:
	var poi_definition = _get_poi_definition(poi_id)
	if poi_definition == null:
		return ""
	return poi_definition.get_reward_role_label()


func get_poi_guard_spawn_point(poi_id: StringName):
	return _get_poi_guard_spawn_point(poi_id)


func get_or_roll_exploration_spawn_count(spawn_point, exploration_spawn_counts: Dictionary) -> int:
	return _get_or_roll_exploration_spawn_count(spawn_point, exploration_spawn_counts)


func is_poi_known(poi_id: StringName) -> bool:
	return bool(_visited_poi_ids.get(poi_id, false))


func refresh_player_poi_discovery_from_current_position() -> void:
	if player == null or not is_instance_valid(player):
		return
	_refresh_player_poi_discovery(player.global_position)


func get_best_known_poi_for_dog(from_position: Vector2) -> StringName:
	var best_poi_id := StringName()
	var best_distance := INF
	for poi_id_variant in _visited_poi_ids.keys():
		var poi_id := StringName(poi_id_variant)
		if not bool(_visited_poi_ids.get(poi_id, false)):
			continue
		if _is_poi_depleted(poi_id):
			continue
		var poi_position := _get_poi_world_position(poi_id)
		var distance := from_position.distance_squared_to(poi_position)
		if distance < best_distance:
			best_distance = distance
			best_poi_id = poi_id
	return best_poi_id


func get_poi_world_position(poi_id: StringName) -> Vector2:
	return _get_poi_world_position(poi_id)


func roll_dog_scavenge_reward(poi_id: StringName) -> Dictionary:
	var hidden_remaining: Dictionary = _get_hidden_stock_remaining_for_poi(poi_id)
	if _get_reward_total(hidden_remaining) > 0:
		_poi_hidden_stock_remaining[poi_id] = _empty_reward_dictionary()
		return hidden_remaining
	var node = _get_next_visible_dog_scavenge_node(poi_id)
	if node == null:
		return {}
	return node.consume_all_remaining_rewards()


func get_poi_id_for_exploration_spawn(spawn_point) -> StringName:
	if spawn_point == null:
		return EMPTY_POI_ID
	var raw_poi_id = spawn_point.get("poi_id")
	if raw_poi_id != null:
		var explicit_poi_id: StringName = raw_poi_id
		if explicit_poi_id != EMPTY_POI_ID:
			return explicit_poi_id
	return get_poi_id_from_name(String(spawn_point.name))


func get_poi_id_from_name(node_name: String) -> StringName:
	var lower_name := node_name.to_lower()
	if not lower_name.begins_with("poi_") or lower_name.length() < 5:
		return EMPTY_POI_ID
	return StringName("poi_%s" % lower_name.substr(4, 1))


func resolve_micro_loot_spawn_defaults(spawn_point) -> Dictionary:
	if spawn_point == null:
		return {}
	var resolved_resource_id := String(spawn_point.resource_id)
	var resolved_amount := int(spawn_point.amount)
	if not bool(spawn_point.get("use_poi_role_defaults")):
		return {
			"resource_id": resolved_resource_id,
			"amount": resolved_amount,
		}
	var raw_poi_id = spawn_point.get("poi_id")
	if raw_poi_id == null:
		return {
			"resource_id": resolved_resource_id,
			"amount": resolved_amount,
		}
	var spawn_poi_id: StringName = raw_poi_id
	var poi_definition = _get_poi_definition(spawn_poi_id)
	if poi_definition == null:
		return {
			"resource_id": resolved_resource_id,
			"amount": resolved_amount,
		}
	return {
		"resource_id": poi_definition.get_default_micro_loot_resource_id(),
		"amount": poi_definition.get_default_micro_loot_amount(),
	}


func _on_scavenge_node_state_changed(_node) -> void:
	autosave_requested.emit()


func _assign_random_daily_modifier(candidate_modifiers: Array[StringName], used_pois: Dictionary) -> void:
	var available_assignments: Array[Dictionary] = []
	for modifier_id in candidate_modifiers:
		var eligible_pois := _get_modifier_eligible_poi_ids(modifier_id, used_pois)
		if eligible_pois.is_empty():
			continue
		available_assignments.append({"modifier": modifier_id, "pois": eligible_pois})
	if available_assignments.is_empty():
		return
	var assignment: Dictionary = available_assignments[randi() % available_assignments.size()]
	var modifier_id := StringName(assignment.get("modifier", StringName()))
	var eligible_pois: Array[StringName] = assignment.get("pois", [])
	if eligible_pois.is_empty():
		return
	var poi_id: StringName = eligible_pois[randi() % eligible_pois.size()]
	_daily_poi_modifiers[poi_id] = modifier_id
	used_pois[poi_id] = true


func _get_modifier_eligible_poi_ids(modifier_id: StringName, excluded_pois: Dictionary) -> Array[StringName]:
	var eligible: Array[StringName] = []
	for poi_id_variant in _poi_visuals_by_id.keys():
		var poi_id := StringName(poi_id_variant)
		if excluded_pois.has(poi_id):
			continue
		if _is_poi_depleted(poi_id):
			continue
		if modifier_id == &"elite_present" and not _is_poi_eligible_for_elite_modifier(poi_id):
			continue
		eligible.append(poi_id)
	return eligible


func _is_poi_depleted(poi_id: StringName) -> bool:
	var visible_remaining_total := 0
	for node in _get_local_scavenge_nodes():
		if StringName(node.poi_id) != poi_id:
			continue
		if node.has_method("get_remaining_rewards"):
			var remaining_rewards: Dictionary = node.get_remaining_rewards()
			for resource_id in remaining_rewards.keys():
				visible_remaining_total += int(remaining_rewards.get(resource_id, 0))
		elif not bool(node.is_depleted):
			visible_remaining_total += int(node.reward_salvage) + int(node.reward_parts) + int(node.reward_medicine) + int(node.reward_bullets) + int(node.reward_food) + int(node.reward_battery)
	var hidden_remaining_total := 0
	var hidden_remaining: Dictionary = _get_hidden_stock_remaining_for_poi(poi_id)
	for resource_id in hidden_remaining.keys():
		hidden_remaining_total += int(hidden_remaining.get(resource_id, 0))
	return visible_remaining_total <= 0 and hidden_remaining_total <= 0


func _is_poi_eligible_for_elite_modifier(poi_id: StringName) -> bool:
	var poi_definition = _get_poi_definition(poi_id)
	if poi_definition == null or not bool(poi_definition.elite_modifier_eligible):
		return false
	var guard_spawn = _get_poi_guard_spawn_point(poi_id)
	if guard_spawn == null:
		return false
	var enemy_definition: Resource = guard_spawn.enemy_definition
	if enemy_definition == null or enemy_definition.get_script() != ENEMY_DEFINITION_SCRIPT:
		return false
	return not bool(enemy_definition.is_elite)


func _get_modifier_label_text(modifier_id: StringName) -> String:
	match modifier_id:
		&"bountiful_food":
			return "[FOOD]"
		&"extra_parts":
			return "[PARTS]"
		&"disturbed":
			return "[HOT]"
		&"elite_present":
			return "[ELITE]"
	return ""


func _get_modifier_tint(modifier_id: StringName) -> Color:
	match modifier_id:
		&"bountiful_food":
			return Color(0.58, 0.96, 0.46, 1.0)
		&"extra_parts":
			return Color(0.66, 0.9, 1.0, 1.0)
		&"disturbed":
			return Color(1.0, 0.62, 0.24, 1.0)
		&"elite_present":
			return Color(1.0, 0.86, 0.32, 1.0)
	return Color.WHITE


func _get_saved_visited_poi_ids() -> Array[String]:
	var saved_ids: Array[String] = []
	for poi_id_variant in _visited_poi_ids.keys():
		var poi_id := StringName(poi_id_variant)
		if bool(_visited_poi_ids.get(poi_id, false)):
			saved_ids.append(String(poi_id))
	return saved_ids


func _refresh_player_poi_discovery(player_position: Vector2) -> void:
	for poi_id_variant in _poi_visuals_by_id.keys():
		var poi_id := StringName(poi_id_variant)
		if bool(_visited_poi_ids.get(poi_id, false)):
			continue
		var poi_position := _get_poi_world_position(poi_id)
		if player_position.distance_to(poi_position) <= 150.0:
			_visited_poi_ids[poi_id] = true
			poi_discovered.emit(poi_id)


func _get_poi_world_position(poi_id: StringName) -> Vector2:
	if not _poi_visuals_by_id.has(poi_id):
		return Vector2.ZERO
	var root: Node2D = _poi_visuals_by_id[poi_id].get("root")
	if root == null or not is_instance_valid(root):
		return Vector2.ZERO
	return root.global_position


func _get_dog_reward_amount(resource_id: String, total_amount: int) -> int:
	match resource_id:
		"salvage":
			return clampi(maxi(int(round(total_amount * 0.4)), 1), 1, 3)
		"food":
			return clampi(maxi(int(round(total_amount * 0.45)), 1), 1, 3)
		"parts":
			return clampi(maxi(int(round(total_amount * 0.4)), 1), 1, 2)
		"bullets":
			return clampi(maxi(int(round(total_amount * 0.35)), 2), 2, 6)
		"medicine":
			return clampi(maxi(int(round(total_amount * 0.4)), 1), 1, 2)
		"battery":
			return 1
		_:
			return 1


func debug_get_remaining_poi_stock_total(poi_id: StringName) -> int:
	var total := 0
	var hidden_remaining: Dictionary = _get_hidden_stock_remaining_for_poi(poi_id)
	for resource_id in hidden_remaining.keys():
		total += int(hidden_remaining.get(resource_id, 0))
	for node in _get_local_scavenge_nodes():
		if node == null or not is_instance_valid(node):
			continue
		if StringName(node.poi_id) != poi_id:
			continue
		if not node.has_method("get_remaining_rewards"):
			continue
		var remaining_rewards: Dictionary = node.get_remaining_rewards()
		for resource_id in remaining_rewards.keys():
			total += int(remaining_rewards.get(resource_id, 0))
	return total


func _rebuild_poi_hidden_stock_defaults() -> void:
	_poi_hidden_stock_defaults.clear()
	for node in _get_local_scavenge_nodes():
		if node == null or not is_instance_valid(node):
			continue
		var poi_id := StringName(node.poi_id)
		if poi_id == StringName():
			continue
		if not _poi_hidden_stock_defaults.has(poi_id):
			_poi_hidden_stock_defaults[poi_id] = {
				"salvage": 0,
				"parts": 0,
				"medicine": 0,
				"bullets": 0,
				"food": 0,
				"battery": 0,
			}
		var hidden_stock: Dictionary = _poi_hidden_stock_defaults[poi_id]
		hidden_stock["salvage"] = int(hidden_stock.get("salvage", 0)) + int(round(int(node.reward_salvage) * DOG_HIDDEN_STOCK_RATIO))
		hidden_stock["parts"] = int(hidden_stock.get("parts", 0)) + int(round(int(node.reward_parts) * DOG_HIDDEN_STOCK_RATIO))
		hidden_stock["medicine"] = int(hidden_stock.get("medicine", 0)) + int(round(int(node.reward_medicine) * DOG_HIDDEN_STOCK_RATIO))
		hidden_stock["bullets"] = int(hidden_stock.get("bullets", 0)) + int(round(int(node.reward_bullets) * DOG_HIDDEN_STOCK_RATIO))
		hidden_stock["food"] = int(hidden_stock.get("food", 0)) + int(round(int(node.reward_food) * DOG_HIDDEN_STOCK_RATIO))
		hidden_stock["battery"] = int(hidden_stock.get("battery", 0)) + int(round(int(node.reward_battery) * DOG_HIDDEN_STOCK_RATIO))


func _reset_poi_hidden_stock_remaining() -> void:
	_poi_hidden_stock_remaining.clear()
	for poi_id_variant in _poi_hidden_stock_defaults.keys():
		var poi_id := StringName(poi_id_variant)
		_poi_hidden_stock_remaining[poi_id] = Dictionary(_poi_hidden_stock_defaults[poi_id]).duplicate(true)


func _get_hidden_stock_remaining_for_poi(poi_id: StringName) -> Dictionary:
	if not _poi_hidden_stock_remaining.has(poi_id):
		return _empty_reward_dictionary()
	return Dictionary(_poi_hidden_stock_remaining[poi_id])


func _get_next_visible_dog_scavenge_node(poi_id: StringName):
	var best_node = null
	var best_key := ""
	for node in _get_local_scavenge_nodes():
		if node == null or not is_instance_valid(node):
			continue
		if StringName(node.poi_id) != poi_id:
			continue
		if bool(node.is_depleted):
			continue
		if not node.has_method("get_remaining_reward_total"):
			continue
		if int(node.get_remaining_reward_total()) <= 0:
			continue
		if node.has_method("has_weapon_reward") and bool(node.has_weapon_reward()):
			continue
		var node_key := String(node.node_id)
		if best_node == null or node_key < best_key:
			best_node = node
			best_key = node_key
	return best_node


func _empty_reward_dictionary() -> Dictionary:
	return {
		"salvage": 0,
		"parts": 0,
		"medicine": 0,
		"bullets": 0,
		"food": 0,
		"battery": 0,
	}


func _get_reward_total(rewards: Dictionary) -> int:
	var total := 0
	for resource_id in rewards.keys():
		total += int(rewards.get(resource_id, 0))
	return total


func _consume_dog_reward_from_poi(poi_id: StringName, rewards: Dictionary) -> void:
	var hidden_remaining: Dictionary = _get_hidden_stock_remaining_for_poi(poi_id)
	for resource_id_variant in rewards.keys():
		var resource_id := String(resource_id_variant)
		var amount_to_consume := int(rewards.get(resource_id, 0))
		if amount_to_consume <= 0:
			continue
		var hidden_amount := int(hidden_remaining.get(resource_id, 0))
		var hidden_consumed := mini(hidden_amount, amount_to_consume)
		hidden_remaining[resource_id] = hidden_amount - hidden_consumed
		amount_to_consume -= hidden_consumed
		if amount_to_consume <= 0:
			continue
		for node in _get_local_scavenge_nodes():
			if node == null or not is_instance_valid(node):
				continue
			if StringName(node.poi_id) != poi_id:
				continue
			if not node.has_method("consume_remaining_reward"):
				continue
			amount_to_consume -= int(node.consume_remaining_reward(resource_id, amount_to_consume))
			if amount_to_consume <= 0:
				break
	_poi_hidden_stock_remaining[poi_id] = hidden_remaining


func _get_saved_hidden_stock_remaining() -> Dictionary:
	var saved: Dictionary = {}
	for poi_id_variant in _poi_hidden_stock_remaining.keys():
		saved[String(poi_id_variant)] = Dictionary(_poi_hidden_stock_remaining[poi_id_variant]).duplicate(true)
	return saved


func _restore_hidden_stock_remaining(raw_saved: Dictionary) -> void:
	_reset_poi_hidden_stock_remaining()
	for poi_id_string in raw_saved.keys():
		var poi_id := StringName(poi_id_string)
		if poi_id == StringName():
			continue
		var saved_remaining: Dictionary = raw_saved.get(poi_id_string, {})
		_poi_hidden_stock_remaining[poi_id] = {
			"salvage": int(saved_remaining.get("salvage", 0)),
			"parts": int(saved_remaining.get("parts", 0)),
			"medicine": int(saved_remaining.get("medicine", 0)),
			"bullets": int(saved_remaining.get("bullets", 0)),
			"food": int(saved_remaining.get("food", 0)),
			"battery": int(saved_remaining.get("battery", 0)),
		}


func _get_modifier_marker_scale(modifier_id: StringName) -> Vector2:
	match modifier_id:
		&"bountiful_food":
			return Vector2(1.08, 1.08)
		&"extra_parts":
			return Vector2(1.08, 1.08)
		&"disturbed":
			return Vector2(1.14, 1.14)
		&"elite_present":
			return Vector2(1.22, 1.22)
	return Vector2.ONE


func _has_active_special_poi_elite(poi_id: StringName) -> bool:
	if exploration_enemy_layer == null:
		return false
	for child in exploration_enemy_layer.get_children():
		if not is_instance_valid(child):
			continue
		if child.is_queued_for_deletion():
			continue
		if StringName(child.get_meta("daily_modifier_poi_id", StringName())) == poi_id:
			return true
	return false


func _spawn_special_poi_elite(poi_id: StringName, guard_spawn, spawn_kind: StringName) -> void:
	var elite_definition := _resolve_daily_modifier_elite_definition(guard_spawn)
	if exploration_enemy_scene == null or elite_definition == null or exploration_enemy_layer == null:
		return
	var enemy = exploration_enemy_scene.instantiate()
	enemy.definition = elite_definition
	exploration_enemy_layer.add_child(enemy)
	enemy.global_position = _get_exploration_spawn_position(guard_spawn)
	if enemy.has_method("configure_runtime_context"):
		enemy.configure_runtime_context(player, exploration_enemy_layer, _get_placeables_root())
	if mvp2_run_controller != null and enemy.has_method("set_external_move_speed_multiplier"):
		enemy.set_external_move_speed_multiplier(mvp2_run_controller.get_mutator_enemy_speed_multiplier())
	enemy.set_meta("spawn_kind", spawn_kind)
	enemy.set_meta("daily_modifier_poi_id", poi_id)
	var initial_facing := Vector2.ZERO
	if guard_spawn.has_method("get_initial_facing_vector"):
		initial_facing = guard_spawn.get_initial_facing_vector()
	var anchor_position: Vector2 = enemy.global_position
	if guard_spawn.has_method("get_anchor_position"):
		anchor_position = guard_spawn.get_anchor_position()
	if enemy.has_method("configure_exploration_context"):
		enemy.configure_exploration_context(player, initial_facing, true, anchor_position, true)


func _resolve_daily_modifier_elite_definition(guard_spawn) -> Resource:
	var poi_id := get_poi_id_for_exploration_spawn(guard_spawn)
	var poi_definition = _get_poi_definition(poi_id)
	if poi_definition != null and poi_definition.daily_elite_definition != null:
		var definition_resource: Resource = poi_definition.daily_elite_definition
		if definition_resource.get_script() == ENEMY_DEFINITION_SCRIPT and definition_resource.is_valid_definition() and bool(definition_resource.is_elite):
			return definition_resource
	if default_daily_elite_enemy != null:
		if default_daily_elite_enemy.get_script() == ENEMY_DEFINITION_SCRIPT and default_daily_elite_enemy.is_valid_definition() and bool(default_daily_elite_enemy.is_elite):
			return default_daily_elite_enemy
	return null


func _get_poi_guard_spawn_point(poi_id: StringName):
	if exploration_spawn_points_root == null:
		return null
	for child in exploration_spawn_points_root.get_children():
		if child == null or child.get_script() != EXPLORATION_SPAWN_POINT_SCRIPT:
			continue
		if get_poi_id_for_exploration_spawn(child) == poi_id:
			return child
	return null


func _get_exploration_spawn_position(spawn_point) -> Vector2:
	var base_position: Vector2 = spawn_point.global_position
	var scatter_radius: float = float(spawn_point.scatter_radius)
	if scatter_radius <= 0.0:
		return base_position
	return base_position + Vector2.RIGHT.rotated(randf() * TAU) * (randf() * scatter_radius)


func _get_or_roll_exploration_spawn_count(spawn_point, exploration_spawn_counts: Dictionary) -> int:
	var spawn_id := String(spawn_point.spawn_id)
	if exploration_spawn_counts.has(spawn_id):
		return int(exploration_spawn_counts[spawn_id])
	var rolled_count := randi_range(int(spawn_point.min_count), int(spawn_point.max_count))
	exploration_spawn_counts[spawn_id] = rolled_count
	return rolled_count


func _duplicate_stringname_dictionary(raw_dictionary: Dictionary) -> Dictionary:
	var result := {}
	for key in raw_dictionary.keys():
		result[StringName(String(key))] = StringName(raw_dictionary[key])
	return result


func _get_placeables_root() -> Node:
	if exploration_enemy_layer == null or not is_instance_valid(exploration_enemy_layer):
		return null
	var world_node: Node = exploration_enemy_layer.get_parent()
	if world_node == null or not is_instance_valid(world_node):
		return null
	return world_node.get_node_or_null("ConstructionPlaceables")


func _get_local_scavenge_nodes() -> Array:
	if get_local_scavenge_nodes_callback.is_valid():
		return Array(get_local_scavenge_nodes_callback.call())
	return []


func _cache_poi_definitions() -> void:
	_poi_definitions_by_id.clear()
	for definition_resource in poi_definitions:
		if definition_resource == null or definition_resource.get_script() != POI_DEFINITION_SCRIPT:
			continue
		if not definition_resource.is_valid_definition():
			continue
		for warning_text in definition_resource.get_bonus_table_alignment_warnings():
			push_warning(warning_text)
		_poi_definitions_by_id[definition_resource.poi_id] = definition_resource


func _get_poi_definition(poi_id: StringName):
	if not _poi_definitions_by_id.has(poi_id):
		return null
	return _poi_definitions_by_id[poi_id]


func _apply_poi_definition_to_scavenge_node(node) -> void:
	if node == null:
		return
	var poi_definition = _get_poi_definition(StringName(node.poi_id))
	if poi_definition == null:
		return
	if poi_definition.bonus_table != null:
		node.bonus_table = poi_definition.bonus_table


func _get_poi_id_for_world_poi_root(root: Node) -> StringName:
	if root == null or not is_instance_valid(root):
		return EMPTY_POI_ID
	for child in root.get_children():
		if child == null or not is_instance_valid(child):
			continue
		var raw_poi_id = child.get("poi_id")
		if raw_poi_id == null:
			continue
		var node_poi_id: StringName = raw_poi_id
		if node_poi_id != EMPTY_POI_ID:
			return node_poi_id
	return EMPTY_POI_ID


func _connect_poi_discovery_areas() -> void:
	if world_root == null or not is_instance_valid(world_root):
		return
	for poi_id_variant in _poi_visuals_by_id.keys():
		var poi_id := StringName(poi_id_variant)
		var visual_data: Dictionary = _poi_visuals_by_id.get(poi_id, {})
		var root: Node = visual_data.get("root")
		if root == null or not is_instance_valid(root):
			continue
		var discovery_area: Area2D = root.get_node_or_null("DiscoveryArea")
		if discovery_area == null:
			continue
		discovery_area.monitoring = true
		discovery_area.monitorable = true
		if not discovery_area.body_entered.is_connected(_on_poi_discovery_area_body_entered):
			discovery_area.body_entered.connect(_on_poi_discovery_area_body_entered.bind(poi_id))


func _on_poi_discovery_area_body_entered(body: Node, poi_id: StringName) -> void:
	if poi_id == EMPTY_POI_ID:
		return
	if player == null or not is_instance_valid(player):
		return
	if body != player:
		return
	_visited_poi_ids[poi_id] = true
	poi_discovered.emit(poi_id)


func _get_saved_daily_poi_events() -> Dictionary:
	var saved_events := {}
	for poi_id_variant in _daily_poi_events.keys():
		saved_events[String(poi_id_variant)] = String(_daily_poi_events[poi_id_variant])
	return saved_events


func _cache_poi_event_definitions() -> void:
	_poi_event_definitions_by_id.clear()
	for definition_resource in poi_event_definitions:
		if definition_resource == null or definition_resource.get_script() != POI_EVENT_DEFINITION_SCRIPT:
			continue
		if not definition_resource.is_valid_definition():
			continue
		_poi_event_definitions_by_id[definition_resource.event_id] = definition_resource


func _get_poi_event_definition(event_id: StringName):
	if not _poi_event_definitions_by_id.has(event_id):
		return null
	return _poi_event_definitions_by_id[event_id]


func _get_eligible_event_ids_for_poi(poi_id: StringName) -> Array[StringName]:
	var eligible: Array[StringName] = []
	var poi_definition = _get_poi_definition(poi_id)
	for event_id_variant in _poi_event_definitions_by_id.keys():
		var event_id := StringName(event_id_variant)
		var poi_event = _get_poi_event_definition(event_id)
		if poi_event == null:
			continue
		if not poi_event.eligible_poi_ids.is_empty() and not poi_event.eligible_poi_ids.has(poi_id):
			continue
		if poi_definition != null and not poi_event.eligible_reward_roles.is_empty() and not poi_event.eligible_reward_roles.has(poi_definition.reward_role):
			continue
		eligible.append(event_id)
	return eligible
