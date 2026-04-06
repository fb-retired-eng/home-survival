extends Node
class_name Mvp2RunController

const DAILY_MUTATOR_DEFINITION_SCRIPT := preload("res://scripts/data/daily_mutator_definition.gd")

signal autosave_requested

var game_manager
var player
var hud
var poi_controller
var patrol_director
var wave_manager
var defense_sockets

var daily_mutator_definitions: Array[Resource] = []

var active_mutator_id: StringName = StringName()
var _mutators_by_id: Dictionary = {}
var _daily_contracts: Array[Dictionary] = []
var _wave_breach_this_night: bool = false


func configure(config: Dictionary) -> void:
	game_manager = config.get("game_manager")
	player = config.get("player")
	hud = config.get("hud")
	poi_controller = config.get("poi_controller")
	patrol_director = config.get("patrol_director")
	wave_manager = config.get("wave_manager")
	defense_sockets = config.get("defense_sockets")
	daily_mutator_definitions = config.get("daily_mutator_definitions", [])
	_cache_mutators()


func reset_for_new_run() -> void:
	active_mutator_id = StringName()
	_daily_contracts.clear()
	_wave_breach_this_night = false


func generate_day_state() -> void:
	_roll_daily_mutator()
	if patrol_director != null and is_instance_valid(patrol_director):
		patrol_director.set_active_mutator(get_active_mutator())
	_generate_daily_contracts()


func get_save_state_fragment() -> Dictionary:
	return {
		"active_mutator_id": String(active_mutator_id),
		"daily_contracts": _daily_contracts.duplicate(true),
	}


func apply_save_state_fragment(save_state: Dictionary) -> void:
	active_mutator_id = StringName(save_state.get("active_mutator_id", ""))
	_daily_contracts.clear()
	for raw_contract in save_state.get("daily_contracts", []):
		_daily_contracts.append(Dictionary(raw_contract))
	if patrol_director != null and is_instance_valid(patrol_director):
		patrol_director.set_active_mutator(get_active_mutator())


func on_run_state_changed(new_state: int) -> void:
	if game_manager == null:
		return
	if new_state == game_manager.RunState.ACTIVE_WAVE:
		_wave_breach_this_night = false
	if new_state == game_manager.RunState.POST_WAVE:
		_mark_survive_without_breach_contract()


func on_defense_socket_state_changed(socket) -> void:
	if socket == null or not is_instance_valid(socket):
		return
	if socket.has_method("is_breached") and socket.is_breached():
		_wave_breach_this_night = true


func on_poi_discovered(poi_id: StringName) -> void:
	for contract in _daily_contracts:
		if StringName(contract.get("type", "")) != &"visit_poi":
			continue
		if StringName(contract.get("target_poi_id", "")) != poi_id:
			continue
		contract["completed"] = true


func on_patrol_enemy_defeated() -> void:
	for contract in _daily_contracts:
		if StringName(contract.get("type", "")) != &"defeat_patrol":
			continue
		var progress: int = int(contract.get("progress", 0)) + 1
		var required: int = int(contract.get("required", 1))
		contract["progress"] = progress
		if progress >= required:
			contract["completed"] = true


func can_player_access_contract_board(_player_ref) -> bool:
	return game_manager != null and (
		int(game_manager.run_state) == int(game_manager.RunState.PRE_WAVE)
		or int(game_manager.run_state) == int(game_manager.RunState.POST_WAVE)
	)


func get_contract_board_label(_player_ref) -> String:
	var claimable := _get_claimable_contract()
	if not claimable.is_empty():
		return "Claim Contract Reward"
	if _daily_contracts.is_empty():
		return "Check Board"
	return "Check Contracts"


func on_contract_board_requested(_player_ref) -> void:
	var claimable := _get_claimable_contract()
	if not claimable.is_empty():
		_claim_contract_reward(claimable)
		autosave_requested.emit()
		return
	if hud != null and is_instance_valid(hud):
		hud.set_status(get_contract_summary_text())


func get_contract_summary_text() -> String:
	var parts: Array[String] = []
	if get_active_mutator() != null:
		parts.append("Mutator: %s." % String(get_active_mutator().display_name))
	for contract in _daily_contracts:
		var reward: Dictionary = contract.get("reward", {})
		var reward_text := _format_reward(reward)
		var status := "pending"
		if bool(contract.get("claimed", false)):
			status = "claimed"
		elif bool(contract.get("completed", false)):
			status = "ready"
		parts.append("%s [%s] -> %s" % [String(contract.get("label", "Contract")), status, reward_text])
	return " ".join(parts)


func get_daily_contracts() -> Array[Dictionary]:
	var contracts: Array[Dictionary] = []
	for contract in _daily_contracts:
		contracts.append(Dictionary(contract))
	return contracts


