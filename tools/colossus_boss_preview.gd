extends Node3D
func _ready() -> void:
	var environment := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color(0.018, 0.028, 0.035)
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color(0.32, 0.42, 0.5)
	sky.ambient_light_energy = 0.55
	sky.tonemap_mode = Environment.TONE_MAPPER_ACES
	sky.glow_enabled = true
	sky.ssao_enabled = true
	environment.environment = sky
	add_child(environment)
	var model: Node3D = preload("res://assets/models/campaign_bosses/warden.glb").instantiate()
	add_child(model)
	box(Vector3(0, -2.69, 0), Vector3(16, 0.16, 10), Color(0.06, 0.085, 0.095))
	for x in range(-7, 8):
		box(Vector3(x, -2.60, 0), Vector3(0.025, 0.01, 10), Color(0.015, 0.025, 0.03))
	for side in [-1, 1]:
		box(Vector3(side * 4, 0, -3), Vector3(0.8, 7, 0.9), Color(0.035, 0.05, 0.055))
		box(Vector3(side * 4, 1, -2.52), Vector3(0.05, 3, 0.05), Color(0.06, 0.3, 0.45), true)
	var camera := Camera3D.new()
	camera.position = Vector3(-6.5, 3.4, 11.5)
	camera.fov = 36
	add_child(camera)
	camera.look_at(Vector3(-0.3, -0.12, 0))
	camera.current = true
	light(Vector3(-4, 6, 6), Color(0.82, 0.92, 1), 3)
	light(Vector3(5, 3, -4), Color(0.25, 0.5, 0.75), 1.0)
	light(Vector3(2, 1, 6), Color(0.85, 0.92, 1), 0.7)
	await get_tree().create_timer(1).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/colossus-boss-preview.png")
	get_tree().quit()
func light(location: Vector3, color: Color, energy: float) -> void:
	var lamp := DirectionalLight3D.new()
	add_child(lamp)
	lamp.position = location
	lamp.look_at(Vector3.ZERO)
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.shadow_enabled = true
func box(location: Vector3, dimensions: Vector3, color: Color, glowing := false) -> void:
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	body.mesh = mesh
	body.position = location
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.6
	mat.roughness = 0.45
	if glowing:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2
	body.material_override = mat
	add_child(body)
