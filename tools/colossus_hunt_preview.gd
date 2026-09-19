extends Node
func _ready() -> void:
	capture.call_deferred()
func capture() -> void:
	var level: Node3D = load("res://src/levels/level_02.tscn").instantiate()
	add_child(level)
	await get_tree().create_timer(0.2).timeout
	for x in level.relay_positions: level.register_relay("relay_%d" % int(x))
	level.player.set_physics_process(false)
	level.player.visual_root.visible = true
	level.player.position = Vector3(level.arena_entry + 7, 0.05, 0)
	GameManager.hurt_invuln_timer = 99
	level._trigger_boss_fight()
	level.boss.state_timer = 100
	level.hud.hide()
	var camera: Camera3D = level.get_node("Camera3D")
	camera.set_physics_process(false)
	camera.position = Vector3(level.arena_entry + 13, 7, 17)
	camera.fov = 36
	camera.look_at(Vector3(level.arena_entry + 15, 2.2, 0))
	DirAccess.make_dir_recursive_absolute("/tmp/colossus-hunt")
	await get_tree().create_timer(0.8).timeout
	for frame in range(55):
		if frame == 14:
			level.player.position.x = level.arena_entry + 24
		if frame == 32:
			level.player.position.x = level.arena_entry + 9
			level.boss.attack_state = 2
			level.boss._execute_attack()
		await get_tree().create_timer(0.1).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/colossus-hunt/frame_%03d.png" % frame)
	print("HUNT PREVIEW CAPTURED")
	get_tree().quit()
