extends Node3D

## Procedural station architecture for the near, mid and far planes. These
## inexpensive meshes make the angled camera read as a miniature 3D set while
## collision and gameplay remain cleanly constrained to Z=0.

const CYAN := Color(0.12, 0.82, 1.0, 1.0)
const AMBER := Color(1.0, 0.42, 0.08, 1.0)

@export var world_end_x: int = 132
@export var alert_start_x: float = 96.0
@export var accent_color: Color = CYAN

func _ready() -> void:
	_build_recessed_deck()
	_build_depth_frames()
	_build_foreground_gantry()
	_build_bulkheads()
	_build_guidance_lights()
	_build_dust()

func _material(color: Color, metallic := 0.75, roughness := 0.38, emission := Color.BLACK) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	if emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = 1.15
	return mat

func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.rotation = rot
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
	return mesh_instance

func _build_recessed_deck() -> void:
	var deck := Node3D.new()
	deck.name = "RecessedDeck"
	add_child(deck)
	var dark := _material(Color(0.028, 0.045, 0.07), 0.9, 0.3)
	var inset := _material(Color(0.055, 0.075, 0.105), 0.78, 0.42)
	var glow := _material(Color(0.02, 0.12, 0.16), 0.2, 0.25, accent_color)
	for x in range(-6, world_end_x, 4):
		_box(deck, Vector3(float(x), -0.72, -1.75), Vector3(3.82, 0.16, 2.1), dark)
		_box(deck, Vector3(float(x), -0.61, -0.72), Vector3(3.45, 0.035, 0.055), glow)
		for z in [-2.72, -0.78]:
			_box(deck, Vector3(float(x), -0.52, z), Vector3(3.25, 0.07, 0.1), inset)

func _build_depth_frames() -> void:
	var frames := Node3D.new()
	frames.name = "MidgroundFrames"
	add_child(frames)
	var structure := _material(Color(0.035, 0.05, 0.075), 0.92, 0.3)
	var trim := _material(Color(0.025, 0.09, 0.13), 0.65, 0.25, accent_color * 0.7)
	for x in range(-4, world_end_x + 4, 8):
		_box(frames, Vector3(float(x), 4.0, -3.0), Vector3(0.32, 9.2, 0.42), structure, Vector3(0.0, 0.0, deg_to_rad(-8.0)))
		_box(frames, Vector3(float(x) + 2.1, 8.15, -3.0), Vector3(4.6, 0.3, 0.42), structure, Vector3(0.0, 0.0, deg_to_rad(-5.0)))
		_box(frames, Vector3(float(x), 6.3, -2.74), Vector3(0.08, 2.3, 0.04), trim)

func _build_foreground_gantry() -> void:
	var front := Node3D.new()
	front.name = "ForegroundGantry"
	add_child(front)
	var silhouette := _material(Color(0.012, 0.018, 0.028), 0.95, 0.25)
	var red := _material(Color(0.24, 0.075, 0.025), 0.48, 0.42)
	for x in range(-4, world_end_x, 18):
		_box(front, Vector3(x, -2.25, 2.8), Vector3(0.55, 4.0, 0.7), silhouette, Vector3(0.0, 0.0, deg_to_rad(12.0)))
		_box(front, Vector3(x + 0.48, -0.45, 2.8), Vector3(0.68, 0.08, 0.28), red)

func _build_bulkheads() -> void:
	var hull := Node3D.new()
	hull.name = "Bulkheads"
	add_child(hull)
	var plate := _material(Color(0.03, 0.042, 0.055), 0.88, 0.34)
	var rib := _material(Color(0.02, 0.08, 0.11), 0.55, 0.28, accent_color * 0.55)
	var pipe := _material(Color(0.04, 0.05, 0.06), 0.92, 0.22)
	for x in range(8, world_end_x, 16):
		_box(hull, Vector3(float(x), 2.4, -2.35), Vector3(5.6, 3.4, 0.18), plate)
		_box(hull, Vector3(float(x) - 2.4, 2.4, -2.22), Vector3(0.12, 3.1, 0.08), rib)
		_box(hull, Vector3(float(x) + 2.4, 2.4, -2.22), Vector3(0.12, 3.1, 0.08), rib)
		if x % 32 == 8:
			_box(hull, Vector3(float(x) + 0.8, 5.4, -1.6), Vector3(4.8, 0.12, 0.12), pipe, Vector3(0.0, 0.0, deg_to_rad(8.0)))
			_box(hull, Vector3(float(x) + 0.8, 5.15, -1.6), Vector3(4.8, 0.08, 0.08), pipe, Vector3(0.0, 0.0, deg_to_rad(-6.0)))
		if x % 48 == 8:
			_box(hull, Vector3(float(x), 7.6, -2.5), Vector3(0.55, 2.4, 0.55), plate)
			_box(hull, Vector3(float(x), 8.9, -2.5), Vector3(0.18, 1.6, 0.18), rib)

func _build_guidance_lights() -> void:
	var lights := Node3D.new()
	lights.name = "GuidanceLights"
	add_child(lights)
	var cyan_mat := _material(Color(0.02, 0.12, 0.16), 0.15, 0.2, accent_color)
	var amber_mat := _material(Color(0.16, 0.05, 0.01), 0.15, 0.2, AMBER)
	for x in range(-4, world_end_x, 2):
		var active_mat := amber_mat if x > alert_start_x else cyan_mat
		_box(lights, Vector3(float(x), -0.39, 0.93), Vector3(0.28, 0.055, 0.09), active_mat)

func _build_dust() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "OrbitalDust"
	particles.amount = 90
	particles.lifetime = 10.0
	particles.visibility_aabb = AABB(Vector3(-15, -8, -7), Vector3(world_end_x + 25, 24, 15))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(float(world_end_x) * 0.55, 8.0, 4.5)
	process.direction = Vector3(-0.25, 0.05, 0.0)
	process.spread = 18.0
	process.initial_velocity_min = 0.08
	process.initial_velocity_max = 0.3
	process.gravity = Vector3.ZERO
	process.scale_min = 0.015
	process.scale_max = 0.055
	process.color = Color(0.55, 0.62, 0.68, 0.24)
	particles.process_material = process
	var mote := SphereMesh.new()
	mote.radius = 0.035
	mote.height = 0.07
	mote.material = _material(Color(0.5, 0.58, 0.64, 0.32), 0.0, 1.0)
	particles.draw_pass_1 = mote
	particles.position = Vector3(float(world_end_x) * 0.45, 5.0, 0.0)
	add_child(particles)
