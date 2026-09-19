extends SceneTree

func _init() -> void:
	var scene := load("res://assets/models/player.glb") as PackedScene
	var inst := scene.instantiate()
	var skel: Skeleton3D = null
	var stack := [inst]
	while stack.size() > 0:
		var c = stack.pop_back()
		if c is Skeleton3D:
			skel = c
			break
		for child in c.get_children():
			stack.push_back(child)
	if skel:
		print("Skeleton found! Bone count: ", skel.get_bone_count())
		for i in skel.get_bone_count():
			var bname := skel.get_bone_name(i)
			if "left" in bname.to_lower() or "hand" in bname.to_lower():
				print("  Bone ", i, ": ", bname)
	else:
		print("No skeleton found!")
	inst.queue_free()
	quit(0)
