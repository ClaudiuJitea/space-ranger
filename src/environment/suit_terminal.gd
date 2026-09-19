extends StaticBody3D

@export var interaction_radius := 2.2
var activated := false
var _prompt: Label3D
var _nearby := false

func _ready() -> void:
	add_to_group("terminals")
	_prompt = Label3D.new()
	_prompt.font = preload("res://assets/fonts/ShareTechMono-Regular.ttf")
	_prompt.font_size = 32
	_prompt.pixel_size = 0.008
	_prompt.position = Vector3(0, 1.5, 0)
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.modulate = Color(0.15, 0.8, 1)
	_prompt.no_depth_test = true
	_prompt.visible = false
	add_child(_prompt)

func _physics_process(_delta: float) -> void:
	_nearby = false
	if GameManager.health > 0:
		for player in get_tree().get_nodes_in_group("player"):
			if player is Node3D and global_position.distance_to(player.global_position) <= interaction_radius:
				_nearby = true
	_prompt.visible = _nearby
	_prompt.text = "UPLINK COMPLETE" if activated else "[F] RESTORE SUIT"

func _unhandled_input(event: InputEvent) -> void:
	if _nearby and not activated and GameManager.health > 0 and event.is_action_pressed("interact"):
		activate()
		get_viewport().set_input_as_handled()

func activate() -> void:
	if activated:
		return
	activated = true
	GameManager.heal_player(25)
	GameManager.recharge_shield(40)
	GameManager.add_score(250)
	GameManager.notify("SUIT UPLINK COMPLETE // +25 HULL / +40 SHIELD", Color(0.15, 0.8, 1))
	SoundManager.play("pickup_shield", 0.9, 0)
	FXManager.spawn_shockwave(global_position + Vector3.UP * 0.8, Color(0.15, 0.8, 1), 1.5)
	$TerminalLight.light_color = Color(0.15, 1, 0.6)
