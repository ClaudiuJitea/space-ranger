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
	light.position = Vector3(5, 5, 5)
	light.look_at(Vector3.ZERO, Vector3.UP)
	root.add_child(light)
	
	var p: Node3D = load("res://assets/models/player.glb").instantiate()
	p.scale = Vector3(1.8, 1.8, 1.8)
	root.add_child(p)
	
	var anim_player: AnimationPlayer = p.find_child("*AnimationPlayer*", true, false)
	if anim_player and anim_player.has_animation("Idle"):
		anim_player.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
		anim_player.play("Idle")
		
	var skel: Skeleton3D = p.find_child("*Skeleton3D*", true, false)
	var hand_idx := skel.find_bone("mixamorig_RightHand")
	print("Hand bone idx:", hand_idx)
	
	var att := BoneAttachment3D.new()
	att.bone_name = "mixamorig_RightHand"
	att.bone_idx = hand_idx
	skel.add_child(att)
	
	var blaster: Node3D = load("res://assets/models/weapon_blaster.glb").instantiate()
	blaster.position = Vector3(0.0, 0.05, 0.0)
	blaster.scale = Vector3(1.2, 1.2, 1.2)
	att.add_child(blaster)
	
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.5, 3.0)
	cam.look_at(Vector3(0, 1.3, 0), Vector3.UP)
	cam.current = true
	root.add_child(cam)
	
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/test_ranger_weapon.png")
	print("SAVED /tmp/test_ranger_weapon.png")
	print("Blaster global_pos:", blaster.global_position)
	get_tree().quit()
