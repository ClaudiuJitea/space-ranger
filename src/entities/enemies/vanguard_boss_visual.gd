extends Node3D

## Skeletal walk cycles and two-handed IK, driven by the physics body.
var boss: CharacterBody3D
var model_root: Node3D
var gun: Node3D
var skeleton: Skeleton3D
var animation: AnimationPlayer
var aim: EnemyRifleAim
var flames: Array[Node3D] = []
var recoil := 0.0
var age := 0.0
var air_pose: SkeletonModifier3D
var pack_mounts: Dictionary = {}
var spine_index := -1
var helmet: Node3D
var head_index := -1
var helmet_mount := Transform3D.IDENTITY

func bind(body: CharacterBody3D, model: Node3D) -> void:
	boss = body
	model_root = model
	model.scale = Vector3.ONE * 2.7
	model.position.y = -2.6
	model.rotation.y = PI / 2
	gun = model.find_child("VanguardGun*", true, false)
	_find_rig(model)
	if animation:
		for clip in ["Idle", "Walk", "Run"]:
			if animation.has_animation(clip):
				animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		animation.play("Idle")
	if skeleton and gun:
		aim = EnemyRifleAim.new()
		skeleton.add_child(aim)
		aim.reach = 0.24
		aim.grip_drop = -0.23
		aim.center_rifle_hold = true
		aim.support_grip = Vector3(0, -0.19, -0.10)
		aim.setup(skeleton, gun)
		air_pose = SkeletonModifier3D.new()
		air_pose.set_script(preload("res://src/entities/enemies/vanguard_air_pose.gd"))
		skeleton.add_child(air_pose)
	if skeleton:
		spine_index = skeleton.find_bone("mixamorig_Spine2")
		if spine_index >= 0:
			var spine_world := skeleton.global_transform * skeleton.get_bone_global_pose(spine_index)
			for pattern in ["VanguardThruster_L*", "VanguardThruster_R*", "ShoulderRocketPod_L*", "ShoulderRocketPod_R*", "ChestBeamAperture*"]:
				var pack := model.find_child(pattern, true, false) as Node3D
				if pack: pack_mounts[pack] = spine_world.affine_inverse() * pack.global_transform
		head_index = skeleton.find_bone("mixamorig_Head")
		helmet = model.find_child("VanguardHelmet*", true, false) as Node3D
		if helmet and head_index >= 0:
			helmet_mount = (skeleton.global_transform * skeleton.get_bone_global_pose(head_index)).affine_inverse() * helmet.global_transform
	for pattern in ["ThrusterSocket_L*", "ThrusterSocket_R*"]:
		var nozzle := model.find_child(pattern, true, false) as Node3D
		if nozzle:
			var flame := preload("res://src/projectiles/muzzle_burst.gd").flare(0.65, 0.09, Color(0.03, 0.65, 1))
			nozzle.add_child(flame)
			flame.rotation.x = -PI / 2
			flames.append(flame)

func _find_rig(node: Node) -> void:
	if node is Skeleton3D: skeleton = node
	if node is AnimationPlayer: animation = node
	for child in node.get_children(): _find_rig(child)

func kick() -> void:
	recoil = minf(0.07, recoil + 0.018)

func _process(delta: float) -> void:
	if not is_instance_valid(boss) or not model_root: return
	age += delta
	recoil = move_toward(recoil, 0, delta * 0.22)
	var airborne: bool = boss.active and not boss.is_on_floor()
	var speed := absf(boss.velocity.x)
	if air_pose: air_pose.fold = move_toward(air_pose.fold, 1.0 if airborne else 0.0, delta * 5.0)
	if animation:
		var clip := "Walk" if speed > 0.15 and not airborne else "Idle"
		if animation.current_animation != clip: animation.play(clip, 0.22)
		animation.speed_scale = clampf(speed / 5.4, 0.15, 1.4) if clip == "Walk" else 1.0
	if is_instance_valid(boss.player_ref):
		var direction: Vector3 = boss.player_ref.global_position + Vector3.UP - boss.global_position
		var facing := -PI / 2 if direction.x > 0 else PI / 2
		# Slight chest opening keeps armour readable while feet travel along X.
		facing += -0.48 if direction.x > 0 else 0.48
		model_root.rotation.y = lerp_angle(model_root.rotation.y, facing, minf(1, delta * 8))
		if animation and animation.current_animation == "Walk":
			animation.speed_scale *= -1.0 if boss.velocity.x * direction.x < 0 else 1.0
		if aim:
			var target: Vector3 = boss.player_ref.global_position + Vector3.UP
			aim.aim_direction = (target - (boss.global_position + Vector3(0, 1.0, 0))).normalized()
			aim.recoil_offset = recoil
	if skeleton and spine_index >= 0:
		var spine_world := skeleton.global_transform * skeleton.get_bone_global_pose(spine_index)
		for pack in pack_mounts: pack.global_transform = spine_world * pack_mounts[pack]
	if helmet and head_index >= 0:
		helmet.global_transform = skeleton.global_transform * skeleton.get_bone_global_pose(head_index) * helmet_mount
	for flame in flames:
		flame.scale = Vector3(1, 1, (1.6 if airborne else 0.35) + sin(age * 29) * 0.04)
