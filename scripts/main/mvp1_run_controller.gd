extends Node
class_name Mvp1RunController

const LEGACY_PERK_DEFINITION_SCRIPT := preload("res://scripts/data/legacy_perk_definition.gd")

var game_manager
var player
var hud
var generator_point
var power_manager
var dog
var defense_sockets
var legacy_perk_definitions: Array[Resource] = []
var legacy_perk_id: String = "max_energy"

var _active_heirloom_socket_ids: Dictionary = {}
var _pending_heirloom_socket_ids: Dictionary = {}
var _last_terminal_run_state: int = -1
var _legacy_perk_definitions_by_id: Dictionary = {}


func configure(config: Dictionary) -> void:
	game_manager = config.get("game_manager")
	player = config.get("player")
	hud = config.get("hud")
	generator_point = config.get("generator_point")
	power_manager = config.get("power_manager")
	dog = config.get("dog")
	defense_sockets = config.get("defense_sockets")
	legacy_perk_definitions = config.get("legacy_perk_definitions", [])
	legacy_perk_id = String(config.get("legacy_perk_id", legacy_perk_id))
	_cache_legacy_perk_definitions()


func set_legacy_perk_id(perk_id: String) -> void:
	legacy_perk_id = perk_id


func get_active_heirloom_socket_ids() -> Dictionary:
	return _active_heirloom_socket_ids


func get_pending_heirloom_socket_ids() -> Dictionary:
	return _pending_heirloom_socket_ids


func get_last_terminal_run_state() -> int:
	return _last_terminal_run_state


func get_save_state_fragment() -> Dictionary:
	return {
		"legacy_perk_id": legacy_perk_id,
		"heirlooms": {
			"active_socket_ids": _get_saved_socket_ids(_active_heirloom_socket_ids),
			"pending_socket_ids": _get_saved_socket_ids(_pending_heirloom_socket_ids),
			"last_terminal_run_state": _last_terminal_run_state,
		},
	}


func apply_save_state_fragment(save_state: Dictionary) -> void:
	legacy_perk_id = String(save_state.get("legacy_perk_id", legacy_perk_id))
	apply_legacy_perk_baseline(false)
	var heirloom_state: Dictionary = save_state.get("heirlooms", {})
	_active_heirloom_socket_ids = _restore_socket_id_dictionary(heirloom_state.get("active_socket_ids", []))
	_pending_heirloom_socket_ids = _restore_socket_id_dictionary(heirloom_state.get("pending_socket_ids", []))
	_last_terminal_run_state = int(heirloom_state.get("last_terminal_run_state", -1))


func on_run_state_changed(new_state: int) -> void:
	if game_manager == null:
		return
	if new_state == game_manager.RunState.LOSS or new_state == game_manager.RunState.WIN:
		_last_terminal_run_state = new_state


func reset_for_new_run() -> void:
	if game_manager != null and _last_terminal_run_state == game_manager.RunState.LOSS:
		_active_heirloom_socket_ids = _pending_heirloom_socket_ids.duplicate(true)
	else:
		_active_heirloom_socket_ids.clear()
	_pending_heirloom_socket_ids.clear()
	_last_terminal_run_state = -1
	apply_legacy_perk_baseline()


func on_defense_socket_state_changed(socket) -> void:
	if socket == null or not is_instance_valid(socket):
		return
	var socket_id: StringName = StringName(socket.socket_id)
	if socket_id == StringName():
		return
	if socket.has_method("is_breached") and socket.is_breached() and String(socket.tier) == "fortified":
		_pending_heirloom_socket_ids[socket_id] = true


func apply_heirloom_socket_state() -> void:
	if defense_sockets == null or not is_instance_valid(defense_sockets):
		return
	for socket in defense_sockets.get_children():
		if socket == null or not is_instance_valid(socket) or not socket.has_method("set_heirloom_debris_active"):
			continue
		socket.set_heirloom_debris_active(bool(_active_heirloom_socket_ids.get(StringName(socket.socket_id), false)))


