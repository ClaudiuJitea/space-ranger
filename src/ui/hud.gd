extends Control

@onready var health_bar: ProgressBar = $TopLeft/VBox/HealthContainer/HealthBar
@onready var shield_bar: ProgressBar = $TopLeft/VBox/ShieldContainer/ShieldBar
@onready var health_label: Label = $TopLeft/VBox/HealthContainer/HealthLabel
@onready var shield_label: Label = $TopLeft/VBox/ShieldContainer/ShieldLabel
@onready var score_label: Label = $TopRight/ScoreContainer/ScoreLabel
@onready var combo_label: Label = $TopRight/ScoreContainer/ComboLabel

@onready var weapon_label: Label = $BottomLeft/WeaponContainer/WeaponLabel
@onready var weapon_icon: Label = $BottomLeft/WeaponContainer/WeaponIcon
@onready var heat_bar: ProgressBar = $BottomLeft/WeaponContainer/HeatBar
@onready var emp_label: Label = $BottomLeft/WeaponContainer/EMPLabel

@onready var boss_container: VBoxContainer = $TopCenter/BossContainer
@onready var boss_bar: ProgressBar = $TopCenter/BossContainer/BossBar
@onready var boss_name_label: Label = $TopCenter/BossContainer/BossNameLabel

@onready var victory_panel: PanelContainer = $VictoryPanel
@onready var game_over_panel: PanelContainer = $GameOverPanel

var target_health: float = 100.0
var target_shield: float = 80.0
var target_boss_health: float = 1000.0
var player_ref: Node3D = null

func _ready() -> void:
	boss_container.visible = false
	victory_panel.visible = false
	game_over_panel.visible = false
	
	GameManager.connect("health_changed", _on_health_changed)
	GameManager.connect("shield_changed", _on_shield_changed)
	GameManager.connect("score_changed", _on_score_changed)
	GameManager.connect("weapon_changed", _on_weapon_changed)
	GameManager.connect("boss_health_changed", _on_boss_health_changed)
	GameManager.connect("boss_defeated", _on_boss_defeated)
	GameManager.connect("player_died", _on_player_died)
	GameManager.connect("level_completed", _on_level_completed)

	_on_health_changed(GameManager.health, GameManager.max_health)
	_on_shield_changed(GameManager.shield, GameManager.max_shield)
	_on_score_changed(GameManager.score, GameManager.combo)
	_on_weapon_changed(GameManager.current_weapon, GameManager.WEAPON_NAMES[GameManager.current_weapon])

func _process(delta: float) -> void:
	health_bar.value = lerpf(health_bar.value, target_health, 12.0 * delta)
	shield_bar.value = lerpf(shield_bar.value, target_shield, 15.0 * delta)
	if boss_container.visible:
		boss_bar.value = lerpf(boss_bar.value, target_boss_health, 10.0 * delta)

	# Fetch player state for heat and secondary EMP
	if not player_ref:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_ref = players[0]

	if player_ref and is_instance_valid(player_ref):
		if "heat" in player_ref and heat_bar:
			heat_bar.value = player_ref.heat
			if player_ref.is_overheated:
				heat_bar.modulate = Color(1.0, 0.2, 0.2)
			else:
				heat_bar.modulate = Color(1.0, 0.65, 0.2)

		if "secondary_cooldown" in player_ref and emp_label:
			if player_ref.secondary_cooldown <= 0.0:
				emp_label.text = "[E/Q] EMP GRENADE: READY"
				emp_label.modulate = Color(0.4, 0.85, 1.0)
			else:
				emp_label.text = "[E/Q] EMP: %.1fs" % player_ref.secondary_cooldown
				emp_label.modulate = Color(0.6, 0.6, 0.6)

func _on_health_changed(curr: float, max_v: float) -> void:
	target_health = curr
	health_bar.max_value = max_v
	health_label.text = "%d / %d" % [int(curr), int(max_v)]

func _on_shield_changed(curr: float, max_v: float) -> void:
	target_shield = curr
	shield_bar.max_value = max_v
	shield_label.text = "%d / %d" % [int(curr), int(max_v)]

func _on_score_changed(new_score: int, combo: int) -> void:
	score_label.text = "%06d" % new_score
	if combo > 1:
		combo_label.visible = true
		combo_label.text = "COMBAT MULTIPLIER x%d" % combo
		var tween := create_tween()
		tween.tween_property(combo_label, "scale", Vector2(1.15, 1.15), 0.08)
		tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.08)
	else:
		combo_label.visible = false

func _on_weapon_changed(index: int, w_name: String) -> void:
	weapon_label.text = w_name
	match index:
		0: weapon_icon.text = "SLOT 1 // KINETIC PULSE"
		1: weapon_icon.text = "SLOT 2 // SCATTER SPREAD"
		2: weapon_icon.text = "SLOT 3 // PHOTON RAILGUN"

func _on_boss_health_changed(curr: float, max_v: float) -> void:
	boss_container.visible = true
	boss_bar.max_value = max_v
	target_boss_health = curr

func _on_boss_defeated() -> void:
	boss_container.visible = false

func _on_player_died() -> void:
	game_over_panel.visible = true
	$GameOverPanel/VBox/ScoreFinal.text = "FINAL SCORE: %06d" % GameManager.score

func _on_level_completed() -> void:
	victory_panel.visible = true
	$VictoryPanel/VBox/ScoreVictory.text = "FINAL SCORE: %06d" % GameManager.score

func _on_restart_pressed() -> void:
	GameManager.reset_game()
	get_tree().reload_current_scene()