func get_active_mutator():
	return _mutators_by_id.get(active_mutator_id)


func get_mutator_poi_guard_bonus() -> int:
	var mutator = get_active_mutator()
	return int(mutator.poi_guard_bonus) if mutator != null else 0


func get_mutator_salvage_bonus() -> int:
	var mutator = get_active_mutator()
	return int(mutator.salvage_bonus) if mutator != null else 0


func get_mutator_floodlight_slow_bonus() -> float:
	var mutator = get_active_mutator()
	return float(mutator.floodlight_slow_bonus) if mutator != null else 0.0


func get_mutator_enemy_speed_multiplier() -> float:
	var mutator = get_active_mutator()
	return 1.0 + float(mutator.enemy_speed_multiplier_bonus) if mutator != null else 1.0


func _cache_mutators() -> void:
	_mutators_by_id.clear()
	for definition in daily_mutator_definitions:
		if definition == null or definition.get_script() != DAILY_MUTATOR_DEFINITION_SCRIPT:
			continue
		if not definition.is_valid_definition():
			continue
		_mutators_by_id[StringName(definition.mutator_id)] = definition


func _roll_daily_mutator() -> void:
	var mutator_ids: Array = _mutators_by_id.keys()
	if mutator_ids.is_empty():
		active_mutator_id = StringName()
		return
	active_mutator_id = StringName(mutator_ids[randi() % mutator_ids.size()])


func _generate_daily_contracts() -> void:
	_daily_contracts.clear()
	var visit_poi_id := _choose_contract_poi()
	if visit_poi_id != StringName():
		_daily_contracts.append({
			"type": &"visit_poi",
			"label": "Visit %s" % poi_controller.get_poi_display_name(visit_poi_id),
			"target_poi_id": visit_poi_id,
			"completed": false,
			"claimed": false,
			"reward": {"salvage": 4, "parts": 1},
		})
	_daily_contracts.append({
		"type": &"defeat_patrol",
		"label": "Defeat 1 patrol",
		"required": 1,
		"progress": 0,
		"completed": false,
		"claimed": false,
		"reward": {"battery": 1},
	})
	_daily_contracts.append({
		"type": &"survive_without_breach",
		"label": "Survive the night without a breach",
		"completed": false,
		"claimed": false,
		"reward": {"parts": 2, "salvage": 3},
	})


func _choose_contract_poi() -> StringName:
	if poi_controller == null or not is_instance_valid(poi_controller):
		return StringName()
	var poi_ids: Array[StringName] = poi_controller.get_all_poi_ids()
	var best_score := -INF
	var best_candidates: Array[StringName] = []
	for poi_id in poi_ids:
		if poi_controller.has_method("is_poi_depleted") and bool(poi_controller.is_poi_depleted(poi_id)):
			continue
		var score := _score_contract_poi(poi_id)
		if score > best_score:
			best_score = score
			best_candidates = [poi_id]
		elif is_equal_approx(score, best_score):
			best_candidates.append(poi_id)
	if best_candidates.is_empty():
		return StringName()
	return best_candidates[randi() % best_candidates.size()]


func _score_contract_poi(poi_id: StringName) -> float:
	var score := 0.0
	if poi_controller.is_poi_known(poi_id):
		score += 2.0
	if poi_controller.get_daily_poi_event(poi_id) != StringName():
		score += 3.0
	var modifier_id: StringName = poi_controller.get_daily_poi_modifier(poi_id)
	if modifier_id == &"disturbed" or modifier_id == &"elite_present":
		score += 1.5
	elif modifier_id != StringName():
		score += 0.5
	score += randf() * 0.25
	return score


func _mark_survive_without_breach_contract() -> void:
	if _wave_breach_this_night:
		return
	for contract in _daily_contracts:
		if StringName(contract.get("type", "")) == &"survive_without_breach":
			contract["completed"] = true


func _get_claimable_contract() -> Dictionary:
	for contract in _daily_contracts:
		if bool(contract.get("completed", false)) and not bool(contract.get("claimed", false)):
			return contract
	return {}


func _claim_contract_reward(contract: Dictionary) -> void:
	if player == null or not is_instance_valid(player):
		return
	var reward: Dictionary = contract.get("reward", {})
	for resource_id in reward.keys():
		var amount := int(reward.get(resource_id, 0))
		if amount > 0:
			player.add_resource(String(resource_id), amount, false)
	contract["claimed"] = true
	if hud != null and is_instance_valid(hud):
		hud.set_status("Contract claimed: %s" % String(contract.get("label", "Contract")))


func _format_reward(reward: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in ["salvage", "parts", "battery"]:
		var amount := int(reward.get(resource_id, 0))
		if amount > 0:
			parts.append("%d %s" % [amount, resource_id])
	return ", ".join(parts)
