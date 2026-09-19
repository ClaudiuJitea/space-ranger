extends Node3D

## Deep-space backdrop: MultiMesh starfield, additive nebula billboards,
## a beige ringed gas giant, and distant starship silhouettes.

@export var cinematic_menu: bool = false

var _planet: MeshInstance3D = null
var _rings: Array[MeshInstance3D] = []

func _ready() -> void:
	_create_colossal_planet()
	_create_nebulae()
	_create_starfield()
	_create_starships()

func _process(delta: float) -> void:
	if _planet:
		_planet.rotate_y(delta * 0.008)
	for ring in _rings:
		ring.rotate_y(delta * 0.008)

func _unshaded(color: Color, additive: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.disable_receive_shadows = true
	return m

func _gas_giant_albedo() -> ImageTexture:
	var w := 512
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		var v := float(y) / float(h - 1)
		var b1 := 0.5 + 0.5 * sin(v * PI * 9.0)
		var b2 := 0.5 + 0.5 * sin(v * PI * 19.0 + 1.4)
		var b3 := 0.5 + 0.5 * sin(v * PI * 4.0 + 0.6)
		var mixv := 0.48 * b1 + 0.32 * b2 + 0.20 * b3
		var cream := Color(0.93, 0.86, 0.70)
		var tan := Color(0.78, 0.66, 0.48)
		var dusk := Color(0.42, 0.33, 0.26)
		var col: Color
		if mixv > 0.55:
			col = tan.lerp(cream, (mixv - 0.55) / 0.45)
		else:
			col = dusk.lerp(tan, mixv / 0.55)
		for x in w:
			var swirl := 0.045 * sin((float(x) / float(w)) * PI * 8.0 + v * 12.0)
			img.set_pixel(x, y, Color(
				clampf(col.r + swirl, 0.0, 1.0),
				clampf(col.g + swirl * 0.7, 0.0, 1.0),
				clampf(col.b + swirl * 0.4, 0.0, 1.0)
			))
	return ImageTexture.create_from_image(img)

func _ring_albedo() -> ImageTexture:
	var s := 512
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(s * 0.5, s * 0.5)
	var max_r := s * 0.5
	for y in s:
		for x in s:
			var d := Vector2(x, y).distance_to(center) / max_r
			var alpha := 0.0
			if d > 0.50 and d < 0.56:
				alpha = 0.18
			elif d > 0.58 and d < 0.78:
				alpha = 0.42
			elif d > 0.80 and d < 0.86:
				alpha = 0.22
			elif d > 0.88 and d < 0.96:
				alpha = 0.12
			if alpha <= 0.0:
				continue
			var shade := 0.78 + 0.12 * sin(d * 40.0)
			img.set_pixel(x, y, Color(shade, shade * 0.92, shade * 0.78, alpha))
	return ImageTexture.create_from_image(img)

func _create_colossal_planet() -> void:
	var planet := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	var radius := 16.5 if cinematic_menu else 18.0
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 64
	sphere.rings = 40
	planet.mesh = sphere
	planet.position = Vector3(-8.0, 8.2, -40.0) if cinematic_menu else Vector3(16.0, 12.0, -32.0)
	planet.rotation_degrees = Vector3(12.0, 28.0, 8.0)

	var p_mat := StandardMaterial3D.new()
	p_mat.albedo_texture = _gas_giant_albedo()
	p_mat.albedo_color = Color(1.0, 0.96, 0.88)
	p_mat.metallic = 0.04
	p_mat.roughness = 0.78
	p_mat.rim_enabled = true
	p_mat.rim = 0.55
	p_mat.rim_tint = 0.25
	planet.material_override = p_mat
	add_child(planet)
	_planet = planet

	var atmo := MeshInstance3D.new()
	var atmo_sphere := SphereMesh.new()
	atmo_sphere.radius = radius * 1.045
	atmo_sphere.height = radius * 2.09
	atmo_sphere.radial_segments = 48
	atmo_sphere.rings = 32
	atmo.mesh = atmo_sphere
	atmo.position = planet.position
	var a_mat := StandardMaterial3D.new()
	a_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	a_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	a_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	a_mat.albedo_color = Color(0.55, 0.48, 0.38, 0.045)
	a_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	atmo.material_override = a_mat
	add_child(atmo)

	var ring_tilt := Vector3(deg_to_rad(68.0), deg_to_rad(14.0), deg_to_rad(-18.0))
	var ring_size := radius * 4.6
	var ring := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(ring_size, ring_size)
	ring.mesh = quad
	ring.position = planet.position
	ring.rotation = ring_tilt
	var r_mat := StandardMaterial3D.new()
	r_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	r_mat.albedo_texture = _ring_albedo()
	r_mat.albedo_color = Color(0.92, 0.86, 0.72, 0.95)
	r_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	r_mat.disable_receive_shadows = true
	ring.material_override = r_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	_rings.append(ring)

func _create_nebulae() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.55))
	gradient.set_color(1, Color(0, 0, 0, 0.0))
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = gradient
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(0.5, 0.0)
	grad_tex.width = 256
	grad_tex.height = 256

	var nebula_cfg := [
		[Vector3(-6.0, 14.0, -42.0), 70.0, Color(0.16, 0.10, 0.32, 0.50)],
		[Vector3(22.0, 6.0, -46.0), 80.0, Color(0.24, 0.08, 0.18, 0.36)],
		[Vector3(8.0, 18.0, -50.0), 55.0, Color(0.10, 0.18, 0.34, 0.40)],
	]
	if not cinematic_menu:
		nebula_cfg = [
			[Vector3(-8.0, 16.0, -45.0), 55.0, Color(0.12, 0.11, 0.22, 0.42)],
			[Vector3(45.0, 4.0, -48.0), 70.0, Color(0.22, 0.11, 0.13, 0.34)],
			[Vector3(95.0, 20.0, -50.0), 60.0, Color(0.08, 0.16, 0.19, 0.36)],
		]
	for cfg in nebula_cfg:
		var quad := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(cfg[1], cfg[1])
		quad.mesh = q
		quad.position = cfg[0]
		var n_mat := StandardMaterial3D.new()
		n_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		n_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		n_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		n_mat.albedo_texture = grad_tex
		n_mat.albedo_color = cfg[2]
		n_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		n_mat.disable_receive_shadows = true
		quad.material_override = n_mat
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(quad)

