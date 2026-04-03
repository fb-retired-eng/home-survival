extends Node2D
class_name CombatAudio2D

const CombatSfxLibraryClass = preload("res://scripts/audio/combat_sfx_library.gd")

@export_range(1, 6, 1) var voice_count: int = 3
@export var audio_bus: StringName = &"SFX"
@export_range(50.0, 2000.0, 10.0) var max_distance: float = 1000.0
@export_range(0.0, 8.0, 0.1) var attenuation: float = 1.6

var _players: Array[AudioStreamPlayer2D] = []
var _voice_index: int = 0
var _last_sound_id: StringName = StringName()
var _recent_sound_ids: PackedStringArray = PackedStringArray()
var _library := CombatSfxLibraryClass.new()
var _headless: bool = false


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		return
	_ensure_audio_bus()
	if not _players.is_empty():
		return
	for index in range(max(voice_count, 1)):
		var player := AudioStreamPlayer2D.new()
		player.name = "Voice%d" % index
		player.bus = String(audio_bus)
		player.max_distance = max_distance
		player.attenuation = attenuation
		add_child(player)
		_players.append(player)


func _exit_tree() -> void:
	for player in _players:
		if player == null or not is_instance_valid(player):
			continue
		player.stop()
		player.stream = null
	_players.clear()
	CombatSfxLibraryClass.clear_cache()


func play_sound(sound_id: StringName, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	if sound_id == StringName():
		return
	_last_sound_id = sound_id
	_recent_sound_ids.append(String(sound_id))
	while _recent_sound_ids.size() > 8:
		_recent_sound_ids.remove_at(0)
	if _headless:
		return
	if _players.is_empty():
		_ready()
	if _players.is_empty():
		return
	var stream = _library.get_stream(sound_id)
	if stream == null:
		return
	var player := _players[_voice_index % _players.size()]
	_voice_index += 1
	player.stop()
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.volume_db = volume_db
	player.play()


func get_last_sound_id() -> StringName:
	return _last_sound_id


func get_recent_sound_ids() -> PackedStringArray:
	return _recent_sound_ids


func _ensure_audio_bus() -> void:
	var desired_bus := String(audio_bus)
	if desired_bus.is_empty():
		audio_bus = &"Master"
		return
	if AudioServer.get_bus_index(desired_bus) >= 0:
		return
	if desired_bus != "SFX":
		audio_bus = &"Master"
		return
	var new_index := AudioServer.bus_count
	AudioServer.add_bus(new_index)
	AudioServer.set_bus_name(new_index, desired_bus)
	AudioServer.set_bus_send(new_index, "Master")
