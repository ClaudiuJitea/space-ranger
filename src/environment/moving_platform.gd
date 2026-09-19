extends AnimatableBody3D

@export var travel := Vector3(0, 4, 0)
@export var period := 5.0
var origin := Vector3.ZERO
var elapsed := 0.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true
	origin = position
	var model := preload("res://assets/models/platform_straight.glb").instantiate()
	add_child(model)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 0.4, 1.6)
	collision.shape = shape
	collision.position.y = -0.2
	add_child(collision)
	var light := OmniLight3D.new()
	light.position.y = 0.3
	light.light_color = Color(0.15, 0.85, 1)
	light.light_energy = 0.45
	light.omni_range = 3
	add_child(light)

func _physics_process(delta: float) -> void:
	elapsed += delta
	position = origin + travel * (0.5 - 0.5 * cos(TAU * elapsed / period))
