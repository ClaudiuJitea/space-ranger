extends Node3D

## Geometry stays aligned to the barrel; ribbons retain actual world-space history.
const TRAIL_SHADER := preload("res://src/projectiles/shot_trail.gdshader")
var profile := "pulse"
var tint := Color.CYAN
var direction := Vector3.RIGHT
var _history: Array[Vector3] = []
var _ribbon: MeshInstance3D
var _mesh := ImmediateMesh.new()
var _material: ShaderMaterial
var _width := 0.06
var _samples := 4
var _age := 0.0
var _depth := 0.0

func configure(kind: String, color: Color, heading: Vector3, launch_depth := 0.0) -> void:
	profile = kind
	tint = color
	direction = heading.normalized()
	_depth = launch_depth
	for child in get_children():
		child.queue_free()
	_history.clear()
	_age = 0
	var length := 0.48
	var radius := 0.035
	_width = 0.085
	_samples = 4
	match profile:
		"scatter":
			length = 0.22
			radius = 0.026
			_width = 0.045
			_samples = 4
		"rail":
			length = 1.1
			radius = 0.022
			_width = 0.11
			_samples = 12
		"enemy":
			length = 0.28
			radius = 0.045
			_width = 0.055
			_samples = 5
		"emp":
			length = 0.18
			radius = 0.07
			_width = 0.13
			_samples = 9
	var core := CylinderMesh.new()
	core.top_radius = 0
	core.bottom_radius = radius
	core.height = length
	core.radial_segments = 8
	var needle := MeshInstance3D.new()
	needle.name = "ShotCore"
	needle.mesh = core
	needle.rotation.x = -PI / 2
	needle.material_override = luminous(tint.lightened(0.8), 2.0)
	add_child(needle)
	if profile == "emp":
		for i in range(2):
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.11 + i * 0.045
			torus.outer_radius = torus.inner_radius + 0.014
			ring.mesh = torus
			ring.rotation.x = PI / 2
			ring.material_override = luminous(tint, 2.0)
			add_child(ring)
	_ribbon = MeshInstance3D.new()
	_ribbon.name = "FlightRibbon"
	_ribbon.top_level = true
	_ribbon.mesh = _mesh
	_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = TRAIL_SHADER
	_material.set_shader_parameter("tint", tint)
	_material.set_shader_parameter("strength", 2.2 if profile == "rail" else 1.3)
	_ribbon.material_override = _material
	add_child(_ribbon)
	_ribbon.global_transform = Transform3D.IDENTITY
	position = global_basis.inverse() * Vector3(0, 0, _depth)
	_history.append(global_position)

static func luminous(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material

func advance(delta: float) -> void:
	_age += delta
	position = global_basis.inverse() * Vector3(0, 0, _depth * maxf(0, 1 - _age / 0.09))
	_history.push_front(global_position)
	while _history.size() > _samples:
		_history.pop_back()
	_mesh.clear_surfaces()
	if _history.size() < 2:
		return
	var side := Vector3(-direction.y, direction.x, 0).normalized()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _history.size():
		var progress := float(i) / float(_history.size() - 1)
		var half_width := _width * (1 - progress * 0.85)
		_mesh.surface_set_uv(Vector2(progress, 0))
		_mesh.surface_add_vertex(_history[i] - side * half_width)
		_mesh.surface_set_uv(Vector2(progress, 1))
		_mesh.surface_add_vertex(_history[i] + side * half_width)
	_mesh.surface_end()

func release_trail() -> void:
	if not is_instance_valid(_ribbon) or _history.size() < 2:
		return
	_ribbon.reparent(get_parent().get_parent())
	var trail := _ribbon
	var material := _material
	var tween := trail.create_tween()
	tween.tween_method(func(value: float): material.set_shader_parameter("opacity", value), 1.0, 0.0, 0.14)
	tween.tween_callback(trail.queue_free)
