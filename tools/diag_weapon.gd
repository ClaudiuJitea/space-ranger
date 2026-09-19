extends Node3D

@onready var player: CharacterBody3D = $Player

var _fail := 0

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
	player.mouse_active = true
	player.aim_timer = 9999.0

	var dirs := {
		"right": Vector3.RIGHT,
		"up_right": Vector3(1, 1, 0).normalized(),
		"down_right": Vector3(1, -1, 0).normalized(),
		"left": Vector3.LEFT,
		"straight_up": Vector3.UP,
		"up_left": Vector3(-1, 1, 0).normalized(),
	}
	for k in dirs:
		player.aim_direction = dirs[k]
		player.aim_timer = 9999.0
		player.aim_solver.aim_weight = 1.0
		for i in range(40):
			await get_tree().physics_frame
		await get_tree().process_frame
		_report(k, dirs[k])
	print("\n=== FAILURES: ", _fail, " ===")
	get_tree().quit()

func _report(label: String, aim: Vector3) -> void:
	var origin: Vector3 = player.global_position
	var gun: Node3D = player.aim_solver.weapon
	var muzzle: Node3D = player.active_muzzle
	var skel: Skeleton3D = player.skeleton
	var shoulder: Vector3 = (skel.global_transform * skel.get_bone_global_pose(skel.find_bone("mixamorig_RightArm"))).origin
	var hand: Vector3 = (skel.global_transform * skel.get_bone_global_pose(skel.find_bone("mixamorig_RightHand"))).origin
	var gun_fwd: Vector3 = -gun.global_transform.basis.y.normalized()
	var gun_up: Vector3 = -gun.global_transform.basis.z.normalized()
	var gun_pos: Vector3 = gun.global_transform.origin
	var mz: Vector3 = muzzle.global_position

	# Where the barrel tip should be: the model's own Muzzle node.
	var tip: Vector3 = muzzle.global_position

	print("\n---- aim=", label, " ", aim, " ----")
	print("  shoulder       rel=", shoulder - origin)
	print("  hand(wrist)    rel=", (hand - origin).snappedf(0.001), "  dist_from_shoulder=", "%.3f" % (hand - shoulder).length())
	print("  gun origin     rel=", (gun_pos - origin).snappedf(0.001))
	print("  muzzle marker  rel=", (mz - origin).snappedf(0.001))
	print("  barrel dir     =", gun_fwd.snappedf(0.001), " dot(aim)=", "%.4f" % gun_fwd.dot(aim))
	print("  gun up         =", gun_up.snappedf(0.001), " dot(world_up)=", "%.4f" % gun_up.dot(Vector3.UP))
	print("  muzzle ahead of shoulder= ", "%.3f" % (mz - shoulder).dot(aim), " m | above shoulder=", "%.3f" % (mz - shoulder).dot(Vector3.UP))
	print("  muzzle == barrel tip? ", "YES" if (mz - tip).length() < 0.001 else "NO  delta=%.4f" % (mz - tip).length())
	print("  gun origin to hand=", "%.4f" % (gun_pos - hand).length())

	if gun_fwd.dot(aim) < 0.999:
		_fail += 1
		print("  !! barrel is not aligned with the aim direction")
	if (mz - tip).length() > 0.001:
		_fail += 1
		print("  !! muzzle marker is not on the barrel tip")
	if (mz - shoulder).dot(aim) < 0.5:
		_fail += 1
		print("  !! muzzle is not out in front of the shoulder")
	if (hand - shoulder).length() > 0.48:
		_fail += 1
		print("  !! arm over-extended (IK clamped)")
