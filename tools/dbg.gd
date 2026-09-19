extends Node3D

@onready var player: CharacterBody3D = $Player

func _ready() -> void:
	await get_tree().process_frame
	player.mouse_active = true
	player.aim_timer = 9999.0
	player.aim_direction = Vector3.RIGHT
	for i in range(15):
		await get_tree().physics_frame
	print("0) default (idle callback): ", await _sample())
	player.anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	for i in range(15):
		await get_tree().physics_frame
	print("1) anim callback=PHYSICS   : ", await _sample())
	player.anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for i in range(15):
		await get_tree().physics_frame
	print("2) anim callback=MANUAL    : ", await _sample())
	get_tree().quit()

func _sample() -> String:
	await get_tree().physics_frame
	var skel: Skeleton3D = player.skeleton
	var ai := skel.find_bone("mixamorig_RightArm")
	var hi := skel.find_bone("mixamorig_RightHand")
	var shoulder: Vector3 = (skel.global_transform * skel.get_bone_global_pose(ai)).origin
	var hw: Transform3D = skel.global_transform * skel.get_bone_global_pose(hi)
	return "hand +Y=%s  wrist-shoulder=%s" % [
		str(hw.basis.y.normalized().snappedf(0.01)), str((hw.origin - shoulder).snappedf(0.01))]
