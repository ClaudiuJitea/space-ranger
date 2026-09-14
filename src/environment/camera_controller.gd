extends Camera3D

@export var target_node: NodePath
@export var follow_speed: float = 6.5
@export var look_ahead_dist: float = 3.0
@export var fixed_z: float = 14.0

var target: Node3D = null
var shake_intensity: float = 0.0
var shake_timer: float = 0.0

func _ready() -> void:
	if not target_node.is_empty():
		target = get_node(target_node)
	FXManager.connect("camera_shake_requested", _on_camera_shake)

func _physics_process(delta: float) -> void:
	if not target or not is_instance_valid(target):
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0]
		return

	# Calculate desired target position with look-ahead
	var target_pos := target.global_position
	var look_ahead := Vector3.ZERO
	if target.has_method("get_velocity"):
		var vel: Vector3 = target.get_velocity()
		look_ahead.x = clampf(vel.x * 0.2, -look_ahead_dist, look_ahead_dist)

	var desired_pos := Vector3(target_pos.x + look_ahead.x, target_pos.y + 1.2, fixed_z)
	global_position = global_position.lerp(desired_pos, follow_speed * delta)

	# Camera Shake
	if shake_timer > 0.0:
		shake_timer -= delta
		var offset := Vector3(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity),
			0.0
		)
		global_position += offset
		shake_intensity = lerpf(shake_intensity, 0.0, 10.0 * delta)

func _on_camera_shake(intensity: float, duration: float) -> void:
	shake_intensity = maxf(shake_intensity, intensity)
	shake_timer = maxf(shake_timer, duration)
