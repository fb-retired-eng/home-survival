extends SceneTree


func _init() -> void:
	var game_scene := load("res://scenes/main/Game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var player = game.player
	var player_audio = player.get_node("CombatAudio")
	var knife := load("res://data/weapons/kitchen_knife.tres")
	player.equip_weapon(knife, false)
	player._play_attack_effect(knife, {
		"end_point": player.global_position + Vector2(0.0, -24.0),
		"impact_kind": "miss",
	})
	await process_frame
	print("combat_audio_probe_player_attack=%s" % str(player_audio.get_last_sound_id()))
	print("combat_audio_probe_player_miss_history=%s" % ",".join(player_audio.get_recent_sound_ids()))

	player.obtain_weapon(load("res://data/weapons/pistol.tres"), true, false)
	player._play_attack_effect(player._get_equipped_weapon(), {
		"end_point": player.global_position + Vector2(0.0, -48.0),
		"impact_kind": "enemy",
	})
	await process_frame
	print("combat_audio_probe_player_hit_history=%s" % ",".join(player_audio.get_recent_sound_ids()))

	var pistol := load("res://data/weapons/pistol.tres")
	player.obtain_weapon(pistol, true, false)
	player.resources["bullets"] = 6
	player._set_weapon_magazine_ammo(pistol, 0)
	player._begin_reload(pistol, false)
	await process_frame
	print("combat_audio_probe_reload_start=%s" % str(player_audio.get_last_sound_id()))
	player._complete_reload()
	await process_frame
	print("combat_audio_probe_reload_done=%s" % str(player_audio.get_last_sound_id()))

	player.take_damage(5, {"attacker": null})
	await process_frame
	print("combat_audio_probe_player_hurt=%s" % str(player_audio.get_last_sound_id()))

	var zombie_scene := load("res://scenes/enemies/Zombie.tscn")
	var hurt_zombie = zombie_scene.instantiate()
	game.exploration_enemy_layer.add_child(hurt_zombie)
	hurt_zombie.global_position = player.global_position + Vector2(0.0, 12.0)
	hurt_zombie.configure_exploration_context(player, Vector2.DOWN, true, hurt_zombie.global_position, true)
	await process_frame

	var zombie_audio = hurt_zombie.get_node("CombatAudio")
	hurt_zombie.take_damage(1, {"attacker": player})
	await process_frame
	print("combat_audio_probe_zombie_hurt=%s" % str(zombie_audio.get_last_sound_id()))

	var attack_zombie = zombie_scene.instantiate()
	game.exploration_enemy_layer.add_child(attack_zombie)
	attack_zombie.global_position = player.global_position + Vector2(0.0, 12.0)
	attack_zombie.configure_exploration_context(player, Vector2.DOWN, true, attack_zombie.global_position, true)
	attack_zombie.attack_range_override = 24.0
	await process_frame

	var attack_zombie_audio = attack_zombie.get_node("CombatAudio")
	attack_zombie._update_facing_direction(player.global_position - attack_zombie.global_position)
	attack_zombie._process_attack_prep(player)
	await process_frame
	print("combat_audio_probe_zombie_tell=%s" % str(attack_zombie_audio.get_last_sound_id()))

	attack_zombie._update_facing_direction(player.global_position - attack_zombie.global_position)
	attack_zombie._try_damage_target(player)
	await process_frame
	print("combat_audio_probe_zombie_hit=%s" % str(attack_zombie_audio.get_last_sound_id()))

	var socket = game.defense_sockets.get_child(0)
	var socket_audio = socket.get_node("CombatAudio")
	socket.take_damage(10, {"attacker": attack_zombie, "damage_type": &"impact"})
	await process_frame
	print("combat_audio_probe_structure_hit=%s" % str(socket_audio.get_last_sound_id()))

	quit()
