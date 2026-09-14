extends Node

# Procedural Sound Synthesizer for Space Ranger
# Generates dynamic sci-fi audio effects using AudioStreamWAV buffers

var audio_players: Array[AudioStreamPlayer] = []
const POOL_SIZE := 16
var _sounds: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		audio_players.append(p)
	
	_generate_all_sounds()

func _generate_all_sounds() -> void:
	_sounds["laser_pulse"] = _create_laser_sound(880.0, 220.0, 0.12, 0.6)
	_sounds["laser_spread"] = _create_laser_sound(550.0, 110.0, 0.18, 0.7)
	_sounds["laser_beam"] = _create_beam_sound(320.0, 0.35, 0.8)
	_sounds["enemy_laser"] = _create_laser_sound(340.0, 120.0, 0.14, 0.5)
	_sounds["explosion"] = _create_explosion_sound(0.45, 0.8)
	_sounds["boss_explosion"] = _create_explosion_sound(0.9, 1.0)
	_sounds["hit"] = _create_hit_sound(0.06, 0.4)
	_sounds["shield_hit"] = _create_shield_ping(0.2, 0.6)
	_sounds["pickup_energy"] = _create_chime_sound([523.25, 659.25, 783.99], 0.22, 0.6)
	_sounds["pickup_shield"] = _create_chime_sound([440.0, 554.37, 659.25, 880.0], 0.3, 0.6)
	_sounds["pickup_weapon"] = _create_chime_sound([330.0, 440.0, 554.37, 659.25, 987.77], 0.4, 0.7)
	_sounds["thruster"] = _create_noise_whoosh(0.18, 0.4)
	_sounds["dash"] = _create_laser_sound(900.0, 400.0, 0.2, 0.5)
	_sounds["alarm"] = _create_chime_sound([440.0, 330.0], 0.3, 0.5)

func play(sound_name: String, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	if not _sounds.has(sound_name):
		return
	var stream: AudioStreamWAV = _sounds[sound_name]
	for player in audio_players:
		if not player.playing:
			player.stream = stream
			player.pitch_scale = pitch_scale + randf_range(-0.06, 0.06)
			player.volume_db = volume_db
			player.play()
			return
	var p = audio_players[0]
	p.stream = stream
	p.pitch_scale = pitch_scale
	p.volume_db = volume_db
	p.play()

func _create_wav(samples: PackedByteArray, sample_rate: int = 22050) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = samples
	return wav

func _create_laser_sound(freq_start: float, freq_end: float, duration: float, volume: float) -> AudioStreamWAV:
	var rate := 22050
	var total_samples := int(rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t := float(i) / float(rate)
		var progress := float(i) / float(total_samples)
		var freq := lerpf(freq_start, freq_end, progress * progress)
		var envelope := 1.0 - progress
		var phase := fmod(t * freq, 1.0)
		var wave := (phase * 2.0 - 1.0) * 0.6 + sin(t * freq * TAU) * 0.4
		var sample := int(clampf(wave * envelope * volume, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
		
	return _create_wav(bytes, rate)

func _create_beam_sound(base_freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var rate := 22050
	var total_samples := int(rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t := float(i) / float(rate)
		var progress := float(i) / float(total_samples)
		var envelope := sin(progress * PI)
		var wave := sin(t * base_freq * TAU) * 0.5 + sin(t * (base_freq * 2.02) * TAU) * 0.3 + (randf() * 2.0 - 1.0) * 0.2
		var sample := int(clampf(wave * envelope * volume, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
		
	return _create_wav(bytes, rate)

func _create_explosion_sound(duration: float, volume: float) -> AudioStreamWAV:
	var rate := 22050
	var total_samples := int(rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	
	var last_val := 0.0
	for i in range(total_samples):
		var progress := float(i) / float(total_samples)
		var envelope := (1.0 - progress) * (1.0 - progress)
		var white_noise := randf() * 2.0 - 1.0
		last_val = lerpf(last_val, white_noise, 0.15)
		var sub_bass := sin(float(i) / rate * 55.0 * TAU) * 0.5
		var wave := (last_val * 0.7 + sub_bass * 0.5)
		var sample := int(clampf(wave * envelope * volume, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
		
	return _create_wav(bytes, rate)

func _create_hit_sound(duration: float, volume: float) -> AudioStreamWAV:
	var rate := 22050
	var total_samples := int(rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	
	for i in range(total_samples):
		var progress := float(i) / float(total_samples)
		var envelope := 1.0 - progress
		var wave := (randf() * 2.0 - 1.0) * 0.6 + sin(float(i) / rate * 300.0 * TAU) * 0.4
		var sample := int(clampf(wave * envelope * volume, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
		
	return _create_wav(bytes, rate)

func _create_shield_ping(duration: float, volume: float) -> AudioStreamWAV:
	var rate := 22050
	var total_samples := int(rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t := float(i) / float(rate)
		var progress := float(i) / float(total_samples)
		var envelope := exp(-progress * 6.0)
		var wave := sin(t * 1200.0 * TAU) * 0.6 + sin(t * 1850.0 * TAU) * 0.4
		var sample := int(clampf(wave * envelope * volume, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
		
	return _create_wav(bytes, rate)

func _create_chime_sound(frequencies: Array, duration: float, volume: float) -> AudioStreamWAV:
	var rate := 22050
	var total_samples := int(rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	var step_size := total_samples / frequencies.size()
	
	for i in range(total_samples):
		var note_idx := clampi(i / step_size, 0, frequencies.size() - 1)
		var freq: float = frequencies[note_idx]
		var t := float(i) / float(rate)
		var note_progress := float(i % step_size) / float(step_size)
		var envelope := exp(-note_progress * 4.0)
		var wave := sin(t * freq * TAU) * 0.7 + sin(t * freq * 2.0 * TAU) * 0.3
		var sample := int(clampf(wave * envelope * volume, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
		
	return _create_wav(bytes, rate)

func _create_noise_whoosh(duration: float, volume: float) -> AudioStreamWAV:
	var rate := 22050
	var total_samples := int(rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	
	var filter_val := 0.0
	for i in range(total_samples):
		var progress := float(i) / float(total_samples)
		var envelope := sin(progress * PI)
		var cutoff := lerpf(0.08, 0.45, sin(progress * PI))
		filter_val = lerpf(filter_val, randf() * 2.0 - 1.0, cutoff)
		var sample := int(clampf(filter_val * envelope * volume, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
		
	return _create_wav(bytes, rate)
