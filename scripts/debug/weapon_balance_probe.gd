extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")

const WEAPON_CASES := [
	{
		"id": "kitchen_knife",
		"path": "res://data/weapons/kitchen_knife.tres",
		"distance": 24.0,
	},
	{
		"id": "baseball_bat",
		"path": "res://data/weapons/baseball_bat.tres",
		"distance": 38.0,
	},
	{
		"id": "pistol",
		"path": "res://data/weapons/pistol.tres",
		"distance": 120.0,
		"reserve_bullets": 24,
	},
	{
		"id": "shotgun",
		"path": "res://data/weapons/shotgun.tres",
		"distance": 88.0,
		"reserve_bullets": 12,
	},
]

const ENEMY_CASES := [
	{
		"id": "basic",
		"path": "res://data/enemies/zombie_basic.tres",
	},
	{
		"id": "runner",
		"path": "res://data/enemies/zombie_runner.tres",
	},
	{
		"id": "brute",
		"path": "res://data/enemies/zombie_brute.tres",
	},
]


func _wait_step() -> void:
	await process_frame
	await physics_frame


func _wait_frames(count: int = 1) -> void:
	for _i in range(count):
		await _wait_step()


func _spawn_player() -> Node:
	var player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	return player


func _spawn_enemy(definition_path: String, position: Vector2, player) -> Node:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.definition = load(definition_path)
	root.add_child(enemy)
	enemy.global_position = position
	enemy.configure_exploration_context(player, Vector2.DOWN, true, position, true)
	return enemy


func _get_total_bullets(player, weapon: Resource) -> int:
	if weapon == null or not player._uses_weapon_magazine(weapon):
		return 0
	return int(player.resources.get("bullets", 0)) + int(player._get_weapon_magazine_ammo(weapon))


func _wait_for_attack_resolution(player, timeout_steps: int = 240) -> bool:
	for _step in range(timeout_steps):
		await _wait_step()
		if not player._attack_windup_pending and player.attack_cooldown_remaining > 0.0:
			return true
	return false


func _measure_weapon_against_enemy(weapon_case: Dictionary, enemy_case: Dictionary) -> Dictionary:
	var player = _spawn_player()
	await _wait_frames(2)

	var weapon: Resource = load(String(weapon_case.path))
	player.obtain_weapon(weapon, true, false)
	player.current_energy = player.max_energy
	if int(weapon_case.get("reserve_bullets", 0)) > 0:
		player.resources["bullets"] = int(weapon_case.reserve_bullets)
		player._set_weapon_magazine_ammo(weapon, int(weapon.magazine_size))

	player.global_position = Vector2(200.0, 200.0)
	player.facing_direction = Vector2.RIGHT
	player._update_facing_visuals()

	var enemy_distance: float = float(weapon_case.distance)
	var enemy = _spawn_enemy(String(enemy_case.path), player.global_position + Vector2(enemy_distance, 0.0), player)
	await _wait_frames(3)

	var elapsed: float = 0.0
	var shots_or_swings: int = 0
	var ammo_before: int = _get_total_bullets(player, weapon)
	var attack_timeout := false

	for _attempt in range(24):
		if enemy == null or not is_instance_valid(enemy) or enemy.current_health <= 0:
			break
		player._attempt_attack()
		var resolved := await _wait_for_attack_resolution(player)
		if not resolved:
			attack_timeout = true
			break
		shots_or_swings += 1
		elapsed += maxf(float(weapon.attack_windup) + float(weapon.attack_cooldown), 0.01)
		for _cooldown_step in range(240):
			await _wait_step()
			if player.attack_cooldown_remaining <= 0.0 and not player._attack_windup_pending:
				break

	var enemy_alive: bool = enemy != null and is_instance_valid(enemy) and enemy.current_health > 0
	var ammo_after: int = _get_total_bullets(player, weapon)
	var ammo_used: int = max(ammo_before - ammo_after, 0)

	if enemy != null and is_instance_valid(enemy):
		enemy.queue_free()
	if player != null and is_instance_valid(player):
		player.queue_free()
	await _wait_frames(2)

	return {
		"weapon_id": String(weapon_case.id),
		"enemy_id": String(enemy_case.id),
		"defeated": not enemy_alive and not attack_timeout,
		"shots": shots_or_swings,
		"time": elapsed,
		"ammo_used": ammo_used,
	}


func _init() -> void:
	for weapon_case in WEAPON_CASES:
		for enemy_case in ENEMY_CASES:
			var result: Dictionary = await _measure_weapon_against_enemy(weapon_case, enemy_case)
			print(
				"weapon_balance_probe_%s_vs_%s=defeated:%s,shots:%d,time:%.2f,ammo:%d" % [
					result.weapon_id,
					result.enemy_id,
					str(result.defeated),
					int(result.shots),
					float(result.time),
					int(result.ammo_used),
				]
			)
	quit()
