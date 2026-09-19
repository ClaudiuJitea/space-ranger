extends Node3D

## Fires every weapon slot and screenshots the result so the muzzle origin and
## the bullet direction can be verified against the drawn weapon.

@onready var level: Node3D = $Level

const OUT_DIR := "res://tools/shots"

func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var player: CharacterBody3D = level.get_node("Player")
	var cam: Camera3D = level.get_node("Camera3D")
	cam.set_script(null)
	cam.set_physics_process(false)
	cam.set_process(false)
	cam.fov = 42.0
	GameManager.unlock_weapon(1)
	GameManager.unlock_weapon(2)
	GameManager.unlock_weapon(3)
	for i in range(90):
		await get_tree().physics_frame
	# Freeze enemies so results are deterministic
	get_tree().call_group("enemies", "set_physics_process", false)
	get_tree().call_group("enemies", "hide")

	var names := {0: "pulse", 1: "scatter", 2: "railgun", 3: "launcher"}
	for slot in [0, 1, 2, 3]:
		GameManager.select_weapon(slot)
		player.aim_direction = Vector3.RIGHT
		player.aim_timer = 9999.0
		player.mouse_active = false
		player.aim_solver.aim_weight = 1.0
		for i in range(40):
			await get_tree().physics_frame
		var muzzle: Vector3 = player.active_muzzle.global_position
		player._shoot()
		await get_tree().physics_frame
		var spawned: Array[Vector3] = []
		for c in level.get_children():
			if c is Area3D and c.get("velocity") != null:
				spawned.append(c.global_position)
		print("--- ", names[slot], " ---")
		print("   muzzle=", muzzle.snappedf(0.001), "  aim=", player.aim_direction)
		for s in spawned:
			print("   projectile spawned at ", s.snappedf(0.001), "  offset from muzzle=", (s - muzzle).snappedf(0.001))
		for i in range(4):
			await get_tree().physics_frame
		_capture(cam, player, names[slot])
	get_tree().quit()


func _capture(cam: Camera3D, player: CharacterBody3D, name: String) -> void:
	var base: Vector3 = player.global_position
	var target := base + Vector3(1.2, 1.25, 0.0)
	cam.global_position = base + Vector3(0.4, 1.5, 5.4)
	cam.look_at(target, Vector3.UP)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/fire_%s.png" % [OUT_DIR, name])
	print("   shot saved: fire_%s.png" % name)
