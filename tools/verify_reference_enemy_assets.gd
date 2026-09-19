extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	for kind in ["crawler", "turret", "gunship", "boss"]:
		var packed := load("res://src/entities/enemies/%s.tscn" % kind) as PackedScene
		assert(packed != null, "Enemy scene must import")
		var enemy := packed.instantiate() as CharacterBody3D
		stage.add_child(enemy)
		enemy.set_physics_process(false)
		var visual := enemy.get_node("ModelAnimation")
		assert(visual.get("model") != null, "Visual model must bind")
		if kind == "crawler":
			assert(visual.get("legs").size() == 4, "Crawler needs four articulated legs")
			enemy.velocity.x = 4.6
			visual._process(0.1)
			assert(absf(visual.get("legs")[0].rotation.z) > 0.01, "Crawler gait must animate")
			enemy.set("state", 2)
			visual._process(0.05)
			assert(visual.get("model").position.y < -0.04, "Lunge warning must crouch with articulated legs")
		elif kind == "turret":
			var base := enemy.get_node("Model").find_child("AnchoredBase*", true, false) as Node3D
			assert(base != null and visual.get("head") != null, "Turret must have separate base and head")
			var original := base.global_transform
			enemy.get_node("SwivelHead").rotation.z = 0.7
			assert(base.global_transform.is_equal_approx(original), "Aiming must leave the base anchored")
			assert(visual.get("head").get_parent() == enemy.get_node("SwivelHead"), "Head must follow aiming")
		else:
			var marker: Marker3D = enemy.get_node("Visual/MuzzleLeft" if kind == "gunship" else "Visual/CannonLeft")
			assert(marker.position.x > 0.6, "Muzzles must face +X")
		print("REFERENCE ASSET VERIFIED: ", kind)
		enemy.free()
	stage.free()
	for path in ["res://src/levels/level_01.tscn", "res://src/levels/level_02.tscn"]:
		var level := load(path) as PackedScene
		assert(level != null, "Both levels must load with the new enemies")
		print("LEVEL VERIFIED: ", path)
	quit()
