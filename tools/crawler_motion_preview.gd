extends Node3D
@export var output_dir := "res://tools/blender_previews/concept_enemies_v2"

func _ready() -> void:
	_run()

func _run() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.025, 0.035, 0.055)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.56, 0.65, 0.8)
	world.environment.ambient_light_energy = 0.5
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.18, 0.23, 0.30)
	sky_material.sky_horizon_color = Color(0.42, 0.46, 0.51)
	sky_material.ground_bottom_color = Color(0.10, 0.12, 0.16)
	sky_material.ground_horizon_color = Color(0.30, 0.33, 0.37)
	world.environment.sky = Sky.new()
	world.environment.sky.sky_material = sky_material
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	world.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment.glow_enabled = true
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -30, 0)
	key.light_energy = 1.7
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 140, 0)
	fill.light_color = Color(0.52, 0.66, 1)
	fill.light_energy = 0.8
	add_child(fill)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(camera)
	camera.make_current()
	var enemy := load("res://src/entities/enemies/crawler.tscn").instantiate() as CharacterBody3D
	add_child(enemy)
	enemy.set_physics_process(false)
	enemy.facing = 1.0
	enemy.get_node("Visual").scale.x = 1.0
	var animator := enemy.get_node("ModelAnimation")
	animator.set_process(false)
	camera.size = 2.3
	DirAccess.make_dir_recursive_absolute("/tmp/crawler_motion_frames")
	for frame in 150:
		var dt := 1.0 / 30.0
		if frame < 75:
			enemy.state = 1
			enemy.velocity = Vector3(4.6, 0, 0)
		elif frame < 90:
			enemy.state = 2
			enemy.state_timer = 0.45 - (frame - 75) * dt
			enemy.velocity = Vector3.ZERO
		elif frame < 100:
			enemy.state = 3
			enemy.state_timer = 0.32 - (frame - 90) * dt
			enemy.velocity = Vector3(7.0, 0, 0)
			enemy.position.y = sin((frame - 90) / 9.0 * PI) * 0.12
		else:
			enemy.state = 4
			enemy.state_timer = maxf(0.0, 0.7 - (frame - 100) * dt)
			enemy.velocity = Vector3.ZERO
			enemy.position.y = 0
		enemy.position.x += enemy.velocity.x * dt
		# Substeps keep the captured 30fps gait identical to the physics cadence.
		for step in 4:
			animator.locomotion.update(dt / 4.0)
		var target := enemy.position + Vector3(0, 0.32, 0)
		camera.position = target + Vector3(0.6, 0.4, 2.6)
		camera.look_at(target)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/crawler_motion_frames/%04d.png" % frame)
	print("CRAWLER MOTION PREVIEW COMPLETE")
	get_tree().quit()
