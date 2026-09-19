extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var crawler := load("res://src/entities/enemies/crawler.tscn").instantiate() as CharacterBody3D
	root.add_child(crawler)
	crawler.set_physics_process(false)
	var visual := crawler.get_node("ModelAnimation")
	visual.set_process(false)
	var gait: RefCounted = visual.locomotion
	assert(gait.limbs.size() == 4)
	for velocity_x in [0.8, -0.8, 2.2, -2.2, 4.6, -4.6]:
		var direction := signf(velocity_x)
		crawler.facing = direction
		crawler.get_node("Visual").scale.x = direction
		crawler.state = 1
		crawler.velocity.x = velocity_x
		for frame in 240:
			crawler.position.x += crawler.velocity.x / 120.0
			gait.update(1.0 / 120.0)
			for limb in gait.limbs:
				var paw: Node3D = limb.paw
				assert(paw.global_position.is_finite(), "IK must remain finite")
				if limb.planted:
					assert(paw.global_position.distance_to(limb.anchor) < 0.035, "Stance paw must stay planted while the body moves")
					assert(absf(paw.global_position.y - 0.065) < 0.025, "Paw must stay at floor height")
	crawler.velocity = Vector3.ZERO
	crawler.state = 2
	for frame in 54:
		crawler.state_timer = 0.45 - frame / 120.0
		gait.update(1.0 / 120.0)
	assert(visual.model.position.y < -0.20, "Attack must load the hind legs")
	assert(visual.model.scale.is_equal_approx(Vector3.ONE), "Armor must keep its proportions")
	crawler.state = 3
	crawler.state_timer = 0.16
	gait.update(1.0 / 120.0)
	for limb in gait.limbs:
		assert(not limb.planted, "Pounce must release the paws")
	crawler.free()
	print("CRAWLER VERIFIED: articulated joints, floor contact, world-space stance in both directions, crouch and airborne pounce")
	quit()
