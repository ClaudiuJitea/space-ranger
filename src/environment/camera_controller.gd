extends Camera3D

## Cinematic 2.5D camera. Gameplay stays on Z=0, but the offset lens, focus
## target, adaptive FOV and subtle roll expose the scene as a dimensional
## diorama instead of photographing it like a flat side scroller.

@export var target_node: NodePath
@export var follow_speed: float = 6.8
@export var look_ahead_dist: float = 4.4
@export var camera_offset := Vector3(-2.1, 4.15, 12.4)
@export var focus_height: float = 1.25
@export var base_fov: float = 44.0
@export var speed_fov_boost: float = 2.0
@export var boss_trigger_x: float = 96.0
@export var boss_focus_x: float = 110.5

var target: Node3D = null
var shake_intensity: float = 0.0
var shake_timer: float = 0.0
var trauma: float = 0.0
@export var trauma_decay: float = 1.45
var _smoothed_focus := Vector3.ZERO
var _smoothed_velocity := Vector3.ZERO
var _trauma_phase: float = 0.0
var _boss_framing: float = 0.0

func _ready() -> void:
	if not target_node.is_empty():
		target = get_node_or_null(target_node)
	if target:
		_smoothed_focus = target.global_position + Vector3.UP * focus_height
	fov = base_fov
	near = 0.15
	far = 180.0
	FXManager.connect("camera_shake_requested", _on_camera_shake)
	if FXManager.has_signal("trauma_requested"):
		FXManager.connect("trauma_requested", _on_trauma)

func _physics_process(delta: float) -> void:
	if not target or not is_instance_valid(target):
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0]
			_smoothed_focus = target.global_position + Vector3.UP * focus_height
		return

	var raw_velocity: Variant = target.get("velocity")
	var target_velocity := Vector3.ZERO
	if raw_velocity is Vector3:
		target_velocity = raw_velocity
	_smoothed_velocity = _smoothed_velocity.lerp(target_velocity, 1.0 - exp(-delta * 5.0))

	var lead_x := clampf(_smoothed_velocity.x * 0.26, -look_ahead_dist, look_ahead_dist)
	var lead_y := clampf(_smoothed_velocity.y * 0.07, -0.8, 1.25)
	var desired_focus := target.global_position + Vector3(lead_x, focus_height + lead_y, 0.0)

	var wants_boss_frame := 1.0 if target.global_position.x > boss_trigger_x else 0.0
	_boss_framing = move_toward(_boss_framing, wants_boss_frame, delta * 0.75)
	if _boss_framing > 0.0:
		desired_focus.x = lerpf(desired_focus.x, boss_focus_x, _boss_framing * 0.62)
		desired_focus.y = lerpf(desired_focus.y, 3.6, _boss_framing * 0.7)

	_smoothed_focus = _smoothed_focus.lerp(desired_focus, 1.0 - exp(-delta * follow_speed))
	var dynamic_offset := camera_offset
	dynamic_offset.z += _boss_framing * 5.0
	dynamic_offset.y += _boss_framing * 0.55
	var desired_position := _smoothed_focus + dynamic_offset
	global_position = global_position.lerp(desired_position, 1.0 - exp(-delta * follow_speed))

	var speed_ratio := clampf(absf(_smoothed_velocity.x) / 28.0, 0.0, 1.0)
	var desired_fov := base_fov + speed_ratio * speed_fov_boost + _boss_framing * 1.5
	fov = lerpf(fov, desired_fov, 1.0 - exp(-delta * 3.0))

	look_at(_smoothed_focus, Vector3.UP)
	var movement_roll := clampf(-_smoothed_velocity.x * 0.0009, -0.012, 0.012)
	rotation.z += movement_roll

	if trauma > 0.0:
		trauma = maxf(0.0, trauma - delta * trauma_decay)
		var shake := trauma * trauma
		_trauma_phase += delta * 46.0
		var offset := Vector3(
			(sin(_trauma_phase * 1.5) * 0.7 + cos(_trauma_phase * 2.3) * 0.3) * 0.65 * shake,
			(cos(_trauma_phase * 1.8) * 0.7 + sin(_trauma_phase * 2.8) * 0.3) * 0.45 * shake,
			sin(_trauma_phase * 2.1) * 0.25 * shake
		)
		global_position += offset
		rotation.z += sin(_trauma_phase * 3.2) * 0.035 * shake
		rotation.x += cos(_trauma_phase * 2.6) * 0.025 * shake
	elif shake_timer > 0.0:
		shake_timer -= delta
		_trauma_phase += delta * 42.0
		var falloff := clampf(shake_timer / 0.45, 0.0, 1.0)
		var amount := shake_intensity * falloff
		global_position += Vector3(sin(_trauma_phase * 1.7), cos(_trauma_phase * 2.3), 0.0) * amount
		rotation.z += sin(_trauma_phase * 2.9) * amount * 0.018
		rotation.y += cos(_trauma_phase * 2.1) * amount * 0.012
		shake_intensity = lerpf(shake_intensity, 0.0, 1.0 - exp(-delta * 7.0))

func _on_camera_shake(intensity: float, duration: float) -> void:
	shake_intensity = maxf(shake_intensity, intensity)
	shake_timer = maxf(shake_timer, duration)

func _on_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)
