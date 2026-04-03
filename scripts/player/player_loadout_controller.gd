extends Node
class_name PlayerLoadoutController

const RESOURCE_IDS := ["salvage", "parts", "medicine", "bullets", "food"]
const WEAPON_DEFINITION_SCRIPT := preload("res://scripts/data/weapon_definition.gd")
const DEFAULT_WEAPON_RESOURCE := preload("res://data/weapons/kitchen_knife.tres")

signal message_requested(text: String)
signal resources_changed(resources: Dictionary)
signal equipped_weapon_resource_changed(weapon: Resource)
signal weapon_changed(display_name: String, weapon_id: StringName)
signal weapon_status_changed(text: String)
signal weapon_trait_changed(text: String)

var resources: Dictionary = {
	"salvage": 0,
	"parts": 0,
	"medicine": 0,
	"bullets": 0,
	"food": 0,
}

var _equipped_weapon: Resource
var _starting_weapon: Resource
var _obtained_weapons: Array[Resource] = []
var _magazine_ammo_by_weapon_id: Dictionary = {}
var _reload_time_remaining: float = 0.0
var _reload_weapon_id: StringName = StringName()
var _invalid_weapon_warning_emitted: bool = false


func configure(starting_weapon: Resource) -> void:
	_starting_weapon = _resolve_valid_weapon_resource(starting_weapon)
	_equipped_weapon = _starting_weapon
	_obtained_weapons.clear()
	if _starting_weapon != null:
		_obtained_weapons.append(_starting_weapon)
		ensure_weapon_runtime_state(_starting_weapon)


func add_resource(resource_id: String, amount: int, show_message: bool = true) -> bool:
	if amount == 0:
		return false
	if not RESOURCE_IDS.has(resource_id):
		message_requested.emit("Invalid resource id: %s" % resource_id)
		return false
	var current_amount: int = int(resources.get(resource_id, 0))
	resources[resource_id] = max(current_amount + amount, 0)
	resources_changed.emit(resources.duplicate(true))
	if show_message:
		message_requested.emit("%s +%d" % [resource_id.capitalize(), amount])
	return true


func spend_resource(resource_id: String, amount: int) -> bool:
	if amount <= 0:
		return true
	if not RESOURCE_IDS.has(resource_id):
		message_requested.emit("Invalid resource id: %s" % resource_id)
		return false
	var current_amount: int = int(resources.get(resource_id, 0))
	if current_amount < amount:
		return false
	resources[resource_id] = current_amount - amount
	resources_changed.emit(resources.duplicate(true))
	return true


func has_resources(costs: Dictionary) -> bool:
	for resource_id in costs.keys():
		var amount := int(costs[resource_id])
		if amount <= 0:
			continue
		if not RESOURCE_IDS.has(String(resource_id)):
			return false
		if int(resources.get(String(resource_id), 0)) < amount:
			return false
	return true


func spend_resources(costs: Dictionary) -> bool:
	if not has_resources(costs):
		return false
	for resource_id in costs.keys():
		var amount := int(costs[resource_id])
		if amount <= 0:
			continue
		spend_resource(String(resource_id), amount)
	return true


func get_equipped_weapon() -> Resource:
	if _is_valid_weapon_resource(_equipped_weapon):
		_invalid_weapon_warning_emitted = false
		return _equipped_weapon
	if _is_valid_weapon_resource(DEFAULT_WEAPON_RESOURCE):
		if not _invalid_weapon_warning_emitted:
			push_warning("Player equipped_weapon is invalid; falling back to kitchen_knife.")
			_invalid_weapon_warning_emitted = true
		return DEFAULT_WEAPON_RESOURCE
	return null


func get_equipped_weapon_display_name() -> String:
	var weapon := get_equipped_weapon()
	if weapon == null:
		return ""
	return weapon.display_name


func get_obtained_weapons() -> Array[Resource]:
	return _obtained_weapons


func get_obtained_weapon_ids() -> PackedStringArray:
	var weapon_ids := PackedStringArray()
	for weapon in _obtained_weapons:
		if weapon == null:
			continue
		weapon_ids.append(String(weapon.weapon_id))
	return weapon_ids


