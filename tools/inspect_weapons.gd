extends SceneTree

func _init() -> void:
	var paths := [
		"res://assets/models/weapon_blaster.glb",
		"res://assets/models/weapon_scattergun.glb",
		"res://assets/models/weapon_railgun.glb",
		"res://assets/models/weapon_launcher.glb"
	]
	for p in paths:
		print("=== WEAPON: ", p, " ===")
		var scene := load(p) as PackedScene
		if not scene:
			print("Could not load ", p)
			continue
		var inst := scene.instantiate()
		_print_hierarchy(inst, 0)
		inst.queue_free()
	quit(0)

func _print_hierarchy(node: Node, depth: int) -> void:
	var indent := "  ".repeat(depth)
	var extra := ""
	if node is Node3D:
		extra += " pos=" + str(node.position)
	if node is MeshInstance3D and node.mesh:
		var aabb: AABB = (node.mesh as Mesh).get_aabb()
		extra += " aabb_pos=" + str(aabb.position) + " aabb_size=" + str(aabb.size)
	print(indent, node.name, " (", node.get_class(), ")", extra)
	for c in node.get_children():
		_print_hierarchy(c, depth + 1)
