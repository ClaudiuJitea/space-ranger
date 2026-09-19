extends StaticBody3D

var mission: Node
var relay_id := ""
var relay_number := 1
var relay_total := 2
var active := false
var nearby := false
var label: Label3D
var light: OmniLight3D

func _ready() -> void:
	add_to_group("mission_relays")
	var model := preload("res://assets/models/prop_terminal.glb").instantiate()
	add_child(model)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.55, 1.1, 0.5)
	collision.shape = shape
	collision.position.y = 0.55
	add_child(collision)
	label = Label3D.new()
	label.position.y = 1.7
	label.font = preload("res://assets/fonts/ShareTechMono-Regular.ttf")
	label.font_size = 28
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
	light = OmniLight3D.new()
	light.position.y = 1.2
	light.light_energy = 1.1
	light.omni_range = 3
	add_child(light)
	active = GameManager.mission_relays.has(relay_id)
	_update_label()

func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	nearby = player != null and player.global_position.distance_to(global_position) < 2.3
	label.visible = player != null and absf(player.global_position.x - global_position.x) < 18
	active = GameManager.mission_relays.has(relay_id)
	_update_label()

func _update_label() -> void:
	label.text = "RELAY %d/%d // SYNCED" % [relay_number, relay_total] if active else ("[F] SYNC RELAY %d/%d" % [relay_number, relay_total] if nearby else "RELAY %d/%d // APPROACH" % [relay_number, relay_total])
	label.modulate = Color(0.15, 1, 0.65) if active else Color(0.9, 0.65, 0.2)
	light.light_color = label.modulate

func _input(event: InputEvent) -> void:
	if nearby and not active and GameManager.health > 0 and event.is_action_pressed("interact"):
		activate()
		get_viewport().set_input_as_handled()

func activate() -> void:
	if active:
		return
	active = true
	mission.register_relay(relay_id)
	_update_label()
	SoundManager.play("pickup_shield", 1.1, -4)
	FXManager.spawn_shockwave(global_position + Vector3.UP, Color(0.15, 1, 0.65), 1.5)
