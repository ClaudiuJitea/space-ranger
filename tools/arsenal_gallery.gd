extends Node3D
## Neutral, bounds-framed renders of the actual imported refit assets.
var camera: Camera3D
var heading: Label
func _ready() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.012, 0.023, 0.04)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.65, 0.75, 0.9)
	settings.ambient_light_energy = 0.55
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.glow_enabled = true
	settings.glow_intensity = 0.18
	environment.environment = settings
	add_child(environment)
	for data in [[Vector3(-35, -30, 0), Color(0.85, 0.94, 1), 1.5], [Vector3(-20, 150, 0), Color(0.18, 0.65, 1), 1.0]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = data[0]
		light.light_color = data[1]
		light.light_energy = data[2]
		add_child(light)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 36
	camera.near = 0.01
	add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	heading = Label.new()
	heading.position = Vector2(40, 30)
	heading.add_theme_font_override("font", preload("res://assets/fonts/ShareTechMono-Regular.ttf"))
	heading.add_theme_font_size_override("font_size", 22)
	heading.modulate = Color(0.2, 0.85, 1)
	layer.add_child(heading)
	run.call_deferred()
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/arsenal")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/arsenal_refit/manifest.json"))
	for asset in manifest:
		var args := OS.get_cmdline_user_args()
		if not args.is_empty() and asset != args[0]: continue
		var model: Node3D = load(manifest[asset].model).instantiate()
		add_child(model)
		if manifest[asset].category == "weapon": model.rotation = Vector3(PI / 2, -PI / 2, 0)
		if asset in ["enforcer", "scout", "apex"]:
			model.rotation.y = PI * 1.2
			var animation := model.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
			if animation and animation.has_animation("Idle"): animation.play("Idle")
		await get_tree().process_frame
		var low := Vector3(INF, INF, INF)
		var high := Vector3(-INF, -INF, -INF)
		for node in model.find_children("*", "MeshInstance3D", true, false):
			var bounds: AABB = node.get_aabb()
			for index in range(8):
				var point: Vector3 = node.global_transform * bounds.get_endpoint(index)
				low = low.min(point)
				high = high.max(point)
		var target := (low + high) * 0.5
		var size := high - low
		var distance := maxf(size.y * 2.6, maxf(size.x * 1.4, size.z * 2.0))
		# Skinned mesh bounds are in bind space; frame humanoids in metres.
		if asset in ["enforcer", "scout", "apex"]:
			target = Vector3(0, 1, 0)
			distance = 4.6
		camera.position = target + Vector3(distance * 0.24, distance * 0.16, distance)
		camera.look_at(target)
		heading.text = "ECLIPSE PROTOCOL // %s\nARSENAL REFIT — BLENDER MCP" % asset.to_upper().replace("_", " ")
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screenshots/arsenal/%s.png" % asset)
		model.queue_free()
		await get_tree().process_frame
	get_tree().quit()