func can_player_upgrade_generator(player_ref) -> bool:
	if game_manager == null or int(game_manager.run_state) != int(game_manager.RunState.PRE_WAVE):
		return false
	return power_manager != null and is_instance_valid(power_manager) and power_manager.can_upgrade_generator(player_ref)


func get_generator_label(player_ref) -> String:
	if game_manager == null or int(game_manager.run_state) != int(game_manager.RunState.PRE_WAVE):
		return ""
	if power_manager == null or not is_instance_valid(power_manager):
		return ""
	return power_manager.get_generator_interaction_label(player_ref)


func on_generator_upgrade_requested(player_ref) -> bool:
	if power_manager == null or not is_instance_valid(power_manager):
		return false
	if power_manager.upgrade_generator(player_ref):
		if hud != null and is_instance_valid(hud):
			hud.set_status("Generator upgraded")
		if player != null and is_instance_valid(player):
			player.refresh_interaction_prompt()
		return true
	if hud != null and is_instance_valid(hud):
		hud.set_status(power_manager.get_generator_interaction_label(player_ref))
	if player != null and is_instance_valid(player):
		player.refresh_interaction_prompt()
	return false


func on_player_dog_command_requested() -> void:
	if dog == null or not is_instance_valid(dog):
		return
	var target_position: Variant = null
	if player != null and is_instance_valid(player) and game_manager != null and int(game_manager.run_state) == int(game_manager.RunState.ACTIVE_WAVE):
		target_position = player.get_global_mouse_position()
	dog.issue_context_command(target_position)


func apply_legacy_perk_baseline(include_inventory_grants: bool = true) -> void:
	if player == null or not is_instance_valid(player):
		return
	var definition = _get_legacy_perk_definition(StringName(legacy_perk_id))
	player.max_energy = 100
	player.current_energy = min(player.current_energy, player.max_energy)
	if dog != null and is_instance_valid(dog):
		dog.max_stamina = 100
		dog.current_stamina = min(dog.current_stamina, dog.max_stamina)
	if definition != null:
		player.max_energy = 100 + int(definition.max_energy_bonus)
		if include_inventory_grants:
			player.current_energy = player.max_energy
		if include_inventory_grants and int(definition.stash_battery_bonus) > 0:
			player.add_resource("battery", int(definition.stash_battery_bonus), false)
		if include_inventory_grants and int(definition.stash_bullets_bonus) > 0:
			player.add_resource("bullets", int(definition.stash_bullets_bonus), false)
		if dog != null and is_instance_valid(dog):
			dog.max_stamina = 100 + int(definition.dog_max_stamina_bonus)
			if include_inventory_grants:
				dog.current_stamina = dog.max_stamina
	player.energy_changed.emit(player.current_energy, player.max_energy)
	if dog != null and is_instance_valid(dog):
		dog.status_changed.emit(dog._build_status_text())


func _cache_legacy_perk_definitions() -> void:
	_legacy_perk_definitions_by_id.clear()
	for definition in legacy_perk_definitions:
		if definition == null or definition.get_script() != LEGACY_PERK_DEFINITION_SCRIPT:
			continue
		if not definition.is_valid_definition():
			continue
		_legacy_perk_definitions_by_id[StringName(definition.perk_id)] = definition


func _get_legacy_perk_definition(perk_id: StringName):
	if perk_id == StringName():
		return null
	return _legacy_perk_definitions_by_id.get(perk_id)


func _get_saved_socket_ids(source: Dictionary) -> Array[String]:
	var saved_ids: Array[String] = []
	for socket_id_variant in source.keys():
		var socket_id := StringName(socket_id_variant)
		if bool(source.get(socket_id, false)):
			saved_ids.append(String(socket_id))
	return saved_ids


func _restore_socket_id_dictionary(raw_ids: Array) -> Dictionary:
	var restored: Dictionary = {}
	for raw_socket_id in raw_ids:
		var socket_id := StringName(raw_socket_id)
		if socket_id == StringName():
			continue
		restored[socket_id] = true
	return restored
