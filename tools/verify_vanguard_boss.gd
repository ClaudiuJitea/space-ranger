extends Node
var failed := false
func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run.call_deferred()
func run() -> void:
	var level: Node3D = load("res://src/levels/level_01.tscn").instantiate()
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	await frames(5)
	for x in level.relay_positions:
		level.register_relay("relay_%d" % int(x))
	level.player.position = Vector3(level.arena_entry + 5, 0.05, 0)
	level.player.set_physics_process(false)
	GameManager.hurt_invuln_timer = 100
	level._trigger_boss_fight()
	var boss: CharacterBody3D = level.boss
	boss.state_timer = 100
	await frames(90)
	check(boss.is_on_floor(), "Vanguard must settle onto arena terrain using physics")
	check(absf(boss.position.y - 2.6) < 0.05, "Vanguard boots and collider must align to arena floor")
	check(boss.get_node("CollisionShape3D").shape is CapsuleShape3D, "Vanguard must use humanoid body collision")
	check(boss._vanguard.skeleton != null and boss._vanguard.aim.is_ready() and boss._vanguard.flames.size() == 2, "Articulated legs and twin thruster sockets must bind")
	var art = boss._vanguard
	check(art.animation.has_animation("Walk") and art.animation.has_animation("Idle"), "Export must preserve skeletal animation clips")
	var leg_index: int = art.skeleton.find_bone("mixamorig_LeftLeg")
	var pose_before: Transform3D = art.skeleton.get_bone_pose(leg_index)
	await frames(30)
	check(not art.skeleton.get_bone_pose(leg_index).is_equal_approx(pose_before), "Walking must animate actual knee bones")
	var previous_x := boss.position.x
	level.player.position.x = boss.home_position.x + 7
	await frames(65)
	check(boss.position.x > previous_x + 0.5 and (-art.model_root.basis.z).dot(Vector3.RIGHT) > 0.7, "Vanguard must approach and turn toward a player to its right")
	check(absf(boss.position.z) < 0.001, "Physics movement must remain on the 2.5D plane")
	check((-art.gun.global_basis.y.normalized()).dot(art.aim.aim_direction) > 0.98, "Held rotary barrels must follow the IK aiming direction")
	level.player.position.x = boss.home_position.x - 7
	await frames(65)
	check((-art.model_root.basis.z).dot(Vector3.LEFT) > 0.7, "Vanguard must turn back toward a player to its left")
	boss._impact_push = 0
	boss.take_damage(100)
	check(boss._impact_push > 0, "Heavy hits must impart physical knockback")
	boss._bolt(boss._muzzles[0].global_position, Vector3.LEFT, 20, 17)
	check(boss._vanguard.recoil > 0, "Gun shots must impart articulated recoil")
	var grounded_y := boss.position.y
	boss.attack_state = 2
	boss._execute_attack()
	check(boss.velocity.y > 10 and boss._stomp_pending, "Thruster stomp must launch via physics velocity")
	await frames(12)
	check(boss.position.y > grounded_y + 0.5, "Thruster impulse must physically lift the boss")
	var paused_position := boss.position
	get_tree().paused = true
	for i in range(10):
		await get_tree().process_frame
	check(boss.position == paused_position, "Boss movement must stop while paused")
	get_tree().paused = false
	await frames(90)
	check(boss.is_on_floor() and not boss._stomp_pending, "Stomp must land on terrain and resolve its shock wave")
	boss.take_damage(10000)
	await frames(2)
	var fragments := get_tree().get_nodes_in_group("boss_debris")
	check(fragments.size() == 8, "Boss defeat must release physical armor debris")
	if not fragments.is_empty():
		var fragment := fragments[0] as RigidBody3D
		var initial_velocity := fragment.linear_velocity
		await frames(12)
		check(fragment.linear_velocity.y < initial_velocity.y, "Armor debris must obey gravity")
	await frames(100)
	check(level.completed, "Physics boss defeat must preserve mission victory")
	print("VANGUARD PHYSICS CHECKS: ", "FAILED" if failed else "PASSED")
	get_tree().quit(1 if failed else 0)
