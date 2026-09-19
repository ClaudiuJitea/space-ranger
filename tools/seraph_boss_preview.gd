extends Node3D

func _ready() -> void:
	var environment := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color(0.015, 0.018, 0.025)
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color(0.35, 0.45, 0.55)
	sky.ambient_light_energy = 0.65
	sky.tonemap_mode = Environment.TONE_MAPPER_ACES
	sky.glow_enabled = true
	sky.glow_bloom = 0.25
	sky.glow_intensity = 1.1
	sky.ssao_enabled = true
	environment.environment = sky
	add_child(environment)

	var boss: CharacterBody3D = preload("res://src/entities/enemies/boss.tscn").instantiate()
	boss.boss_profile = 2
	add_child(boss)
	boss.position = Vector3(0, 0.2, 0)
	boss.visible = true
	boss.visual.visible = true
	boss.set_physics_process(false)
	
	var target := Node3D.new()
	add_child(target)
	target.position = Vector3(-6, -1.5, 0)
	boss.player_ref = target
	boss._warning.hide()

	# Pedestal / throne arena deck
	box(Vector3(0, -2.8, 0), Vector3(20, 0.2, 10), Color(0.06, 0.08, 0.10))
	for x in range(-9, 10, 2):
		box(Vector3(x, -2.69, 0), Vector3(0.04, 0.02, 10), Color(0.15, 0.18, 0.22))
	for side in [-1, 1]:
		box(Vector3(side * 5.5, 0, -3.5), Vector3(1.0, 9, 1.0), Color(0.04, 0.05, 0.07))
		box(Vector3(side * 5.5, 1.2, -2.9), Vector3(0.08, 4, 0.08), Color(1.0, 0.40, 0.08), true)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 0.4, 7.8)
	camera.fov = 44
	add_child(camera)
	camera.look_at(Vector3(0, 0.1, 0))
	camera.current = true

	# Three-point cinematic lighting
	light(Vector3(-5, 6, 7), Color(1.0, 0.92, 0.82), 1.8) # Key warm light
	light(Vector3(6, 4, -4), Color(0.2, 0.45, 0.8), 1.2)  # Cool cyan fill rim
	light(Vector3(0, -3, 4), Color(1.0, 0.35, 0.08), 0.8) # Upward ember bounce

	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/seraph-boss-preview.png")
	print("SERAPH BOSS PREVIEW SAVED TO /tmp/seraph-boss-preview.png")
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
	mat.metallic = 0.7
	mat.roughness = 0.4
	if glowing:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 3.0
	body.material_override = mat
	add_child(body)
