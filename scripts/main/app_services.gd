extends RefCounted
class_name AppServices

const SETTINGS_STORE_PATH := NodePath("/root/SettingsStore")
const SAVE_STORE_PATH := NodePath("/root/SaveStore")


static func get_settings_store(tree: SceneTree) -> Node:
	if tree == null:
		return null
	return tree.root.get_node_or_null(SETTINGS_STORE_PATH)


static func get_save_store(tree: SceneTree) -> Node:
	if tree == null:
		return null
	return tree.root.get_node_or_null(SAVE_STORE_PATH)
