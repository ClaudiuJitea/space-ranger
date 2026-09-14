extends Node

signal health_changed(current: float, max_val: float)
signal shield_changed(current: float, max_val: float)
signal score_changed(new_score: int, combo: int)
signal weapon_changed(index: int, weapon_name: String)
signal boss_health_changed(current: float, max_val: float)
signal boss_defeated()
signal player_died()
signal level_completed()

var score: int = 0
var high_score: int = 0
var combo: int = 1
var combo_timer: float = 0.0
const COMBO_TIMEOUT: float = 3.5

var max_health: float = 100.0
var health: float = 100.0
var max_shield: float = 80.0
var shield: float = 80.0
var shield_recharge_rate: float = 15.0 # per second
var shield_recharge_delay: float = 3.0
var shield_delay_timer: float = 0.0

var unlocked_weapons: Array[bool] = [true, false, false] # Pulse, Spread, Beam
var current_weapon: int = 0
const WEAPON_NAMES: Array[String] = ["PULSE BLASTER", "PLASMA SCATTER", "PHOTON RAILGUN"]

var boss_active: bool = false
var boss_health: float = 1000.0
var boss_max_health: float = 1000.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset_game()

func reset_game() -> void:
	score = 0
	combo = 1
	combo_timer = 0.0
	health = max_health
	shield = max_shield
	shield_delay_timer = 0.0
	unlocked_weapons = [true, false, false]
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
	
	# Shield recharge
	if shield < max_shield and health > 0:
		if shield_delay_timer > 0.0:
			shield_delay_timer -= delta
		else:
			shield = minf(shield + shield_recharge_rate * delta, max_shield)
			emit_signal("shield_changed", shield, max_shield)

func add_score(amount: int) -> void:
	score += amount * combo
	combo = mini(combo + 1, 10)
	combo_timer = COMBO_TIMEOUT
	if score > high_score:
		high_score = score
	emit_signal("score_changed", score, combo)

func take_player_damage(amount: float) -> void:
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
		SoundManager.play("hit", 0.9, 3.0)
		emit_signal("health_changed", health, max_health)
		if health <= 0.0:
			SoundManager.play("explosion", 0.8, 6.0)
			emit_signal("player_died")

func heal_player(amount: float) -> void:
	health = minf(health + amount, max_health)
	emit_signal("health_changed", health, max_health)

func recharge_shield(amount: float) -> void:
	shield = minf(shield + amount, max_shield)
	emit_signal("shield_changed", shield, max_shield)

func select_weapon(index: int) -> void:
	if index >= 0 and index < unlocked_weapons.size():
		if unlocked_weapons[index]:
			current_weapon = index
			emit_signal("weapon_changed", current_weapon, WEAPON_NAMES[current_weapon])
			SoundManager.play("pickup_energy", 1.4, -2.0)

func cycle_weapon() -> void:
	var next_w := (current_weapon + 1) % unlocked_weapons.size()
	while not unlocked_weapons[next_w] and next_w != current_weapon:
		next_w = (next_w + 1) % unlocked_weapons.size()
	select_weapon(next_w)

func unlock_weapon(index: int) -> void:
	if index >= 0 and index < unlocked_weapons.size():
		unlocked_weapons[index] = true
		select_weapon(index)
		SoundManager.play("pickup_weapon", 1.0, 3.0)

func update_boss_health(curr: float, max_v: float) -> void:
	boss_active = true
	boss_health = curr
	boss_max_health = max_v
	emit_signal("boss_health_changed", curr, max_v)
	if curr <= 0.0:
		boss_active = false
		emit_signal("boss_defeated")
