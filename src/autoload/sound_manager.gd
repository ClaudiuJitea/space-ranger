extends Node

# Procedural Sound Synthesizer for Space Ranger
# Generates dynamic sci-fi audio effects using AudioStreamWAV buffers, plus a
# fully procedural three-layer ambient music system (explore pad / combat
# pulse / boss tension) that crossfades with the game state.

var audio_players: Array[AudioStreamPlayer] = []
const POOL_SIZE := 16
var _sounds: Dictionary = {}
var _last_played: Dictionary = {} # sound name -> msec timestamp, gates pellet spam

# --- Music engine ---------------------------------------------------------
const MUSIC_RATE := 22050
const MUSIC_LOOP_SEC := 32.0 # every layer loops over exactly this window

var music_players: Array[StringName] = ["pad", "pulse", "tension"]
var _music: Dictionary = {} # layer -> AudioStreamPlayer
var _music_target: Dictionary = {} # layer -> linear volume
var _music_current: Dictionary = {} # layer -> linear volume
var music_mood: String = "explore"
var _mood_lock_until: int = 0 # msec timestamp, keeps stings from being cut

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_buses()
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		audio_players.append(p)

	_generate_all_sounds()
	# Music synthesis is heavier; defer it so the first frame renders fast.
	call_deferred("_late_music_init")

func _exit_tree() -> void:
	# Release every stream/playback so shutdown doesn't leak audio objects.
	# (Some playback objects are only reclaimable by the audio thread, so a
	# hard quit may still report a couple — this is exit-time noise only.)
	for layer in _music:
		if is_instance_valid(_music[layer]):
			_music[layer].stop()
			_music[layer].stream = null
	for p in audio_players:
		p.stop()
		p.stream = null

func _setup_audio_buses() -> void:
	# Master exists by default; add Music and SFX children so the settings
	# screen can mix them independently.
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	if AudioServer.get_bus_index("Music") >= 0:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(0.7))
	if AudioServer.get_bus_index("SFX") >= 0:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(0.9))

func apply_volumes(master: float, music: float, sfx: float) -> void:
	for pair in [["Master", master], ["Music", music], ["SFX", sfx]]:
		var idx := AudioServer.get_bus_index(pair[0])
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(pair[1], 0.0001)))
			AudioServer.set_bus_mute(idx, pair[1] <= 0.001)

const SFX_KEYS: Array[String] = [
	"laser_pulse", "laser_spread", "laser_beam", "enemy_laser",
	"explosion", "boss_explosion", "hit", "shield_hit",
	"pickup_energy", "pickup_shield", "pickup_weapon",
	"thruster", "dash", "alarm", "weapon_swap", "rocket_launch",
	"hitmarker", "rocket_explode", "footstep", "footstep_alt", "landing", "landing_hard",
	"ui_click", "ui_hover", "notify", "respawn", "lunge", "victory",
	"powerup", "plasma_burst",
]

func _load_mp3(path: String, loop := false) -> AudioStream:
	# Exported builds pack imported .mp3str files, not the original MP3 bytes.
	# FileAccess on res://assets/...mp3 works in the editor (project folder)
	# and fails in a release PCK, which used to drop every cue back to synth.
	if ResourceLoader.exists(path):
		var loaded := ResourceLoader.load(path)
		if loaded is AudioStreamMP3:
			var mp3: AudioStreamMP3 = (loaded as AudioStreamMP3).duplicate()
			mp3.loop = loop
			return mp3
		if loaded is AudioStream:
			return loaded
	if FileAccess.file_exists(path):
		var bytes := FileAccess.get_file_as_bytes(path)
		if not bytes.is_empty():
			var raw := AudioStreamMP3.new()
			raw.data = bytes
			raw.loop = loop
			return raw
	return null

func _generate_all_sounds() -> void:
	var loaded := 0
	for key in SFX_KEYS:
		var recorded := _load_mp3("res://assets/audio/sfx/%s.mp3" % key)
		if recorded:
			_sounds[key] = recorded
			loaded += 1
			continue
		_sounds[key] = _synth_fallback(key)
	print("SoundManager: %d/%d ElevenLabs SFX loaded" % [loaded, SFX_KEYS.size()])

