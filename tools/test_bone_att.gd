extends SceneTree

func _init():
	var p = load("res://assets/models/player.glb").instantiate()
	var skel: Skeleton3D = p.find_child("*Skeleton3D*", true, false)
	print("Skel: ", skel)
	var att = BoneAttachment3D.new()
	att.bone_name = "mixamorig_RightHand"
	print("Before add_child: bone_idx=", att.bone_idx)
	skel.add_child(att)
	print("After add_child: bone_idx=", att.bone_idx)
	att.bone_idx = skel.find_bone("mixamorig_RightHand")
	print("Manual set bone_idx=", att.bone_idx)
	
	var blaster = load("res://assets/models/weapon_blaster.glb").instantiate()
	att.add_child(blaster)
	print("Blaster child of att:", blaster.get_parent() == att)
	print("Att global transform:", att.global_transform)
	print("Blaster global transform:", blaster.global_transform)
	quit()
