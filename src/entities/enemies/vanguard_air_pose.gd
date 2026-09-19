extends SkeletonModifier3D
var fold := 0.0
func _process_modification() -> void:
	var rig := get_skeleton()
	if not rig or fold < 0.001: return
	for side in ["Left", "Right"]:
		for entry in [["UpLeg", -0.30], ["Leg", 0.55], ["Foot", -0.12]]:
			var bone := rig.find_bone("mixamorig_" + side + entry[0])
			if bone >= 0:
				var pose := rig.get_bone_pose(bone)
				pose.basis *= Basis(Vector3.RIGHT, float(entry[1]) * fold)
				rig.set_bone_pose(bone, pose)