func equip_weapon(weapon: Resource, show_message: bool = true) -> bool:
	var resolved_weapon := _resolve_strict_weapon_resource(weapon)
	if resolved_weapon == null:
		if show_message:
			message_requested.emit("Invalid weapon")
		return false
	if not _has_obtained_weapon_id(resolved_weapon.weapon_id):
		_obtained_weapons.append(resolved_weapon)
	ensure_weapon_runtime_state(resolved_weapon)

	var current_weapon := get_equipped_weapon()
	if current_weapon != null and current_weapon.weapon_id == resolved_weapon.weapon_id:
		if show_message:
			message_requested.emit("%s ready" % resolved_weapon.display_name)
		return false

	_equipped_weapon = resolved_weapon
	equipped_weapon_resource_changed.emit(_equipped_weapon)
	_emit_weapon_state()
	if show_message:
		message_requested.emit("Equipped %s" % resolved_weapon.display_name)
	return true


func obtain_weapon(weapon: Resource, auto_equip: bool = true, show_message: bool = true) -> bool:
	var resolved_weapon := _resolve_strict_weapon_resource(weapon)
	if resolved_weapon == null:
		if show_message:
			message_requested.emit("Invalid weapon")
		return false

	var already_owned := _has_obtained_weapon_id(resolved_weapon.weapon_id)
	if not already_owned:
		_obtained_weapons.append(resolved_weapon)
	ensure_weapon_runtime_state(resolved_weapon)

	if auto_equip:
		var equipped := equip_weapon(resolved_weapon, false)
		if show_message:
			if not already_owned:
				message_requested.emit("Found %s" % resolved_weapon.display_name)
			elif equipped:
				message_requested.emit("Switched to %s" % resolved_weapon.display_name)
			else:
				message_requested.emit("%s ready" % resolved_weapon.display_name)
		return equipped or not already_owned

	if show_message and not already_owned:
		message_requested.emit("Found %s" % resolved_weapon.display_name)
	return not already_owned


func reset_for_new_run() -> void:
	resources = {
		"salvage": 0,
		"parts": 0,
		"medicine": 0,
		"bullets": 0,
		"food": 0,
	}
	_obtained_weapons.clear()
	_magazine_ammo_by_weapon_id.clear()
	_reload_time_remaining = 0.0
	_reload_weapon_id = StringName()
	if _starting_weapon != null:
		_obtained_weapons.append(_starting_weapon)
		ensure_weapon_runtime_state(_starting_weapon)
		_equipped_weapon = _starting_weapon
	equipped_weapon_resource_changed.emit(_equipped_weapon)
	emit_full_state()


func emit_full_state() -> void:
	resources_changed.emit(resources.duplicate(true))
	_emit_weapon_state()


func get_save_state() -> Dictionary:
	var saved_magazine_ammo_by_weapon_id: Dictionary = {}
	for weapon_id in _magazine_ammo_by_weapon_id.keys():
		saved_magazine_ammo_by_weapon_id[String(weapon_id)] = int(_magazine_ammo_by_weapon_id[weapon_id])
	return {
		"resources": resources.duplicate(true),
		"equipped_weapon_id": String(get_equipped_weapon().weapon_id) if get_equipped_weapon() != null else "",
		"obtained_weapon_ids": get_obtained_weapon_ids(),
		"magazine_ammo_by_weapon_id": saved_magazine_ammo_by_weapon_id,
		"reload_time_remaining": _reload_time_remaining,
		"reload_weapon_id": String(_reload_weapon_id),
	}


