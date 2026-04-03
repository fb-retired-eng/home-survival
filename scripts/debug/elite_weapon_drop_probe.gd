extends SceneTree


func _count_weapon_pickups(root_node: Node) -> int:
	var count := 0
	for child in root_node.get_children():
		if not is_instance_valid(child):
			continue
		if not child.is_in_group("pickups"):
			continue
		if bool(child.get("is_weapon_drop")):
			count += 1
	return count


func _init() -> void:
	var enemy_scene := load("res://scenes/enemies/Enemy.tscn")
	var pistol := load("res://data/weapons/pistol.tres")
	var base_definition := load("res://data/enemies/zombie_spitter.tres")
	var non_elite_definition = base_definition.duplicate(true)
	non_elite_definition.enemy_id = &"probe_non_elite"
	non_elite_definition.is_elite = false
	non_elite_definition.weapon_drop = pistol
	non_elite_definition.weapon_drop_chance = 1.0

	var root_node := Node2D.new()
	var world_node := Node2D.new()
	world_node.name = "World"
	root.add_child(root_node)
	root_node.add_child(world_node)
	current_scene = root_node

	var zombie = enemy_scene.instantiate()
	root_node.add_child(zombie)
	zombie.definition = non_elite_definition
	await process_frame

	zombie._spawn_death_drop()
	await process_frame

	print("elite_weapon_drop_probe_weapon_pickups=%d" % _count_weapon_pickups(world_node))
	quit()
