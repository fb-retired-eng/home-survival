extends Area2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func get_interaction_label(player) -> String:
	var socket := get_parent()
	if socket != null and socket.has_method("get_interaction_label"):
		return str(socket.get_interaction_label(player))
	return ""


func can_interact(player) -> bool:
	var socket := get_parent()
	return socket != null and socket.has_method("can_interact") and bool(socket.can_interact(player))


func interact(player) -> void:
	var socket := get_parent()
	if socket != null and socket.has_method("interact"):
		socket.interact(player)


func get_interaction_priority(player) -> int:
	var socket := get_parent()
	if socket != null and socket.has_method("get_interaction_priority"):
		return int(socket.get_interaction_priority(player))
	return 0


func is_direct_interactable() -> bool:
	return true


func _on_body_entered(body) -> void:
	if body == null or not body.is_in_group("player"):
		return

	var socket := get_parent()
	if socket != null and socket.has_method("set_context_label_visible"):
		socket.set_context_label_visible(true)


func _on_body_exited(body) -> void:
	if body == null or not body.is_in_group("player"):
		return

	var socket := get_parent()
	if socket != null and socket.has_method("set_context_label_visible"):
		socket.set_context_label_visible(false)