func apply_save_state(save_state: Dictionary, weapon_lookup: Callable) -> void:
	var restored_resources := {
		"salvage": 0,
		"parts": 0,
		"medicine": 0,
		"bullets": 0,
		"food": 0,
	}
	var saved_resources: Dictionary = save_state.get("resources", {})
	for resource_id in RESOURCE_IDS:
		restored_resources[resource_id] = int(saved_resources.get(resource_id, 0))
	resources = restored_resources

	_obtained_weapons.clear()
	_magazine_ammo_by_weapon_id.clear()
	var saved_weapon_ids: Array = save_state.get("obtained_weapon_ids", [])
	for raw_weapon_id in saved_weapon_ids:
		var weapon := _resolve_weapon_from_lookup(weapon_lookup, StringName(raw_weapon_id))
		if weapon != null and not _has_obtained_weapon_id(weapon.weapon_id):
			_obtained_weapons.append(weapon)
			ensure_weapon_runtime_state(weapon)
	if _starting_weapon != null and not _has_obtained_weapon_id(_starting_weapon.weapon_id):
		_obtained_weapons.append(_starting_weapon)
		ensure_weapon_runtime_state(_starting_weapon)

	var saved_magazine_ammo_by_weapon_id: Dictionary = save_state.get("magazine_ammo_by_weapon_id", {})
	for raw_weapon_id in saved_magazine_ammo_by_weapon_id.keys():
		var weapon_id := StringName(raw_weapon_id)
		var weapon := find_obtained_weapon_by_id(weapon_id)
		if weapon == null or not uses_weapon_magazine(weapon):
			continue
		_magazine_ammo_by_weapon_id[weapon_id] = clampi(
			int(saved_magazine_ammo_by_weapon_id[raw_weapon_id]),
			0,
			int(weapon.magazine_size)
		)

	var equipped_weapon_id := StringName(save_state.get("equipped_weapon_id", ""))
	var resolved_equipped_weapon := _resolve_weapon_from_lookup(weapon_lookup, equipped_weapon_id)
	if resolved_equipped_weapon == null:
		resolved_equipped_weapon = _starting_weapon
	_equipped_weapon = _resolve_strict_weapon_resource(resolved_equipped_weapon)
	_reload_time_remaining = maxf(float(save_state.get("reload_time_remaining", 0.0)), 0.0)
	_reload_weapon_id = StringName(save_state.get("reload_weapon_id", ""))
	if _reload_time_remaining <= 0.0 or find_obtained_weapon_by_id(_reload_weapon_id) == null:
		_reload_time_remaining = 0.0
		_reload_weapon_id = StringName()
	equipped_weapon_resource_changed.emit(_equipped_weapon)
	emit_full_state()


func uses_weapon_magazine(weapon: Resource) -> bool:
	return weapon != null and bool(weapon.uses_magazine)


func ensure_weapon_runtime_state(weapon: Resource) -> void:
	if weapon == null or not uses_weapon_magazine(weapon):
		return
	if not _magazine_ammo_by_weapon_id.has(weapon.weapon_id):
		_magazine_ammo_by_weapon_id[weapon.weapon_id] = int(weapon.magazine_size)


func get_weapon_magazine_ammo(weapon: Resource) -> int:
	if weapon == null or not uses_weapon_magazine(weapon):
		return 0
	ensure_weapon_runtime_state(weapon)
	return int(_magazine_ammo_by_weapon_id.get(weapon.weapon_id, int(weapon.magazine_size)))


func set_weapon_magazine_ammo(weapon: Resource, amount: int) -> void:
	if weapon == null or not uses_weapon_magazine(weapon):
		return
	_magazine_ammo_by_weapon_id[weapon.weapon_id] = clampi(amount, 0, int(weapon.magazine_size))
	_emit_weapon_state()


func consume_weapon_magazine_round(weapon: Resource) -> void:
	if weapon == null or not uses_weapon_magazine(weapon):
		return
	var remaining_ammo: int = maxi(get_weapon_magazine_ammo(weapon) - 1, 0)
	set_weapon_magazine_ammo(weapon, remaining_ammo)
	if remaining_ammo == 0:
		begin_reload(weapon, true)


func is_reloading_weapon() -> bool:
	return _reload_time_remaining > 0.0 and _reload_weapon_id != StringName()


func get_reload_weapon_id() -> StringName:
	return _reload_weapon_id


func begin_reload(weapon: Resource, auto_triggered: bool) -> void:
	if weapon == null or not uses_weapon_magazine(weapon):
		return

	var current_ammo := get_weapon_magazine_ammo(weapon)
	if current_ammo >= int(weapon.magazine_size):
		if not auto_triggered:
			message_requested.emit("Magazine full")
		return
	if get_bullet_reserve_amount() <= 0:
		message_requested.emit("Out of bullets")
		return

	_reload_weapon_id = weapon.weapon_id
	_reload_time_remaining = float(weapon.reload_time)
	_emit_weapon_state()
	if auto_triggered:
		message_requested.emit("%s empty. Reloading..." % weapon.display_name)
	else:
		message_requested.emit("Reloading %s" % weapon.display_name)


