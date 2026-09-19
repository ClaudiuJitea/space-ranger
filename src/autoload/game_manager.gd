extends Node

signal health_changed(current: float, max_val: float)
signal shield_changed(current: float, max_val: float)
signal score_changed(new_score: int, combo: int)
signal weapon_changed(index: int, weapon_name: String)
signal boss_health_changed(current: float, max_val: float)
signal boss_defeated()
signal player_died()
signal level_completed()
signal hull_damaged(amount: float)
## Fired for any event that deserves an on-screen toast (pickup, overheat,
## objective). The HUD listens and renders the notification stack.
signal notify_requested(text: String, color: Color)

var score: int = 0
var high_score: int = 0
var combo: int = 1
var combo_timer: float = 0.0
const COMBO_TIMEOUT: float = 3.5

# --- Persisted settings (user://settings.cfg) ---
var settings_master_volume: float = 0.9
var settings_music_volume: float = 0.7
var settings_sfx_volume: float = 0.9
var settings_shake_scale: float = 1.0
var settings_fullscreen: bool = false

var _last_combat_msec: int = -10000

var max_health: float = 100.0
var health: float = 100.0
var max_shield: float = 80.0
var shield: float = 80.0
var shield_recharge_rate: float = 18.0 # per second
var shield_recharge_delay: float = 2.2
var shield_delay_timer: float = 0.0

## Brief invulnerability window after hull damage so overlapping projectiles
## (e.g. the boss missile fan) can't instantly delete the player.
const HURT_INVULN_TIME: float = 0.65
var hurt_invuln_timer: float = 0.0

var unlocked_weapons: Array[bool] = [true, false, false, false] # PX-9 starts equipped; the rest are campaign pickups.
var current_weapon: int = 0
const WEAPON_NAMES: Array[String] = ["PX-9 PULSE BLASTER", "TITAN-8 SCATTERGUN", "LR-77 PHOTON RAILGUN", "HV-4 HAVOC LAUNCHER"]
const WEAPON_COLORS: Array[Color] = [
	Color(0.15, 0.85, 1.0),
	Color(1.0, 0.5, 0.1),
	Color(0.2, 1.0, 0.85),
	Color(1.0, 0.3, 0.15),
]

var boss_active: bool = false
var boss_health: float = 1000.0
var boss_max_health: float = 1000.0

var player_node: Node = null

# Session checkpoints preserve the campaign loadout without writing save files.
var mission_checkpoint: Dictionary = {}
var mission_relays: Array[String] = []
var retry_pending := false

func prepare_mission(path: String, _minimum_weapon: int) -> Vector3:
	var resume: bool = retry_pending and mission_checkpoint.get("path", "") == path
	retry_pending = false
	if resume:
		score = mission_checkpoint["score"]
		unlocked_weapons.assign(mission_checkpoint["weapons"])
		current_weapon = mission_checkpoint["weapon"]
		mission_relays.assign(mission_checkpoint["relays"])
	else:
		mission_relays.clear()
		# Campaign transitions preserve only weapons actually collected. Starting
		# a mission must never silently grant the full arsenal.
		if current_weapon < 0 or current_weapon >= unlocked_weapons.size() or not unlocked_weapons[current_weapon]:
			current_weapon = 0
		store_checkpoint(path, Vector3(0, 0.2, 0))
	health = max_health
	shield = max_shield
	combo = 1
	combo_timer = 0
	shield_delay_timer = 0
	hurt_invuln_timer = 1.2
	boss_active = false
	emit_signal("health_changed", health, max_health)
	emit_signal("shield_changed", shield, max_shield)
	emit_signal("score_changed", score, combo)
	emit_signal("weapon_changed", current_weapon, WEAPON_NAMES[current_weapon])
	return mission_checkpoint["position"]

func store_checkpoint(path: String, location: Vector3) -> void:
	mission_checkpoint = {"path": path, "position": location, "score": score,
		"weapons": unlocked_weapons.duplicate(), "weapon": current_weapon,
		"relays": mission_relays.duplicate()}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_save_data()
	_apply_settings()
	reset_game()

## Loads high score and user settings from disk (missing file = defaults).
func _load_save_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		high_score = int(cfg.get_value("progress", "high_score", 0))
		settings_master_volume = cfg.get_value("audio", "master", 0.9)
		settings_music_volume = cfg.get_value("audio", "music", 0.7)
		settings_sfx_volume = cfg.get_value("audio", "sfx", 0.9)
		settings_shake_scale = cfg.get_value("gameplay", "shake_scale", 1.0)
		settings_fullscreen = cfg.get_value("video", "fullscreen", false)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "high_score", high_score)
	cfg.set_value("audio", "master", settings_master_volume)
	cfg.set_value("audio", "music", settings_music_volume)
	cfg.set_value("audio", "sfx", settings_sfx_volume)
	cfg.set_value("gameplay", "shake_scale", settings_shake_scale)
	cfg.set_value("video", "fullscreen", settings_fullscreen)
	cfg.save("user://settings.cfg")

func _apply_settings() -> void:
	FXManager.shake_scale = settings_shake_scale
	SoundManager.apply_volumes(settings_master_volume, settings_music_volume, settings_sfx_volume)
	if settings_fullscreen:
		var win := get_window()
		if win:
			win.mode = Window.MODE_FULLSCREEN
	else:
		var win := get_window()
		if win and win.mode == Window.MODE_FULLSCREEN:
			win.mode = Window.MODE_WINDOWED