func _create_starfield() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	sphere.radial_segments = 6
	sphere.rings = 4

	var mat_star := _unshaded(Color(0.9, 0.95, 1.0))
	var mat_star_amber := _unshaded(Color(1.0, 0.75, 0.4))
	var counts := [180, 50]
	var mats := [mat_star, mat_star_amber]
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xC0FFEE

	for pass_idx in range(2):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = sphere
		mm.instance_count = counts[pass_idx]
		for i in range(counts[pass_idx]):
			var t := Transform3D()
			t = t.scaled(Vector3.ONE * rng.randf_range(0.28, 1.1))
			t.origin = Vector3(
				rng.randf_range(-50.0, 50.0),
				rng.randf_range(-18.0, 36.0),
				rng.randf_range(-20.0, -52.0)
			)
			mm.set_instance_transform(i, t)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mats[pass_idx]
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)

func _create_starships() -> void:
	var hull_mat := StandardMaterial3D.new()
	hull_mat.albedo_color = Color(0.045, 0.05, 0.07)
	hull_mat.metallic = 0.88
	hull_mat.roughness = 0.34
	var engine_mat := _unshaded(Color(0.35, 0.82, 1.0, 0.8), true)
	var window_mat := _unshaded(Color(0.55, 0.78, 0.95, 0.7), true)

	var specs := [
		[Vector3(-26.0, 12.5, -30.0), 0.85, 0.55],
		[Vector3(-32.0, 8.0, -36.0), 0.42, 0.2],
		[Vector3(14.0, 11.0, -24.0), 1.15, -0.5],
		[Vector3(22.0, 14.5, -30.0), 0.62, -0.75],
		[Vector3(9.5, 16.5, -34.0), 0.36, -0.18],
	]
	if not cinematic_menu:
		specs = [
			[Vector3(-28.0, 18.0, -30.0), 0.7, 0.4],
			[Vector3(48.0, 14.0, -36.0), 1.1, -0.5],
			[Vector3(80.0, 22.0, -40.0), 0.6, -0.2],
		]
	for spec in specs:
		var root := Node3D.new()
		root.position = spec[0]
		root.rotation = Vector3(0.08, spec[2], 0.04)
		root.scale = Vector3.ONE * spec[1]
		add_child(root)

		var hull := MeshInstance3D.new()
		var hull_mesh := BoxMesh.new()
		hull_mesh.size = Vector3(3.4, 0.42, 0.85)
		hull.mesh = hull_mesh
		hull.material_override = hull_mat
		hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(hull)

		var spine := MeshInstance3D.new()
		var spine_mesh := BoxMesh.new()
		spine_mesh.size = Vector3(4.4, 0.16, 0.22)
		spine.mesh = spine_mesh
		spine.position = Vector3(0.15, 0.06, 0.0)
		spine.material_override = hull_mat
		spine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(spine)

		for side in [-1.0, 1.0]:
			var wing := MeshInstance3D.new()
			var wing_mesh := BoxMesh.new()
			wing_mesh.size = Vector3(1.0, 0.08, 2.1)
			wing.mesh = wing_mesh
			wing.position = Vector3(-0.15, 0.0, side * 1.1)
			wing.material_override = hull_mat
			wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(wing)

		var engine := MeshInstance3D.new()
		var engine_mesh := BoxMesh.new()
		engine_mesh.size = Vector3(0.4, 0.32, 0.32)
		engine.mesh = engine_mesh
		engine.position = Vector3(-1.9, 0.0, 0.0)
		engine.material_override = engine_mat
		engine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(engine)

		var window := MeshInstance3D.new()
		var window_mesh := BoxMesh.new()
		window_mesh.size = Vector3(0.7, 0.08, 0.2)
		window.mesh = window_mesh
		window.position = Vector3(1.3, 0.16, 0.0)
		window.material_override = window_mat
		window.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(window)
