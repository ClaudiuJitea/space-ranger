extends Node3D

## Render the actual imported assets with neutral studio lighting for art review.
var camera: Camera3D
var label: Label
func _ready() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.018, 0.028, 0.047)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.6, 0.75, 0.9)
	settings.ambient_light_energy = 0.6
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.glow_enabled = true
	settings.glow_intensity = 0.25
	environment.environment = settings
	add_child(environment)
	for data in [[Vector3(-35, -30, 0), Color(0.85, 0.94, 1), 1.8], [Vector3(-20, 150, 0), Color(0.18, 0.65, 1), 1.3]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = data[0]
		light.light_color = data[1]
		light.light_energy = data[2]
		add_child(light)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 36
	add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(40, 35)
	label.add_theme_font_override("font", preload("res://assets/fonts/ShareTechMono-Regular.ttf"))
	label.add_theme_font_size_override("font_size", 24)
	label.modulate = Color(0.2, 0.85, 1)
	layer.add_child(label)
	run.call_deferred()

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots/eclipse")
	for asset in ["ranger", "hound", "wasp", "apex", "warden", "seraph", "leviathan", "sovereign"]:
		var model: Node3D = load("res://assets/models/eclipse_expansion/%s.glb" % asset).instantiate()
		add_child(model)
		var animation := model.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
		if animation:
			print(asset, " CLIPS ", animation.get_animation_list())
			if animation.has_animation("Idle"): animation.play("Idle")
		var target := Vector3(0, 1, 0) if asset == "ranger" else (Vector3(0, 0.7, 0) if asset == "hound" else (Vector3(0, 1.3, 0) if asset == "apex" else Vector3.ZERO))
		var distance := 4.3 if asset == "ranger" else (4.7 if asset in ["hound", "wasp"] else (7.0 if asset == "apex" else 12.0))
		camera.position = target + Vector3(distance * 0.38, distance * 0.2, distance)
		camera.look_at(target)
		if asset in ["ranger", "apex", "warden", "seraph"]:
			model.rotation.y = PI * (1.2 if asset in ["ranger", "apex"] else 0.2)
		label.text = "ECLIPSE PROTOCOL // %s\nBLENDER MCP ASSET ATELIER" % asset.to_upper()
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screenshots/eclipse/%s.png" % asset)
		model.queue_free()
		await get_tree().process_frame
	get_tree().quit()
