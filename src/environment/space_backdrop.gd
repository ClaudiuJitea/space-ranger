extends Node3D

# Cinematic Hard Sci-Fi Space Backdrop:
# Features a colossal ringed planet, orbital station silhouettes, nebulae, and starfields

func _ready() -> void:
	_create_colossal_planet()
	_create_starfield()
	_create_station_silhouettes()

func _create_colossal_planet() -> void:
	# Giant Gas Giant Planet in deep background (Z = -60)
	var planet := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 28.0
	sphere.height = 56.0
	sphere.radial_segments = 32
	sphere.rings = 24
	planet.mesh = sphere
	planet.position = Vector3(60.0, -15.0, -70.0)

	var p_mat := StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.18, 0.22, 0.32) # Cold atmospheric indigo
	p_mat.metallic = 0.2
	p_mat.roughness = 0.8
	p_mat.rim_enabled = true
	p_mat.rim = 0.8
	p_mat.rim_tint = 0.5
	planet.material_override = p_mat
	add_child(planet)

	# Planetary Rings
	var rings := MeshInstance3D.new()
	var torus := CylinderMesh.new()
	torus.top_radius = 46.0
	torus.bottom_radius = 46.0
	torus.height = 0.4
	rings.mesh = torus
	rings.position = planet.position
	rings.rotation = Vector3(math_deg(28.0), math_deg(15.0), math_deg(-20.0))

	var r_mat := StandardMaterial3D.new()
	r_mat.albedo_color = Color(0.35, 0.38, 0.45, 0.6)
	r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	r_mat.metallic = 0.4
	r_mat.roughness = 0.7
	rings.material_override = r_mat
	add_child(rings)

func math_deg(d: float) -> float:
	return deg_to_rad(d)

func _create_starfield() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24

	var mat_star := StandardMaterial3D.new()
	mat_star.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_star.albedo_color = Color(0.9, 0.94, 1.0)

	var mat_star_amber := StandardMaterial3D.new()
	mat_star_amber.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_star_amber.albedo_color = Color(1.0, 0.75, 0.4)

	for i in range(160):
		var star := MeshInstance3D.new()
		star.mesh = sphere
		star.material_override = mat_star if (i % 5 != 0) else mat_star_amber
		star.position = Vector3(
			randf_range(-50.0, 160.0),
			randf_range(-30.0, 50.0),
			randf_range(-25.0, -55.0)
		)
		var s := randf_range(0.3, 1.3)
		star.scale = Vector3(s, s, s)
		add_child(star)

func _create_station_silhouettes() -> void:
	# Distant orbital station trusses and industrial modules
	var mat_station := StandardMaterial3D.new()
	mat_station.albedo_color = Color(0.04, 0.05, 0.07)
	mat_station.metallic = 0.9
	mat_station.roughness = 0.4

	for i in range(14):
		var truss := MeshInstance3D.new()
		var box := BoxMesh.new()
		var h := randf_range(12.0, 32.0)
		box.size = Vector3(randf_range(1.2, 3.0), h, randf_range(1.2, 3.0))
		truss.mesh = box
		truss.material_override = mat_station
		truss.position = Vector3(
			-30.0 + i * 14.0 + randf_range(-4.0, 4.0),
			randf_range(-5.0, 15.0),
			randf_range(-14.0, -22.0)
		)
		truss.rotation = Vector3(0, 0, randf_range(-0.15, 0.15))
		add_child(truss)
