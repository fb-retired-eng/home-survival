extends Node
class_name GameEnemyRuntimeController

const ResourcePickupScene = preload("res://scenes/world/ResourcePickup.tscn")

var enemy: GameEnemy


func configure(enemy_ref: GameEnemy) -> void:
	enemy = enemy_ref


func refresh_player_reference() -> void:
	if enemy._player_ref != null and is_instance_valid(enemy._player_ref) and not enemy._player_ref.is_dead:
		return

	var candidate = enemy.get_tree().get_first_node_in_group("player")
	if candidate != null and is_instance_valid(candidate):
		enemy._player_ref = candidate


func get_live_player():
	refresh_player_reference()
	if enemy._player_ref == null or not is_instance_valid(enemy._player_ref) or enemy._player_ref.is_dead:
		return null
	return enemy._player_ref


func cache_runtime_context() -> void:
	if (enemy._enemy_layer_ref == null or not is_instance_valid(enemy._enemy_layer_ref)) and enemy.get_parent() != null and is_instance_valid(enemy.get_parent()):
		enemy._enemy_layer_ref = enemy.get_parent()
	if (enemy._placeables_root == null or not is_instance_valid(enemy._placeables_root)) and enemy._enemy_layer_ref != null and is_instance_valid(enemy._enemy_layer_ref):
		var world_root := enemy._enemy_layer_ref.get_parent()
		if world_root != null and is_instance_valid(world_root):
			enemy._placeables_root = world_root.get_node_or_null("ConstructionPlaceables")


func is_player_body_touching(player_target) -> bool:
	if player_target == null or not is_instance_valid(player_target):
		return false
	if enemy.body_touch_area == null:
		return false

	return enemy.body_touch_area.overlaps_body(player_target)


func get_runtime_placeables() -> Array:
	var placeables: Array = []
	if enemy._placeables_root == null or not is_instance_valid(enemy._placeables_root):
		return placeables
	for placeable in enemy._placeables_root.get_children():
		if placeable == null or not is_instance_valid(placeable):
			continue
		placeables.append(placeable)
	return placeables


func get_local_enemy_nodes() -> Array:
	var enemies: Array = []
	if enemy._enemy_layer_ref == null or not is_instance_valid(enemy._enemy_layer_ref):
		return enemies
	for other_enemy in enemy._enemy_layer_ref.get_children():
		if other_enemy == null or not is_instance_valid(other_enemy):
			continue
		enemies.append(other_enemy)
	return enemies


func spawn_death_drop() -> void:
	if enemy.definition == null:
		return

	var drop_parent: Node = enemy.get_parent()
	var scene_tree := enemy.get_tree()
	var current_scene := scene_tree.current_scene if scene_tree != null else null
	var world_node = current_scene.get_node_or_null("World") if current_scene != null else null
	if world_node != null:
		drop_parent = world_node

	if drop_parent == null:
		return

	var drop_entries: Array[Dictionary] = []
	var salvage_amount: int = maxi(int(enemy.definition.drop_salvage), 0)
	if salvage_amount > 0:
		if enemy.definition.bonus_salvage > 0 and randf() < enemy.definition.bonus_salvage_chance:
			salvage_amount += enemy.definition.bonus_salvage
		drop_entries.append({"resource_id": "salvage", "amount": salvage_amount})
	if enemy.definition.drop_parts > 0:
		drop_entries.append({"resource_id": "parts", "amount": enemy.definition.drop_parts})
	if enemy.definition.drop_bullets > 0:
		drop_entries.append({"resource_id": "bullets", "amount": enemy.definition.drop_bullets})
	if enemy.definition.drop_food > 0:
		drop_entries.append({"resource_id": "food", "amount": enemy.definition.drop_food})

	for drop_entry in drop_entries:
		var pickup = ResourcePickupScene.instantiate()
		pickup.resource_id = String(drop_entry.get("resource_id", "salvage"))
		pickup.amount = int(drop_entry.get("amount", 1))
		drop_parent.add_child(pickup)
		pickup.global_position = enemy.global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0))

	if enemy.definition.is_elite and enemy.definition.weapon_drop != null and enemy.definition.weapon_drop_chance > 0.0 and randf() <= enemy.definition.weapon_drop_chance:
		var weapon_pickup = ResourcePickupScene.instantiate()
		weapon_pickup.is_weapon_drop = true
		weapon_pickup.weapon_reward = enemy.definition.weapon_drop
		drop_parent.add_child(weapon_pickup)
		weapon_pickup.global_position = enemy.global_position + Vector2(0.0, -14.0)
