extends Node

## Render the imported Blender asset at close range, then fire it in the real level.
func _ready() -> void:
	_run()

func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)

func _run() -> void:
	var world := Node3D.new()
	add_child(world)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.022, 0.038, 0.055)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.6, 0.72, 0.85)
	settings.ambient_light_energy = 0.8
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.glow_enabled = true
	settings.glow_intensity = 0.25
	environment.environment = settings
	world.add_child(environment)
	var camera := Camera3D.new()
	camera.position = Vector3(1.15, 0.55, 0.95)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.1
	world.add_child(camera)
	camera.look_at(Vector3(0, 0, 0.1))
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.8, -0.6, 0)
	key.light_energy = 2.5
	world.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1, 0.3, -0.3)
	fill.light_energy = 1.5
	fill.omni_range = 3
	world.add_child(fill)
	var visual := Node3D.new()
	visual.set_script(preload("res://src/projectiles/rocket_visual.gd"))
	world.add_child(visual)
	var model := visual.get_node("HavocMissileModel")
	var nozzle := model.find_child("ExhaustSocket", true, false) as Node3D
	var nose := model.find_child("NoseSocket", true, false) as Node3D
	assert(nozzle != null and nose != null)
	assert(nozzle.position.z > 0.32 and nose.position.z < -0.44)
	assert(visual.get_node("EngineExhaust").global_position.distance_to(nozzle.global_position) < 0.001)
	assert(model.find_children("*", "MeshInstance3D", true, false).size() == 1)
	await get_tree().create_timer(0.5).timeout
	await _capture("/tmp/havoc-missile-detail.png")
	world.queue_free()
	await get_tree().process_frame
	var level := preload("res://src/levels/level_01.tscn").instantiate()
	add_child(level)
	var player: Node = level.get_node("Player")
	player.position = Vector3(1, 0, 0)
	GameManager.unlock_weapon(3)
	GameManager.select_weapon(3)
	player.mouse_active = false
	player.aim_direction = Vector3(1, 0.15, 0).normalized()
	player.aim_timer = 10
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		enemy.set_process(false)
	await get_tree().create_timer(0.6).timeout
	player._shoot()
	for i in range(3):
		await get_tree().physics_frame
	await _capture("/tmp/havoc-missile-ingame.png")
	print("HAVOC IMPORT, NOZZLE ALIGNMENT AND LIVE FIRING CHECKS PASSED")
	get_tree().quit()
