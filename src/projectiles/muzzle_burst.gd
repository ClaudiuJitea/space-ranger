extends Node3D

var _age := 0.0
var _duration := 0.085
var _material: ShaderMaterial

func configure(profile: String, tint: Color) -> void:
	var reach := 0.38
	var width := 0.10
	match profile:
		"scatter":
			reach = 0.58
			width = 0.18
			_duration = 0.10
		"rail":
			reach = 0.72
			width = 0.075
			_duration = 0.12
		"rocket":
			reach = 0.32
			width = 0.16
	var flash := flare(reach, width, tint)
	add_child(flash)
	_material = flash.get_meta("flare_material")
	if profile == "rail":
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.085
		torus.outer_radius = 0.10
		ring.mesh = torus
		ring.rotation.x = PI / 2
		ring.material_override = preload("res://src/projectiles/shot_visual.gd").luminous(tint, 1.5)
		add_child(ring)

func _process(delta: float) -> void:
	_age += delta
	var fade := maxf(0, 1 - _age / _duration)
	_material.set_shader_parameter("opacity", fade * fade)
	scale = Vector3.ONE * (0.75 + fade * 0.25)
	if _age >= _duration:
		queue_free()

static func flare(length: float, width: float, tint: Color, backwards := false) -> Node3D:
	var root := Node3D.new()
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/projectiles/muzzle_flare.gdshader")
	material.set_shader_parameter("tint", tint)
	root.set_meta("flare_material", material)
	for angle in [0.0, PI / 2]:
		var side := Vector3(cos(angle), sin(angle), 0) * width
		var end := Vector3(0, 0, length if backwards else -length)
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		var vertices := [side, -side, end + side * 0.25, -side, end - side * 0.25, end + side * 0.25]
		var uvs := [Vector2(0, 0), Vector2(0, 1), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]
		for i in range(6):
			mesh.surface_set_uv(uvs[i])
			mesh.surface_add_vertex(vertices[i])
		mesh.surface_end()
		var plane := MeshInstance3D.new()
		plane.mesh = mesh
		plane.material_override = material
		plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(plane)
	return root
