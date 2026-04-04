extends Node
class_name RunPhaseController

signal autosave_requested

var game_manager
var player
var hud
var wave_manager
var exploration_controller
var poi_controller
var construction_controller
var mvp1_run_controller
var food_energy_per_unit: int = 25
var sleep_heal_amount: int = 25


func configure(config: Dictionary) -> void:
	game_manager = config.get("game_manager")
	player = config.get("player")
	hud = config.get("hud")
	wave_manager = config.get("wave_manager")
	exploration_controller = config.get("exploration_controller")
	poi_controller = config.get("poi_controller")
	construction_controller = config.get("construction_controller")
	mvp1_run_controller = config.get("mvp1_run_controller")
	food_energy_per_unit = int(config.get("food_energy_per_unit", food_energy_per_unit))
	sleep_heal_amount = int(config.get("sleep_heal_amount", sleep_heal_amount))


func can_player_eat(_player) -> bool:
	return game_manager.run_state == game_manager.RunState.PRE_WAVE and game_manager.can_start_next_wave()


func get_food_table_label(_player) -> String:
	if game_manager.run_state != game_manager.RunState.PRE_WAVE:
		return ""

	var next_wave: int = game_manager.current_wave + 1
	if not game_manager.can_start_next_wave():
		return ""
	if exploration_controller.has_sleep_blocking_exploration_threat():
		return "Enemies too close for dinner"
	if not wave_manager.can_start_wave(next_wave):
		return "Night %d not configured" % next_wave

	var food_needed := _get_missing_food_units_for_full_energy()
	if food_needed <= 0:
		return "Eat dinner to start night %d" % next_wave

	var current_food := int(player.resources.get("food", 0))
	if current_food < food_needed:
		return "Need %d food for dinner" % food_needed

	return "Eat %d food and start night %d" % [food_needed, next_wave]


func can_player_sleep(_player) -> bool:
	return game_manager.run_state == game_manager.RunState.POST_WAVE


func get_sleep_label(_player) -> String:
	if game_manager.run_state != game_manager.RunState.POST_WAVE:
		return ""
	return "Sleep on bed until morning"


func can_player_upgrade_generator(player_ref) -> bool:
	return mvp1_run_controller.can_player_upgrade_generator(player_ref)


func get_generator_label(player_ref) -> String:
	return mvp1_run_controller.get_generator_label(player_ref)


func on_food_table_requested(_player) -> void:
	var next_wave: int = game_manager.current_wave + 1
	if game_manager.run_state != game_manager.RunState.PRE_WAVE or not game_manager.can_start_next_wave():
		return
	if exploration_controller.has_sleep_blocking_exploration_threat():
		hud.set_status("Enemies too close for dinner")
		player.refresh_interaction_prompt()
		return
	if not wave_manager.can_start_wave(next_wave):
		hud.set_status("Night %d is not configured" % next_wave)
		player.refresh_interaction_prompt()
		return

	var food_needed := _get_missing_food_units_for_full_energy()
	if food_needed > 0:
		if int(player.resources.get("food", 0)) < food_needed:
			hud.set_status("Need %d food for dinner" % food_needed)
			player.refresh_interaction_prompt()
			return
		if not player.spend_resource("food", food_needed):
			hud.set_status("Not enough food")
			player.refresh_interaction_prompt()
			return
		player.restore_full_energy()

	if not wave_manager.start_wave(next_wave):
		if food_needed > 0:
			player.add_resource("food", food_needed, false)
		hud.set_status("Night %d failed to start" % next_wave)
		player.refresh_interaction_prompt()
		return

	game_manager.set_wave(next_wave)
	game_manager.set_run_state(game_manager.RunState.ACTIVE_WAVE)


func on_generator_upgrade_requested(player_ref) -> void:
	if mvp1_run_controller.on_generator_upgrade_requested(player_ref):
		autosave_requested.emit()


func on_sleep_requested(_player) -> void:
	if game_manager.run_state != game_manager.RunState.POST_WAVE:
		return

	player.heal(sleep_heal_amount)
	game_manager.set_run_state(game_manager.RunState.PRE_WAVE)


func on_wave_started(wave_number: int) -> void:
	hud.set_phase("Phase: Night")
	hud.set_status("Night %d incoming. Hold the perimeter." % wave_number)


func on_wave_cleared(_wave_number: int) -> void:
	game_manager.complete_active_wave()


func refresh_phase_status() -> void:
	if player != null and is_instance_valid(player) and player.is_build_mode_active():
		construction_controller.refresh_build_mode_status()
		return
	var base_status := ""
	match game_manager.run_state:
		game_manager.RunState.PRE_WAVE:
			if game_manager.current_wave <= 0:
				base_status = "Day 1. Scavenge carefully, build up, and eat dinner at the table to start night 1."
			elif game_manager.current_wave < game_manager.final_wave - 1:
				base_status = "Day %d. Explore, build, and eat dinner at the table to start night %d." % [game_manager.current_wave + 1, game_manager.current_wave + 1]
			else:
				base_status = "Final day. Make repairs, gather food, and eat dinner before the last night."
		game_manager.RunState.ACTIVE_WAVE:
			base_status = "Night %d in progress. Hold the base." % game_manager.current_wave
		game_manager.RunState.POST_WAVE:
			base_status = "Night %d cleared. Sleep on the bed to start the next day." % game_manager.current_wave
		_:
			return

	var modifier_summary := ""
	if poi_controller != null and is_instance_valid(poi_controller):
		modifier_summary = poi_controller.get_daily_modifier_summary()
	hud.set_status(base_status if modifier_summary.is_empty() else "%s %s" % [base_status, modifier_summary])


func _get_missing_food_units_for_full_energy() -> int:
	var missing_energy: int = maxi(int(player.max_energy) - int(player.current_energy), 0)
	if missing_energy <= 0:
		return 0
	return int(ceili(float(missing_energy) / float(max(food_energy_per_unit, 1))))
