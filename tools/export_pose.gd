extends Node3D

## Exports the posed character and weapon as OBJ files so the exact pose the
## renderer receives can be inspected in Blender.
##
## The engine restores the unmodified animation poses right after the skeleton
## update, so `get_bone_global_pose()` cannot be used from outside a modifier.
## The solver therefore captures the poses it produced and we skin the mesh
## ourselves with those exact matrices.

@onready var player: CharacterBody3D = $Player

const OUT_DIR := "res://tools/shots"

func _ready() -> void:
	await get_tree().process_frame
	player.mouse_active = true
	player.aim_timer = 9999.0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var shots := {
		"aim_right": Vector3.RIGHT,
		"aim_up45": Vector3(1.0, 1.0, 0.0).normalized(),
		"aim_down30": Vector3(1.0, -0.6, 0.0).normalized(),
		"aim_left": Vector3.LEFT,
	}
	for key in shots:
		player.aim_direction = shots[key]
		player.aim_timer = 9999.0
		player.aim_solver.aim_weight = 1.0
		for i in range(30):
			await get_tree().physics_frame
		player.aim_solver.capture_pose = true
		await get_tree().process_frame
		await get_tree().process_frame
		player.aim_solver.capture_pose = false
		_export(key, shots[key])
		print("exported ", key, "  muzzle=", player.muzzle.global_position - player.global_position)
	get_tree().quit()


func _export(key: String, aim: Vector3) -> void:
	var poses: Array[Transform3D] = player.aim_solver.pose_capture
	var skel: Skeleton3D = player.skeleton
	var skel_world: Transform3D = skel.global_transform
	var dir := ProjectSettings.globalize_path(OUT_DIR)

	# --- character (hand-skinned with the captured poses) ---
	var obj := PackedStringArray()
	var faces := 0
	for child in skel.get_children():
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null or mi.skin == null:
			continue
		faces += _append_skinned(obj, mi, poses, skel_world)
	_write(dir + "/char_%s.obj" % key, obj, faces)

	# --- weapon ---
	var gun_obj := PackedStringArray()
	var gun_faces := 0
	var stack: Array[Node] = [player.weapon_root]
	var gun_world: Transform3D = player.blaster_instance.global_transform
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		var mi := n as MeshInstance3D
		if mi != null and mi.mesh != null:
			gun_faces += _append_rigid(gun_obj, mi, mi.global_transform)
		for c in n.get_children():
			stack.push_back(c)
	_write(dir + "/gun_%s.obj" % key, gun_obj, gun_faces)

	# --- markers / camera hints ---
	var mz: Vector3 = player.muzzle.global_position
	var shoulder: Vector3 = skel_world * poses[skel.find_bone("mixamorig_RightArm")].origin
	var info := {
		"key": key,
		"aim": [aim.x, aim.y, aim.z],
		"origin": [player.global_position.x, player.global_position.y, player.global_position.z],
		"shoulder": [shoulder.x, shoulder.y, shoulder.z],
		"muzzle": [mz.x, mz.y, mz.z],
		"barrel_dir": [
			(-gun_world.basis.y).normalized().x,
			(-gun_world.basis.y).normalized().y,
			(-gun_world.basis.y).normalized().z,
		],
	}
	var f := FileAccess.open(dir + "/pose_%s.json" % key, FileAccess.WRITE)
	f.store_string(JSON.stringify(info, "  "))
	f.close()


func _append_skinned(out: PackedStringArray, mi: MeshInstance3D, poses: Array[Transform3D], skel_world: Transform3D) -> int:
	var skin: Skin = mi.skin
	var mats: Array[Transform3D] = []
	for b in range(skin.get_bind_count()):
		var bone_idx: int = skin.get_bind_bone(b)
		if bone_idx < 0 or bone_idx >= poses.size():
			mats.append(Transform3D())
		else:
			mats.append(poses[bone_idx] * skin.get_bind_pose(b))
	var face_total := 0
	for s in range(mi.mesh.get_surface_count()):
		var arrays := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var base := out.size()
		var skinned := PackedVector3Array()
		skinned.resize(verts.size())
		for vi in range(verts.size()):
			var v: Vector3 = verts[vi]
			var acc := Vector3.ZERO
			if bones.size() >= (vi + 1) * 4:
				for k in range(4):
					var w: float = weights[vi * 4 + k]
					if w <= 0.0:
						continue
					var bi: int = bones[vi * 4 + k]
					if bi >= 0 and bi < mats.size():
						acc += (mats[bi] * v) * w
			else:
				acc = v
			skinned[vi] = (skel_world * acc).snappedf(0.00001)
		# vertices (deduplicated by exact value to keep the file small)
		var index_map := {}
		var unique := PackedStringArray()
		var remap := PackedInt32Array()
		remap.resize(verts.size())
		for vi in range(verts.size()):
			var keyv := str(skinned[vi])
			if not index_map.has(keyv):
				index_map[keyv] = unique.size()
				unique.append("v %f %f %f" % [skinned[vi].x, skinned[vi].y, skinned[vi].z])
			remap[vi] = index_map[keyv]
		out.append_array(unique)
		var tri := 0
		if indices.size() > 0:
			while tri + 2 < indices.size():
				out.append("f %d %d %d" % [remap[indices[tri]] + 1, remap[indices[tri + 1]] + 1, remap[indices[tri + 2]] + 1])
				tri += 3
		else:
			while tri + 2 < verts.size():
				out.append("f %d %d %d" % [remap[tri] + 1, remap[tri + 1] + 1, remap[tri + 2] + 1])
				tri += 3
		face_total += tri / 3
		_ = base
	return face_total


func _append_rigid(out: PackedStringArray, mi: MeshInstance3D, xform: Transform3D) -> int:
	var face_total := 0
	for s in range(mi.mesh.get_surface_count()):
		var arrays := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for v in verts:
			var w: Vector3 = xform * v
			out.append("v %f %f %f" % [w.x, w.y, w.z])
		var tri := 0
		if indices.size() > 0:
			while tri + 2 < indices.size():
				out.append("f %d %d %d" % [indices[tri] + 1, indices[tri + 1] + 1, indices[tri + 2] + 1])
				tri += 3
		else:
			while tri + 2 < verts.size():
				out.append("f %d %d %d" % [tri + 1, tri + 2, tri + 3])
				tri += 3
		face_total += tri / 3
	return face_total


func _write(path: String, lines: PackedStringArray, faces: int) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	print("  wrote ", path, "  faces=", faces)
