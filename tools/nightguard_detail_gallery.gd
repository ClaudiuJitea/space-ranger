extends Node3D
const OUTPUT := "res://tools/blender_previews/nightguard_detail"
func _ready() -> void:
	print("GALLERY READY")
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

	camera.size = 2.5
	for kind in ["enforcer", "drone"]:
		var enemy = load("res://src/entities/enemies/%s.tscn" % kind).instantiate()
		print("INSTANTIATING ", kind)
		add_child(enemy)
		enemy.set_physics_process(false)
		await get_tree().process_frame
		await get_tree().process_frame
		var animator = enemy.get_node("ModelAnimation")
		assert(animator.player != null, "Missing imported animation player")
		assert(animator.aim_solver != null and animator.muzzle != null, "Missing rifle aim or muzzle")
		for clip in ["Idle", "Walk", "Run"]:
			assert(animator.player.has_animation(clip), "Missing locomotion clip " + clip)
		print("BOUND ", kind)
		for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3(1, 1, 0).normalized(), Vector3(-1, -1, 0).normalized(), Vector3.UP, Vector3.DOWN]:
			enemy.get_node("Visual").rotation.y = -PI * 0.5 * (-1.0 if direction.x < 0 else 1.0)
			for frame in range(12):
				animator.update_visual(3.1, direction, kind == "drone")
				await get_tree().process_frame
			print("AIM CHECK ", kind, " ", direction, " error=", animator.aim_solver.support_error)
			assert(animator.aim_solver.support_error < 0.05, "Support hand cannot reach rifle")
			assert(animator.get_muzzle_position().is_finite())
		enemy.get_node("Visual").rotation.y = -PI * 0.5
		for view in ["front", "side", "back"]:
			var target := Vector3(0, 0.9, 0)
			camera.position = target + (Vector3(2.5, 0.8, 4) if view == "front" else (Vector3(0, 0.2, 4) if view == "side" else Vector3(-2.5, 0.8, -4)))
			camera.look_at(target)
			for frame in range(35):
				animator.update_visual(0.0, Vector3(1, 0.1, 0), kind == "drone")
				await get_tree().process_frame
			print("CAPTURE ", kind, " ", view)
			RenderingServer.force_draw(false)
			get_viewport().get_texture().get_image().save_png(OUTPUT + "/godot_%s_%s.png" % [kind, view])
		print("NIGHTGUARD VERIFIED: ", kind, " clips=", animator.player.get_animation_list(), " muzzle=", animator.get_muzzle_position(), " support_error=", animator.aim_solver.support_error)
		enemy.queue_free()
		await get_tree().process_frame
	for level_path in ["res://src/levels/level_01.tscn", "res://src/levels/level_02.tscn"]:
		assert(load(level_path) != null)
	print("NIGHTGUARD GALLERY COMPLETE")
	get_tree().quit()
