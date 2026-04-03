extends RefCounted
class_name CombatSfxLibrary

const MIX_RATE := 22050
const AMPLITUDE := 0.7

static var _cache: Dictionary = {}


static func get_stream(sound_id: StringName) -> AudioStreamWAV:
	if _cache.has(sound_id):
		return _cache[sound_id]

	var stream := _build_stream(sound_id)
	_cache[sound_id] = stream
	return stream


static func clear_cache() -> void:
	_cache.clear()


static func _build_stream(sound_id: StringName) -> AudioStreamWAV:
	match String(sound_id):
		"knife_swing":
			return _create_wave_stream(0.08, 220.0, 140.0, "noise", 0.003, 0.05, 0.0, 0.027)
		"bat_swing":
			return _create_layered_stream([
				{"duration": 0.11, "start_freq": 180.0, "end_freq": 110.0, "waveform": "saw", "attack": 0.002, "decay": 0.06, "sustain": 0.0, "release": 0.048, "gain": 0.55},
				{"duration": 0.05, "start_freq": 620.0, "end_freq": 260.0, "waveform": "noise", "attack": 0.001, "decay": 0.03, "sustain": 0.0, "release": 0.019, "gain": 0.16},
			])
		"pistol_shot":
			return _create_layered_stream([
				{"duration": 0.055, "start_freq": 980.0, "end_freq": 180.0, "waveform": "noise", "attack": 0.001, "decay": 0.045, "sustain": 0.0, "release": 0.009, "gain": 1.0},
				{"duration": 0.06, "start_freq": 120.0, "end_freq": 70.0, "waveform": "sine", "attack": 0.001, "decay": 0.05, "sustain": 0.0, "release": 0.009, "gain": 0.35},
			])
		"shotgun_shot":
			return _create_layered_stream([
				{"duration": 0.08, "start_freq": 760.0, "end_freq": 120.0, "waveform": "noise", "attack": 0.001, "decay": 0.055, "sustain": 0.0, "release": 0.024, "gain": 1.0},
				{"duration": 0.1, "start_freq": 90.0, "end_freq": 52.0, "waveform": "sine", "attack": 0.001, "decay": 0.07, "sustain": 0.0, "release": 0.029, "gain": 0.48},
			])
		"player_reload_start":
			return _create_layered_stream([
				{"duration": 0.07, "start_freq": 520.0, "end_freq": 420.0, "waveform": "square", "attack": 0.001, "decay": 0.03, "sustain": 0.15, "release": 0.039, "gain": 0.35},
				{"duration": 0.045, "start_freq": 960.0, "end_freq": 780.0, "waveform": "noise", "attack": 0.001, "decay": 0.03, "sustain": 0.0, "release": 0.014, "gain": 0.22},
			])
		"player_reload_done":
			return _create_wave_stream(0.06, 640.0, 760.0, "square", 0.001, 0.02, 0.0, 0.039)
		"player_hurt":
			return _create_layered_stream([
				{"duration": 0.12, "start_freq": 180.0, "end_freq": 120.0, "waveform": "saw", "attack": 0.001, "decay": 0.08, "sustain": 0.0, "release": 0.039, "gain": 0.55},
				{"duration": 0.08, "start_freq": 760.0, "end_freq": 420.0, "waveform": "noise", "attack": 0.001, "decay": 0.05, "sustain": 0.0, "release": 0.029, "gain": 0.22},
			])
		"zombie_hurt":
			return _create_layered_stream([
				{"duration": 0.09, "start_freq": 140.0, "end_freq": 90.0, "waveform": "saw", "attack": 0.001, "decay": 0.06, "sustain": 0.0, "release": 0.029, "gain": 0.55},
				{"duration": 0.05, "start_freq": 420.0, "end_freq": 220.0, "waveform": "noise", "attack": 0.001, "decay": 0.035, "sustain": 0.0, "release": 0.014, "gain": 0.18},
			])
		"zombie_attack_tell":
			return _create_wave_stream(0.05, 240.0, 310.0, "saw", 0.001, 0.02, 0.0, 0.029)
		"zombie_attack_hit":
			return _create_layered_stream([
				{"duration": 0.075, "start_freq": 120.0, "end_freq": 70.0, "waveform": "saw", "attack": 0.001, "decay": 0.05, "sustain": 0.0, "release": 0.024, "gain": 0.5},
				{"duration": 0.05, "start_freq": 520.0, "end_freq": 180.0, "waveform": "noise", "attack": 0.001, "decay": 0.04, "sustain": 0.0, "release": 0.009, "gain": 0.25},
			])
		"structure_hit":
			return _create_layered_stream([
				{"duration": 0.08, "start_freq": 420.0, "end_freq": 240.0, "waveform": "square", "attack": 0.001, "decay": 0.045, "sustain": 0.0, "release": 0.034, "gain": 0.28},
				{"duration": 0.07, "start_freq": 900.0, "end_freq": 360.0, "waveform": "noise", "attack": 0.001, "decay": 0.05, "sustain": 0.0, "release": 0.019, "gain": 0.24},
			])
		"trap_trigger":
			return _create_layered_stream([
				{"duration": 0.06, "start_freq": 1180.0, "end_freq": 640.0, "waveform": "square", "attack": 0.001, "decay": 0.04, "sustain": 0.0, "release": 0.019, "gain": 0.35},
				{"duration": 0.05, "start_freq": 760.0, "end_freq": 260.0, "waveform": "noise", "attack": 0.001, "decay": 0.035, "sustain": 0.0, "release": 0.014, "gain": 0.22},
			])
		"pickup_resource":
			return _create_layered_stream([
				{"duration": 0.06, "start_freq": 620.0, "end_freq": 840.0, "waveform": "square", "attack": 0.001, "decay": 0.025, "sustain": 0.0, "release": 0.034, "gain": 0.24},
				{"duration": 0.045, "start_freq": 980.0, "end_freq": 1220.0, "waveform": "sine", "attack": 0.001, "decay": 0.02, "sustain": 0.0, "release": 0.024, "gain": 0.28},
			])
		"pickup_weapon":
			return _create_layered_stream([
				{"duration": 0.08, "start_freq": 540.0, "end_freq": 820.0, "waveform": "square", "attack": 0.001, "decay": 0.03, "sustain": 0.08, "release": 0.039, "gain": 0.24},
				{"duration": 0.07, "start_freq": 960.0, "end_freq": 1460.0, "waveform": "sine", "attack": 0.001, "decay": 0.025, "sustain": 0.0, "release": 0.034, "gain": 0.24},
			])
		"build_place":
			return _create_layered_stream([
				{"duration": 0.07, "start_freq": 260.0, "end_freq": 180.0, "waveform": "square", "attack": 0.001, "decay": 0.03, "sustain": 0.0, "release": 0.039, "gain": 0.26},
				{"duration": 0.05, "start_freq": 880.0, "end_freq": 420.0, "waveform": "noise", "attack": 0.001, "decay": 0.03, "sustain": 0.0, "release": 0.019, "gain": 0.18},
			])
		"build_repair":
			return _create_layered_stream([
				{"duration": 0.07, "start_freq": 420.0, "end_freq": 560.0, "waveform": "square", "attack": 0.001, "decay": 0.03, "sustain": 0.0, "release": 0.039, "gain": 0.24},
				{"duration": 0.05, "start_freq": 700.0, "end_freq": 980.0, "waveform": "sine", "attack": 0.001, "decay": 0.025, "sustain": 0.0, "release": 0.024, "gain": 0.22},
			])
		"build_recycle":
			return _create_layered_stream([
				{"duration": 0.06, "start_freq": 680.0, "end_freq": 420.0, "waveform": "square", "attack": 0.001, "decay": 0.025, "sustain": 0.0, "release": 0.034, "gain": 0.22},
				{"duration": 0.05, "start_freq": 880.0, "end_freq": 520.0, "waveform": "noise", "attack": 0.001, "decay": 0.03, "sustain": 0.0, "release": 0.019, "gain": 0.16},
			])
		"build_upgrade":
			return _create_layered_stream([
				{"duration": 0.09, "start_freq": 420.0, "end_freq": 760.0, "waveform": "square", "attack": 0.001, "decay": 0.035, "sustain": 0.05, "release": 0.039, "gain": 0.24},
				{"duration": 0.07, "start_freq": 760.0, "end_freq": 1180.0, "waveform": "sine", "attack": 0.001, "decay": 0.03, "sustain": 0.0, "release": 0.029, "gain": 0.22},
			])
		"attack_hit_enemy":
			return _create_layered_stream([
				{"duration": 0.045, "start_freq": 820.0, "end_freq": 540.0, "waveform": "noise", "attack": 0.001, "decay": 0.025, "sustain": 0.0, "release": 0.019, "gain": 0.18},
				{"duration": 0.055, "start_freq": 260.0, "end_freq": 180.0, "waveform": "sine", "attack": 0.001, "decay": 0.03, "sustain": 0.0, "release": 0.024, "gain": 0.18},
			])
		"attack_miss":
			return _create_layered_stream([
				{"duration": 0.05, "start_freq": 920.0, "end_freq": 420.0, "waveform": "noise", "attack": 0.001, "decay": 0.03, "sustain": 0.0, "release": 0.019, "gain": 0.12},
				{"duration": 0.04, "start_freq": 560.0, "end_freq": 300.0, "waveform": "sine", "attack": 0.001, "decay": 0.022, "sustain": 0.0, "release": 0.017, "gain": 0.1},
			])
		_:
			return _create_wave_stream(0.04, 440.0, 330.0, "sine", 0.001, 0.025, 0.0, 0.014)