## Called by the settings screen whenever a slider/toggle changes.
func update_setting(key: String, value: float) -> void:
	match key:
		"master": settings_master_volume = value
		"music": settings_music_volume = value
		"sfx": settings_sfx_volume = value
		"shake": settings_shake_scale = value
		"fullscreen": settings_fullscreen = value > 0.5
	_apply_settings()
	save_settings()

func submit_score(final_score: int) -> void:
	if final_score > high_score:
		high_score = final_score
		save_settings()

func notify(text: String, color: Color = Color(0.7, 0.85, 1.0)) -> void:
	emit_signal("notify_requested", text, color)

## True while recent scoring/damage happened, drives the combat music layer.
func is_in_combat() -> bool:
	return Time.get_ticks_msec() - _last_combat_msec < 5000

func _mark_combat() -> void:
	_last_combat_msec = Time.get_ticks_msec()

func reset_game() -> void:
	mission_checkpoint.clear()
	mission_relays.clear()
	retry_pending = false
	score = 0
	combo = 1
	combo_timer = 0.0
	health = max_health
	shield = max_shield
	shield_delay_timer = 0.0
	hurt_invuln_timer = 0.0
	unlocked_weapons = [true, false, false, false]
	current_weapon = 0
	boss_active = false
	emit_signal("health_changed", health, max_health)
	emit_signal("shield_changed", shield, max_shield)
	emit_signal("score_changed", score, combo)
	emit_signal("weapon_changed", current_weapon, WEAPON_NAMES[current_weapon])

func _process(delta: float) -> void:
	# Combo decay
	if combo > 1:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 1
			emit_signal("score_changed", score, combo)

	if hurt_invuln_timer > 0.0:
		hurt_invuln_timer -= delta

	# Shield recharge
	if shield < max_shield and health > 0:
		if shield_delay_timer > 0.0:
			shield_delay_timer -= delta
		else:
			shield = minf(shield + shield_recharge_rate * delta, max_shield)
			emit_signal("shield_changed", shield, max_shield)

func is_player_invulnerable() -> bool:
	if hurt_invuln_timer > 0.0:
		return true
	if player_node != null and is_instance_valid(player_node):
		var dashing: bool = player_node.get("is_dashing")
		return dashing
	return false

func add_score(amount: int) -> void:
	score += amount * combo
	combo = mini(combo + 1, 10)
	combo_timer = COMBO_TIMEOUT
	_mark_combat()
	if score > high_score:
		high_score = score
	emit_signal("score_changed", score, combo)

func take_player_damage(amount: float) -> void:
	if health <= 0.0:
		return
	if is_player_invulnerable():
		return
	_mark_combat()

	shield_delay_timer = shield_recharge_delay
	if shield > 0.0:
		if shield >= amount:
			shield -= amount
			amount = 0.0
			SoundManager.play("shield_hit", 1.0, 2.0)
		else:
			amount -= shield
			shield = 0.0
			SoundManager.play("shield_hit", 0.8, 4.0)
		emit_signal("shield_changed", shield, max_shield)

	if amount > 0.0:
		health = maxf(health - amount, 0.0)
		hurt_invuln_timer = HURT_INVULN_TIME
		SoundManager.play("hit", 0.9, 3.0)
		FXManager.shake(0.25, 0.15)
		emit_signal("health_changed", health, max_health)
		emit_signal("hull_damaged", amount)
		if health <= 0.0:
			SoundManager.play("explosion", 0.8, 6.0)
			submit_score(score)
			emit_signal("player_died")

func heal_player(amount: float) -> void:
	health = minf(health + amount, max_health)
	emit_signal("health_changed", health, max_health)

func recharge_shield(amount: float) -> void:
	shield = minf(shield + amount, max_shield)
	emit_signal("shield_changed", shield, max_shield)

func select_weapon(index: int) -> void:
	if index >= 0 and index < unlocked_weapons.size():
		if unlocked_weapons[index] and index != current_weapon:
			current_weapon = index
			emit_signal("weapon_changed", current_weapon, WEAPON_NAMES[current_weapon])
			SoundManager.play("weapon_swap", 1.0, -2.0)

func cycle_weapon() -> void:
	var next_w := (current_weapon + 1) % unlocked_weapons.size()
	while not unlocked_weapons[next_w] and next_w != current_weapon:
		next_w = (next_w + 1) % unlocked_weapons.size()
	select_weapon(next_w)

func cycle_weapon_backwards() -> void:
	var next_w := (current_weapon - 1 + unlocked_weapons.size()) % unlocked_weapons.size()
	while not unlocked_weapons[next_w] and next_w != current_weapon:
		next_w = (next_w - 1 + unlocked_weapons.size()) % unlocked_weapons.size()
	select_weapon(next_w)

func unlock_weapon(index: int) -> void:
	if index >= 0 and index < unlocked_weapons.size():
		var already_had: bool = unlocked_weapons[index]
		unlocked_weapons[index] = true
		select_weapon(index)
		# Weapon pickups are permanent campaign progress, including across a
		# death before the next suit-anchor checkpoint.
		if not mission_checkpoint.is_empty():
			mission_checkpoint["weapons"] = unlocked_weapons.duplicate()
			mission_checkpoint["weapon"] = current_weapon
		if not already_had:
			SoundManager.play("pickup_weapon", 1.0, 3.0)

func update_boss_health(curr: float, max_v: float) -> void:
	boss_active = true
	boss_health = curr
	boss_max_health = max_v
	emit_signal("boss_health_changed", curr, max_v)
	if curr <= 0.0:
		boss_active = false
		emit_signal("boss_defeated")
