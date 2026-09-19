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
	for kind in ["crawler", "turret", "gunship", "boss"]:
		var enemy := load("res://src/entities/enemies/%s.tscn" % kind).instantiate() as CharacterBody3D
		add_child(enemy)
		enemy.set_physics_process(false)
		enemy.get_node("ModelAnimation").set_process(false)
		var span := 4.5 if kind == "boss" else 2.3
		var target := Vector3(0, 0.35 if kind in ["crawler", "turret"] else 0.15, 0)
		camera.size = span
		camera.position = target + Vector3(span * 0.65, span * 0.45, span * 1.2)
		camera.look_at(target)
		await get_tree().create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output_dir + "/godot_%s.png" % kind)
		camera.position = target + Vector3(0, 0.15, span * 1.2)
		camera.look_at(target)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output_dir + "/godot_%s_side.png" % kind)
		enemy.queue_free()
		await get_tree().process_frame
	print("GODOT REFERENCE GALLERY COMPLETE")
	get_tree().quit()
