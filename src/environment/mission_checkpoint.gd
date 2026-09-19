extends Area3D

var mission: Node
var triggered := false
var label: Label3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.2, 3, 2)
	collision.shape = shape
	collision.position.y = 1.5
	add_child(collision)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.62
	torus.outer_radius = 0.70
	ring.mesh = torus
	ring.position.y = 0.04
	ring.material_override = preload("res://src/projectiles/shot_visual.gd").luminous(Color(0.15, 0.8, 1), 1.5)
	add_child(ring)
	label = Label3D.new()
	label.text = "SUIT ANCHOR"
	label.position.y = 2.3
	label.font = preload("res://assets/fonts/ShareTechMono-Regular.ttf")
	label.font_size = 24
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.15, 0.8, 1)
	add_child(label)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not triggered and body.is_in_group("player") and GameManager.health > 0:
		triggered = true
		label.text = "ANCHOR SECURED"
		mission.register_checkpoint(global_position + Vector3(1, 0.2, 0))
