extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var camera: Camera3D = $Camera3D
@onready var hud: Control = $HUD
@onready var boss: CharacterBody3D = $Enemies/Boss

var boss_triggered: bool = false

func _ready() -> void:
	GameManager.reset_game()
	
	if boss:
		boss.set_physics_process(false)
		boss.visible = false

	if "--screenshot" in OS.get_cmdline_user_args() or "--screenshot" in OS.get_cmdline_args():
		_capture_and_quit()

func _capture_and_quit() -> void:
	await get_tree().create_timer(0.5).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/screenshot.png")
	get_tree().quit()

func _physics_process(_delta: float) -> void:
	if not boss_triggered and player and is_instance_valid(player):
		if player.global_position.x >= 72.0:
			_trigger_boss_fight()

func _trigger_boss_fight() -> void:
	boss_triggered = true
	if boss and is_instance_valid(boss):
		boss.activate_boss()
		SoundManager.play("alarm", 0.9, 4.0)
		FXManager.shake(0.5, 0.4)
