extends Area3D

## High-Intensity Sweeping Thermal Beam Cannon
## Telegraphs with a warning line, then sweeps a devastating particle beam across the arena.

@export var damage: float = 24.0
@export var sweep_duration: float = 1.4
@export var beam_length: float = 28.0

var boss_ref: Node3D = null
var current_angle: float = 0.0
var start_angle: float = -0.35
var end_angle: float = 0.35
var _timer: float = 0.0
var _is_firing: bool = false
var _hit_player: bool = false
var _hit_cooldown: float = 0.0

var _beam_mesh: MeshInstance3D
var _core_mesh: MeshInstance3D
var _collision_shape: CollisionShape3D

func _ready() -> void:
	connect("body_entered", _on_body_entered)
	_setup_visuals()

func _setup_visuals() -> void:
	_collision_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(beam_length, 0.5, 1.5)
	_collision_shape.shape = box
	_collision_shape.position = Vector3(beam_length * 0.5, 0, 0)
	add_child(_collision_shape)
	_collision_shape.disabled = true

	# Outer glowing beam cylinder
	_beam_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.22
	cyl.bottom_radius = 0.22
	cyl.height = beam_length
	_beam_mesh.mesh = cyl
	_beam_mesh.rotation.z = PI * 0.5
	_beam_mesh.position = Vector3(beam_length * 0.5, 0, 0)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.35, 0.05, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_mesh.material_override = mat
	add_child(_beam_mesh)

	# Inner hot white-yellow core
	_core_mesh = MeshInstance3D.new()
	var core_cyl := CylinderMesh.new()
	core_cyl.top_radius = 0.09
	core_cyl.bottom_radius = 0.09
	core_cyl.height = beam_length
	_core_mesh.mesh = core_cyl
	_core_mesh.rotation.z = PI * 0.5
	_core_mesh.position = Vector3(beam_length * 0.5, 0, 0)

	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color(1.0, 0.9, 0.7, 0.95)
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_core_mesh.material_override = core_mat
	add_child(_core_mesh)

func init_beam(boss: Node3D, origin_pos: Vector3, facing_dir: float, sweep_upward: bool = true) -> void:
	boss_ref = boss
	global_position = origin_pos
	global_position.z = 0.0
	
	if facing_dir < 0:
		start_angle = PI + (0.35 if sweep_upward else -0.35)
		end_angle = PI + (-0.35 if sweep_upward else 0.35)
	else:
		start_angle = -0.35 if sweep_upward else 0.35
		end_angle = 0.35 if sweep_upward else -0.35

	current_angle = start_angle
	rotation.z = current_angle
	_is_firing = true
	_collision_shape.disabled = false
	SoundManager.play("laser_beam", 0.8, 4.0)
	FXManager.shake(0.4, sweep_duration * 0.8)

func _physics_process(delta: float) -> void:
	if not _is_firing:
		return

	_timer += delta
	var progress := clampf(_timer / sweep_duration, 0.0, 1.0)
	current_angle = lerp_angle(start_angle, end_angle, progress)
	rotation.z = current_angle

	# Follow boss chest if boss moves
	if is_instance_valid(boss_ref):
		global_position.x = boss_ref.global_position.x
		global_position.y = boss_ref.global_position.y + 0.5
		global_position.z = 0.0

	# Pulse beam thickness
	var pulse := 1.0 + sin(_timer * 35.0) * 0.15
	_beam_mesh.scale.y = pulse
	_beam_mesh.scale.z = pulse

	# Sizzle sparks at end of beam
	var tip := global_position + Vector3(cos(current_angle), sin(current_angle), 0) * (beam_length * 0.6)
	if fmod(_timer, 0.08) < delta:
		FXManager.spawn_hit_spark(tip, Color(1.0, 0.5, 0.1))

	if _hit_cooldown > 0.0:
		_hit_cooldown -= delta

	if progress >= 1.0:
		_is_firing = false
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and _hit_cooldown <= 0.0:
		_hit_cooldown = 0.4
		GameManager.take_player_damage(int(damage))
		SoundManager.play("hit", 1.2, 0.0)
		FXManager.spawn_hit_spark(body.global_position, Color(1.0, 0.4, 0.1))
		if body is CharacterBody3D:
			body.velocity.x += 8.0 * (1.0 if cos(current_angle) >= 0 else -1.0)
			body.velocity.y += 4.0
