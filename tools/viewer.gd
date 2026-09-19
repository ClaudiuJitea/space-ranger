extends Node3D

## Renders the operative + each weapon from a couple of angles for several aim
## directions, straight out of the running game, so the weapon rig can be
## eyeballed. Run with:
##   godot --path . res://tools/viewer.tscn

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
	cam.fov = 40.0

	# let the player settle on the floor and the animations kick in
	for i in range(90):
		await get_tree().physics_frame

	# Keep the harness deterministic: freeze enemies so the player is never
	# shot mid-capture (a dead player hides the rig and nukes the aim solver).
	get_tree().call_group("enemies", "set_physics_process", false)
	get_tree().call_group("enemies", "hide")

	var shots := {
		"right": Vector3.RIGHT,
		"up45": Vector3(1.0, 1.0, 0.0).normalized(),
		"down30": Vector3(1.0, -0.6, 0.0).normalized(),
	}
	for w_idx in range(4):
		GameManager.health = GameManager.max_health
		GameManager.hurt_invuln_timer = 0.0
		player.visible = true
		player.visual_root.visible = true
		player._equip_weapon_model(w_idx, true)
		for key in shots:
			player.aim_direction = shots[key]
			player.aim_timer = 9999.0
			player.mouse_active = false  # keep the scripted aim (no mouse in this harness)
			player.aim_solver.aim_weight = 1.0
			for i in range(40):
				await get_tree().physics_frame
			await _shoot_cam(cam, player, "w%d_%s_full" % [w_idx, key], 3.04, 0.98, 0.0)
			await _shoot_cam(cam, player, "w%d_%s_close" % [w_idx, key], 2.1, 1.32, 0.55)
			await _shoot_grip(cam, player, "w%d_%s_grip" % [w_idx, key])
	get_tree().quit()


## Tight shot on the weapon grip so the hand/grip contact can be checked.
func _shoot_grip(cam: Camera3D, player: CharacterBody3D, name: String) -> void:
	var grip: Vector3 = player.aim_solver.weapon.global_transform * Vector3(0.0, 0.05, 0.0)
	cam.fov = 28.0
	cam.global_position = grip + Vector3(0.34, 0.36, 0.95)
	cam.look_at(grip, Vector3.UP)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, name])
	print("shot ", name, " grip_rel=", (grip - player.global_position).snappedf(0.01))


func _shoot_cam(cam: Camera3D, player: CharacterBody3D, name: String, dist: float, height: float, side: float) -> void:
	var base: Vector3 = player.global_position
	var target := base + Vector3(0.0, height, 0.0)
	cam.global_position = target + Vector3(side, 0.12, dist)
	cam.look_at(target, Vector3.UP)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, name])
	print("shot ", name, " muzzle_rel=", (player.active_muzzle.global_position - base).snappedf(0.01),
		" aim=", player.aim_direction.snappedf(0.01))
