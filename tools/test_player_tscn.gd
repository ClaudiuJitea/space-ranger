extends Node

func _ready() -> void:
	test.call_deferred()

func test() -> void:
	var root := Node3D.new()
	add_child(root)
	
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.08, 0.12)
	env.environment = e
	root.add_child(env)
	
	var light := DirectionalLight3D.new()
	root.add_child(light)
	light.position = Vector3(5, 5, 5)
	light.look_at(Vector3.ZERO, Vector3.UP)
	
	var p = load("res://src/entities/player/player.tscn").instantiate()
	p.set_physics_process(false)
	p.set_process_unhandled_input(false)
	p.scale = Vector3(1.8, 1.8, 1.8)
	root.add_child(p)
	
	# Point aim direction forward/right
	p.aim_direction = Vector3(1.0, 0.0, 0.0)
	
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, 1.5, 3.5)
	cam.look_at(Vector3(0, 1.3, 0), Vector3.UP)
	cam.current = true
	
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/test_player_tscn.png")
	print("SAVED /tmp/test_player_tscn.png")
	get_tree().quit()
