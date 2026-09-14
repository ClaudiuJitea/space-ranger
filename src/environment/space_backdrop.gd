extends Node3D

func _ready() -> void:
	_create_colossal_planet()
	_create_starfield()
	_create_station_silhouettes()

func _create_colossal_planet() -> void:
	# Prominent ringed planet visible directly from the start
	var planet := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 18.0
	sphere.height = 36.0
	sphere.radial_segments = 36
	sphere.rings = 24
	planet.mesh = sphere
	planet.position = Vector3(16.0, 12.0, -32.0)

	var p_mat := StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.18, 0.24, 0.35)
	p_mat.metallic = 0.15
	p_mat.roughness = 0.75
	p_mat.rim_enabled = true
	p_mat.rim = 1.0
	p_mat.rim_tint = 0.4
	planet.material_override = p_mat
	add_child(planet)

	# Planetary Dust Rings
	var rings := MeshInstance3D.new()
	var torus := CylinderMesh.new()
	torus.top_radius = 30.0
	torus.bottom_radius = 30.0
	torus.height = 0.25
	rings.mesh = torus
	rings.position = planet.position
	rings.rotation = Vector3(deg_to_rad(28.0), deg_to_rad(15.0), deg_to_rad(-22.0))

	var r_mat := StandardMaterial3D.new()
	r_mat.albedo_color = Color(0.4, 0.45, 0.55, 0.55)
	r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	r_mat.metallic = 0.3
	r_mat.roughness = 0.8
	rings.material_override = r_mat
	add_child(rings)

func _create_starfield() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2

	var mat_star := StandardMaterial3D.new()
	mat_star.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_star.albedo_color = Color(0.9, 0.95, 1.0)

	var mat_star_amber := StandardMaterial3D.new()
	mat_star_amber.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_star_amber.albedo_color = Color(1.0, 0.75, 0.4)

	for i in range(180):
		var star := MeshInstance3D.new()
		star.mesh = sphere
		star.material_override = mat_star if (i % 4 != 0) else mat_star_amber
		star.position = Vector3(
			randf_range(-40.0, 140.0),
			randf_range(-15.0, 35.0),
			randf_range(-18.0, -42.0)
		)
		var s := randf_range(0.35, 1.2)
		star.scale = Vector3(s, s, s)
		add_child(star)

func _create_station_silhouettes() -> void:
	var mat_station := StandardMaterial3D.new()
	mat_station.albedo_color = Color(0.05, 0.06, 0.09)
	mat_station.metallic = 0.85
	mat_station.roughness = 0.4

	for i in range(16):
		var truss := MeshInstance3D.new()
		var box := BoxMesh.new()
		var h := randf_range(14.0, 30.0)
		box.size = Vector3(randf_range(1.2, 2.5), h, randf_range(1.0, 2.0))
		truss.mesh = box
		truss.material_override = mat_station
		truss.position = Vector3(
			-20.0 + i * 10.0 + randf_range(-3.0, 3.0),
			randf_range(-2.0, 12.0),
			randf_range(-12.0, -18.0)
		)
		truss.rotation = Vector3(0, 0, randf_range(-0.1, 0.1))
		add_child(truss)
