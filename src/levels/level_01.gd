extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var camera: Camera3D = $Camera3D
@onready var hud: Control = $HUD
@onready var boss: CharacterBody3D = $Enemies/Boss

var boss_triggered: bool = false

func _ready() -> void:
	GameManager.reset_game()
	
	# Start boss disabled until player reaches boss arena (X > 75)
	if boss:
		boss.set_physics_process(false)
		boss.visible = false

func _physics_process(_delta: float) -> void:
	if not boss_triggered and player and is_instance_valid(player):
		if player.global_position.x >= 72.0:
			_trigger_boss_fight()

func _trigger_boss_fight() -> void:
	boss_triggered = true
	if boss and is_instance_valid(boss):
		boss.visible = true
		boss.set_physics_process(true)
		SoundManager.play("alarm", 0.9, 4.0)
		FXManager.shake(0.5, 0.4)
