extends SceneTree


func _spawn_enemy(root_node: Node, definition_path: String, position: Vector2):
	var zombie_scene = load("res://scenes/enemies/Zombie.tscn")
	var enemy = zombie_scene.instantiate()
	enemy.definition = load(definition_path)
	root_node.add_child(enemy)
	enemy.global_position = position
	return enemy


func _wait_frames() -> void:
	await process_frame
	await physics_frame
	await process_frame


func _init() -> void:
	var basic_enemy = _spawn_enemy(root, "res://data/enemies/zombie_basic.tres", Vector2(120, 120))
	var elite_enemy = _spawn_enemy(root, "res://data/enemies/zombie_elite_brute.tres", Vector2(180, 120))
	await _wait_frames()

	var basic_aura: Polygon2D = basic_enemy.get_node("EliteAura")
	var elite_aura: Polygon2D = elite_enemy.get_node("EliteAura")
	var basic_marker: Polygon2D = basic_enemy.get_node("FacingMarker")
	var elite_marker: Polygon2D = elite_enemy.get_node("FacingMarker")

	print("elite_visual_probe_basic_aura_visible=%s" % str(basic_aura.visible))
	print("elite_visual_probe_elite_aura_visible=%s" % str(elite_aura.visible))
	print("elite_visual_probe_basic_marker_color=%s" % str(basic_marker.color))
	print("elite_visual_probe_elite_marker_color=%s" % str(elite_marker.color))
	quit()