func _synth_fallback(key: String) -> AudioStreamWAV:
	match key:
		"laser_pulse":
			return _create_laser_sound(880.0, 220.0, 0.12, 0.6)
		"laser_spread":
			return _create_laser_sound(550.0, 110.0, 0.18, 0.7)
		"laser_beam":
			return _create_beam_sound(320.0, 0.35, 0.8)
		"enemy_laser":
			return _create_laser_sound(340.0, 120.0, 0.14, 0.5)
		"explosion":
			return _create_explosion_sound(0.45, 0.8)
		"boss_explosion":
			return _create_explosion_sound(0.9, 1.0)
		"hit":
			return _create_hit_sound(0.06, 0.4)
		"shield_hit":
			return _create_shield_ping(0.2, 0.6)
		"pickup_energy":
			return _create_chime_sound([523.25, 659.25, 783.99], 0.22, 0.6)
		"pickup_shield":
			return _create_chime_sound([440.0, 554.37, 659.25, 880.0], 0.3, 0.6)
		"pickup_weapon":
			return _create_chime_sound([330.0, 440.0, 554.37, 659.25, 987.77], 0.4, 0.7)
		"thruster":
			return _create_noise_whoosh(0.18, 0.4)
		"dash":
			return _create_laser_sound(900.0, 400.0, 0.2, 0.5)
		"alarm":
			return _create_chime_sound([440.0, 330.0], 0.3, 0.5)
		"weapon_swap":
			return _create_click_sound(0.08, 0.5)
		"rocket_launch":
			return _create_rocket_sound(0.5, 0.8)
		"hitmarker":
			return _create_chime_sound([1300.0, 1750.0], 0.07, 0.35)
		"rocket_explode":
			return _create_explosion_sound(0.7, 1.0)
		"footstep":
			return _create_noise_whoosh(0.09, 0.22)
		"footstep_alt":
			return _create_noise_whoosh(0.1, 0.24)
		"landing":
			return _create_noise_whoosh(0.14, 0.4)
		"landing_hard":
			return _create_explosion_sound(0.22, 0.5)
		"ui_click":
			return _create_click_sound(0.06, 0.45)
		"ui_hover":
			return _create_chime_sound([880.0], 0.05, 0.18)
		"notify":
			return _create_chime_sound([740.0, 1108.0], 0.14, 0.4)
		"respawn":
			return _create_noise_whoosh(0.35, 0.5)
		"lunge":
			return _create_laser_sound(180.0, 60.0, 0.22, 0.6)
		"victory":
			return _create_chime_sound([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.85, 0.65)
		"powerup":
			return _create_chime_sound([392.0, 523.25, 659.25, 784.0], 0.32, 0.6)
		_:
			return _create_laser_sound(420.0, 90.0, 0.22, 0.7)

func play(sound_name: String, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	if not _sounds.has(sound_name):
		return
	# Gate identical re-triggers within 30 ms (e.g. 6 shotgun pellets landing
	# in the same frame would otherwise stack six hitmarker pings).
	var now := Time.get_ticks_msec()
	if _last_played.has(sound_name) and now - int(_last_played[sound_name]) < 30:
		return
	_last_played[sound_name] = now
	var stream: AudioStream = _sounds[sound_name]
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

func _create_click_sound(duration: float, volume: float) -> AudioStreamWAV:
	var rate := 22050
	var total_samples := int(rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)

	for i in range(total_samples):
		var progress := float(i) / float(total_samples)
		var envelope := exp(-progress * 12.0)
		var wave := sin(float(i) / rate * 2400.0 * TAU) * 0.5 + (randf() * 2.0 - 1.0) * 0.5
		var sample := int(clampf(wave * envelope * volume, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)

	return _create_wav(bytes, rate)

func _create_rocket_sound(duration: float, volume: float) -> AudioStreamWAV:
	var rate := 22050
	var total_samples := int(rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)

	var filter_val := 0.0
	for i in range(total_samples):
		var t := float(i) / float(rate)
		var progress := float(i) / float(total_samples)
		var envelope := (1.0 - progress) * (1.0 - progress * 0.4)
		var cutoff := lerpf(0.5, 0.1, progress)
		filter_val = lerpf(filter_val, randf() * 2.0 - 1.0, cutoff)
		var rumble := sin(t * 70.0 * TAU) * 0.4 + sin(t * 140.0 * TAU) * 0.2
		var wave := filter_val * 0.6 + rumble
		var sample := int(clampf(wave * envelope * volume, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)

	return _create_wav(bytes, rate)

# ---------------------------------------------------------------- music ----
## Fully procedural, seamlessly looping ambient music. Every oscillator
## frequency is quantized to an integer multiple of 1/loop_length, so each
## layer's waveform is perfectly periodic and loops without a click.

func _late_music_init() -> void:
	# Runs after all autoloads exist, so GameManager signals are connectable.
	if get_tree().root.has_node("GameManager"):
		var gm := get_tree().root.get_node("GameManager")
		gm.connect("level_completed", _on_victory)
		gm.connect("player_died", func(): set_music_mood("none", 0))
	_generate_music_layers()

func _on_victory() -> void:
	play("victory", 1.0, 2.0)
	set_music_mood("victory", 8000)

func _quant(freq: float) -> float:
	# Snap a frequency to the nearest integer multiple of 1/loop so the loop
	# stays click-free.
	var f0 := 1.0 / MUSIC_LOOP_SEC
	return maxf(roundf(freq / f0), 1.0) * f0

func _make_loop_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MUSIC_RATE
	wav.stereo = false
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = samples.size()
	return wav

func _generate_music_layers() -> void:
	if not _music.is_empty():
		return
	var files := {"pad": "music_pad", "pulse": "music_pulse", "tension": "music_tension"}
	var need_synth := false
	var recorded: Dictionary = {}
	for layer in music_players:
		var stream := _load_mp3("res://assets/audio/music/%s.mp3" % files[layer], true)
		if stream:
			recorded[layer] = stream
		else:
			need_synth = true
	var synth := {}
	if need_synth:
		var L := int(MUSIC_LOOP_SEC * MUSIC_RATE)
		synth = {"pad": _render_pad(L), "pulse": _render_pulse(L), "tension": _render_tension(L)}
	for layer in music_players:
		var p := AudioStreamPlayer.new()
		p.name = "Music_%s" % layer
		p.bus = "Music"
		if recorded.has(layer):
			p.stream = recorded[layer]
		else:
			p.stream = _make_loop_stream(synth[layer])
		p.volume_db = -60.0
		add_child(p)
		p.play()
		_music[layer] = p
		_music_current[layer] = 0.0
	_music_target = {"pad": 0.0, "pulse": 0.0, "tension": 0.0}
	_set_targets("explore")

## Slow evolving pad: Am - F - C - G, 4 s per chord, additive sines with
## chorus detune and a slow shimmer LFO.
func _render_pad(L: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(L)
	# Chord roots and their stacked intervals (semitones above root).
	var chords := [[57, 0, 3, 7, 12], [53, 0, 4, 7, 12], [48, 0, 4, 7, 12], [55, 0, 4, 7, 11]]
	var chord_len := L / chords.size()
	var detunes := [1.0, 1.0035] # two chorus voices keeps boot synthesis cheap
	for c in range(chords.size()):
		var root_hz := 440.0 * pow(2.0, (chords[c][0] - 69.0) / 12.0)
		var base := c * chord_len
		for n in range(1, chords[c].size()):
			var freq := _quant(root_hz * pow(2.0, chords[c][n] / 12.0))
			var amp := 0.30 / n
			for d in range(detunes.size()):
				var f := _quant(freq * detunes[d])
				var phase := randf() * TAU
				var w := TAU * f / MUSIC_RATE
				for i in range(chord_len):
					var t := float(base + i)
					var prog := float(i) / chord_len
					var env := pow(sin(prog * PI), 1.5) * amp
					var shimmer := 0.75 + 0.25 * sin(TAU * (t / L) * 8.0 + phase)
					var v := sin(w * t + phase) * env * shimmer
					if base + i < L:
						out[base + i] += v
					else:
						out[base + i - L] += v
	# Soft-clip and normalize
	var peak := 0.001
	for i in range(L):
		peak = maxf(peak, absf(out[i]))
	var norm := 0.55 / peak
	for i in range(L):
		out[i] = tanh(out[i] * norm * 1.4) * 0.7
	return out

## Combat layer: driving eighth-note bass pulses with a filtered tick.
func _render_pulse(L: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(L)
	var grid := 128 # eighth notes at 128 per 32 s
	var slot := L / grid
	var roots := [45, 41, 36, 43] # A1 F1 C1 G1 MIDI, one per 8 s
	for s in range(grid):
		var chord_idx := (s * 4) / grid
		var root_hz := 440.0 * pow(2.0, (roots[chord_idx] - 69.0) / 12.0)
		var on_beat := s % 2 == 0
		var start := s * slot
		var plen := slot * (2 if on_beat else 1)
		for i in range(plen):
			var t := float(i) / MUSIC_RATE
			var env := exp(-t * (14.0 if on_beat else 8.0)) * (0.5 if on_beat else 0.22)
			var v := 0.0
			for h in range(1, 5):
				v += sin(TAU * _quant(root_hz * h) * t) * (0.8 / h)
			var idx := start + i
			if idx >= L:
				idx -= L
			out[idx] += v * env * 0.35
	var peak := 0.001
	for i in range(L):
		peak = maxf(peak, absf(out[i]))
	var norm := 0.8 / peak
	for i in range(L):
		out[i] *= norm
	return out

## Boss tension: tritone drone with beating detune and a heartbeat kick.
func _render_tension(L: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(L)
	var beats := 40 # heartbeat every 0.8 s -> exactly 40 beats per loop
	var beat_len := L / beats
	for b in range(beats):
		var strong := b % 2 == 0
		for i in range(beat_len):
			var t := float(i) / MUSIC_RATE
			var env := exp(-t * (10.0 if strong else 16.0)) * (0.5 if strong else 0.25)
			var idx := b * beat_len + i
			out[idx] += sin(TAU * 55.0 * t) * env * 0.8
	for i in range(L):
		var t := float(i) / MUSIC_RATE
		var drift := sin(TAU * t / MUSIC_LOOP_SEC * 2.0)
		out[i] += (sin(TAU * 110.0 * t) + sin(TAU * 155.7 * t) * 0.8 + sin(TAU * 111.5 * t) * 0.4) * 0.05
		out[i] += sin(TAU * (220.0 + 3.0 * drift) * t) * 0.02 * (0.5 + 0.5 * drift)
	var peak := 0.001
	for i in range(L):
		peak = maxf(peak, absf(out[i]))
	var norm := 0.75 / peak
	for i in range(L):
		out[i] *= norm
	return out

func set_music_mood(mood: String, lock_msec: int = 0) -> void:
	music_mood = mood
	_mood_lock_until = Time.get_ticks_msec() + lock_msec
	_set_targets(mood)

func _set_targets(mood: String) -> void:
	match mood:
		"menu":
			_music_target = {"pad": 1.0, "pulse": 0.0, "tension": 0.0}
		"explore":
			_music_target = {"pad": 0.9, "pulse": 0.0, "tension": 0.0}
		"combat":
			_music_target = {"pad": 0.5, "pulse": 0.8, "tension": 0.0}
		"boss":
			_music_target = {"pad": 0.35, "pulse": 0.55, "tension": 0.9}
		"victory":
			_music_target = {"pad": 1.0, "pulse": 0.0, "tension": 0.0}
		_:
			_music_target = {"pad": 0.0, "pulse": 0.0, "tension": 0.0}

func _process(_delta: float) -> void:
	if _music.is_empty():
		return
	# Auto mood selection while unlocked: menu/victory moods stick until the
	# scene explicitly changes them.
	if Time.get_ticks_msec() >= _mood_lock_until:
		var auto := "explore"
		if music_mood in ["menu", "victory", "none"]:
			auto = music_mood
		elif GameManager.boss_active:
			auto = "boss"
		elif GameManager.is_in_combat():
			auto = "combat"
		if auto != music_mood:
			music_mood = auto
			_set_targets(auto)
	for layer in _music:
		var cur: float = _music_current[layer]
		var tgt: float = _music_target[layer]
		cur = lerpf(cur, tgt, 0.8 * _delta)
		_music_current[layer] = cur
		var p: AudioStreamPlayer = _music[layer]
		p.volume_db = linear_to_db(maxf(cur * cur, 0.0001)) if cur > 0.001 else -60.0
