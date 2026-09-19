extends Node3D

@onready var player: CharacterBody3D = $Player

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
	var skel: Skeleton3D = player.skeleton
	print("### bone count: ", skel.get_bone_count())
	print("### skeleton global origin=", skel.global_transform.origin, " scale=", skel.global_transform.basis.get_scale())
	for i in range(skel.get_bone_count()):
		var n := skel.get_bone_name(i)
		var rest := skel.get_bone_rest(i)
		var parent := skel.get_bone_parent(i)
		print("%3d %-30s parent=%3d rest_origin=%s rest_fwd(-Z)=%s" % [i, n, parent, rest.origin, -rest.basis.z])
	print("\n### arm chain child offsets (in parent bone space) ###")
	for pair in [["mixamorig_RightShoulder", "mixamorig_RightArm"], ["mixamorig_RightArm", "mixamorig_RightForeArm"], ["mixamorig_RightForeArm", "mixamorig_RightHand"], ["mixamorig_RightHand", "mixamorig_RightHandMiddle1"], ["mixamorig_LeftShoulder", "mixamorig_LeftArm"], ["mixamorig_LeftArm", "mixamorig_LeftForeArm"], ["mixamorig_LeftForeArm", "mixamorig_LeftHand"], ["mixamorig_LeftHand", "mixamorig_LeftHandMiddle1"], ["mixamorig_Spine2", "mixamorig_RightShoulder"], ["mixamorig_Spine2", "mixamorig_LeftShoulder"]]:
		var a := skel.find_bone(pair[0])
		var b := skel.find_bone(pair[1])
		var off := skel.get_bone_rest(b).origin
		print("  %-28s -> %-28s offset_in_parent=%s len=%.4f" % [pair[0], pair[1], off, off.length()])
	print("\n### rest world positions (relative to player origin) ###")
	for bone in ["mixamorig_Spine2", "mixamorig_RightShoulder", "mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand", "mixamorig_RightHandMiddle1", "mixamorig_LeftShoulder", "mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand", "mixamorig_LeftHandMiddle1", "mixamorig_Head"]:
		var idx := skel.find_bone(bone)
		var w := skel.global_transform * skel.get_bone_global_pose(idx)
		print("  %-28s rel=%s  +Y=%s  -Z=%s" % [bone, w.origin - player.global_position, w.basis.y.normalized(), -w.basis.z.normalized()])
	get_tree().quit()