static func _create_layered_stream(layer_specs: Array) -> AudioStreamWAV:
	var max_duration := 0.0
	for spec_variant in layer_specs:
		var spec: Dictionary = spec_variant
		max_duration = maxf(max_duration, float(spec.get("duration", 0.05)))

	var sample_count: int = maxi(int(ceil(max_duration * MIX_RATE)), 1)
	var mixed := PackedFloat32Array()
	mixed.resize(sample_count)
	for i in range(sample_count):
		mixed[i] = 0.0

	for spec_variant in layer_specs:
		var spec: Dictionary = spec_variant
		var layer := _synthesize_samples(
			float(spec.get("duration", 0.05)),
			float(spec.get("start_freq", 440.0)),
			float(spec.get("end_freq", 440.0)),
			String(spec.get("waveform", "sine")),
			float(spec.get("attack", 0.001)),
			float(spec.get("decay", 0.02)),
			float(spec.get("sustain", 0.0)),
			float(spec.get("release", 0.01))
		)
		var gain: float = float(spec.get("gain", 1.0))
		for i in range(min(sample_count, layer.size())):
			mixed[i] += layer[i] * gain

	var normalized := PackedFloat32Array()
	normalized.resize(sample_count)
	for i in range(sample_count):
		normalized[i] = clampf(mixed[i], -1.0, 1.0)
	return _samples_to_stream(normalized)