func cancel_reload() -> void:
	if not is_reloading_weapon():
		return
	_reload_time_remaining = 0.0
	_reload_weapon_id = StringName()
	_emit_weapon_state()


func update_reload(delta: float) -> void:
	if not is_reloading_weapon():
		return
	_reload_time_remaining = max(_reload_time_remaining - delta, 0.0)
	if _reload_time_remaining > 0.0:
		return
	complete_reload()


func complete_reload() -> void:
	var reloaded_weapon := find_obtained_weapon_by_id(_reload_weapon_id)
	_reload_time_remaining = 0.0
	_reload_weapon_id = StringName()
	if reloaded_weapon == null:
		_emit_weapon_state()
		return
	var current_ammo := get_weapon_magazine_ammo(reloaded_weapon)
	var bullets_needed := maxi(int(reloaded_weapon.magazine_size) - current_ammo, 0)
	var bullets_to_load := mini(bullets_needed, get_bullet_reserve_amount())
	if bullets_to_load <= 0:
		message_requested.emit("Out of bullets")
		_emit_weapon_state()
		return
	spend_resource("bullets", bullets_to_load)
	set_weapon_magazine_ammo(reloaded_weapon, current_ammo + bullets_to_load)
	message_requested.emit("%s reloaded" % reloaded_weapon.display_name)


func find_obtained_weapon_by_id(weapon_id: StringName) -> Resource:
	for weapon in _obtained_weapons:
		if weapon != null and weapon.weapon_id == weapon_id:
			return weapon
	return null


func get_bullet_reserve_amount() -> int:
	return int(resources.get("bullets", 0))


func get_weapon_status_text() -> String:
	var weapon := get_equipped_weapon()
	if weapon == null:
		return "Weapon: None"
	if not uses_weapon_magazine(weapon):
		return "Weapon: %s" % weapon.display_name
	var ammo_in_mag := get_weapon_magazine_ammo(weapon)
	var status := "Weapon: %s %d/%d | ◉%d" % [weapon.display_name, ammo_in_mag, int(weapon.magazine_size), get_bullet_reserve_amount()]
	if is_reloading_weapon() and get_reload_weapon_id() == weapon.weapon_id:
		status += " ↻"
	return status


func get_weapon_trait_text() -> String:
	var weapon := get_equipped_weapon()
	if weapon == null:
		return ""
	return String(weapon.hud_trait_text)


func _emit_weapon_state() -> void:
	var weapon := get_equipped_weapon()
	if weapon == null:
		weapon_changed.emit("", StringName())
		weapon_status_changed.emit("Weapon: None")
		weapon_trait_changed.emit("")
		return
	weapon_changed.emit(weapon.display_name, weapon.weapon_id)
	weapon_status_changed.emit(get_weapon_status_text())
	weapon_trait_changed.emit(get_weapon_trait_text())


func _has_obtained_weapon_id(weapon_id: StringName) -> bool:
	return _get_obtained_weapon_index(weapon_id) >= 0


func _get_obtained_weapon_index(weapon_id: StringName) -> int:
	for index in _obtained_weapons.size():
		var weapon: Resource = _obtained_weapons[index]
		if weapon != null and weapon.weapon_id == weapon_id:
			return index
	return -1


func _resolve_weapon_from_lookup(weapon_lookup: Callable, weapon_id: StringName) -> Resource:
	if not weapon_lookup.is_valid():
		return null
	var weapon: Resource = weapon_lookup.call(weapon_id)
	if weapon == null or not _is_valid_weapon_resource(weapon):
		return null
	return weapon


func _resolve_valid_weapon_resource(resource: Resource) -> Resource:
	if _is_valid_weapon_resource(resource):
		return resource
	if _is_valid_weapon_resource(DEFAULT_WEAPON_RESOURCE):
		return DEFAULT_WEAPON_RESOURCE
	return null


func _resolve_strict_weapon_resource(resource: Resource) -> Resource:
	if _is_valid_weapon_resource(resource):
		return resource
	return null


func _is_valid_weapon_resource(resource: Resource) -> bool:
	if resource == null:
		return false
	if resource.get_script() != WEAPON_DEFINITION_SCRIPT and not resource.is_class("WeaponDefinition"):
		return false
	if not resource.has_method("is_valid_definition"):
		return false
	return resource.is_valid_definition()