static func _create_wave_stream(
	duration: float,
	start_freq: float,
	end_freq: float,
	waveform: String,
	attack: float,
	decay: float,
	sustain: float,
	release: float
) -> AudioStreamWAV:
	return _samples_to_stream(_synthesize_samples(duration, start_freq, end_freq, waveform, attack, decay, sustain, release))


static func _samples_to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var sample_value := int(round(clampf(samples[i] * AMPLITUDE, -1.0, 1.0) * 32767.0))
		var encoded := sample_value & 0xffff
		bytes[i * 2] = encoded & 0xff
		bytes[i * 2 + 1] = (encoded >> 8) & 0xff

	var stream := AudioStreamWAV.new()
	stream.data = bytes
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream


static func _synthesize_samples(
	duration: float,
	start_freq: float,
	end_freq: float,
	waveform: String,
	attack: float,
	decay: float,
	sustain: float,
	release: float
) -> PackedFloat32Array:
	var sample_count: int = maxi(int(ceil(duration * MIX_RATE)), 1)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var phase: float = 0.0
	var prng: RandomNumberGenerator = RandomNumberGenerator.new()
	prng.seed = hash([duration, start_freq, end_freq, waveform, attack, decay, sustain, release])

	for i in range(sample_count):
		var t: float = float(i) / float(sample_count)
		var frequency: float = lerpf(start_freq, end_freq, t)
		phase = fmod(phase + (TAU * frequency / MIX_RATE), TAU)
		var wave_sample: float = _sample_waveform(phase, waveform, prng)
		samples[i] = wave_sample * _envelope(t * duration, duration, attack, decay, sustain, release)
	return samples


static func _sample_waveform(phase: float, waveform: String, prng: RandomNumberGenerator) -> float:
	match waveform:
		"square":
			return 1.0 if sin(phase) >= 0.0 else -1.0
		"saw":
			return (fmod(phase / TAU, 1.0) * 2.0) - 1.0
		"noise":
			return prng.randf_range(-1.0, 1.0)
		_:
			return sin(phase)


static func _envelope(time: float, duration: float, attack: float, decay: float, sustain: float, release: float) -> float:
	var sustain_level: float = clampf(1.0 - sustain, 0.12, 1.0)
	var attack_end: float = maxf(attack, 0.0001)
	var decay_end: float = attack_end + maxf(decay, 0.0)
	var release_start: float = maxf(duration - maxf(release, 0.0), decay_end)

	if time < attack_end:
		return clampf(time / attack_end, 0.0, 1.0)
	if time < decay_end:
		var decay_progress: float = (time - attack_end) / maxf(decay_end - attack_end, 0.0001)
		return lerpf(1.0, sustain_level, decay_progress)
	if time < release_start:
		return sustain_level
	var release_progress: float = (time - release_start) / maxf(duration - release_start, 0.0001)
	return lerpf(sustain_level, 0.0, clampf(release_progress, 0.0, 1.0))
