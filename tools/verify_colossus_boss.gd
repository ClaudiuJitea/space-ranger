extends Node
var failed := false
func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run.call_deferred()
func run() -> void:
	GameManager.reset_game()
	var level: Node3D = load("res://src/levels/level_02.tscn").instantiate()
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	await frames(5)
	for x in level.relay_positions: level.register_relay("relay_%d" % int(x))
	level.player.position = Vector3(level.arena_entry + 8, 0.05, 0)
	level.player.set_physics_process(false)
	level._trigger_boss_fight()
	var boss: CharacterBody3D = level.boss
	boss.state_timer = 100
	await frames(90)
	check(boss.is_on_floor() and absf(boss.position.y - 2.6) < 0.05, "Colossus must stand on the arena through gravity and terrain collision")
	check(boss._colossus.arms.size() == 2 and boss._colossus.legs.size() == 2, "All Colossus limb pivots must bind")
	# Hunt a moving target on both sides rather than patrol the spawn point.
	level.player.position.x = boss.position.x + 6
	var hunting_x := boss.position.x
	await frames(65)
	check(boss.position.x > hunting_x + 2, "Beast must chase a target to its right")
	check(boss._colossus.facing == 1, "Beast must turn to face a target to its right")
	check(boss._colossus.gait_phase > 1, "Physical pursuit must drive its quadruped gait")
	level.player.position.x = boss.position.x - 6
	hunting_x = boss.position.x
	await frames(65)
	check(boss.position.x < hunting_x - 2, "Beast must reverse pursuit when player moves behind it")
	check(boss._colossus.facing == -1, "Beast must turn back toward its prey")
	var initial_x := boss.position.x
	boss.attack_state = 0
	boss._execute_attack()
	await frames(25)
	check(boss.position.x < initial_x - 1, "Locked-direction charge must move boss through physics")
	boss._charge_time = 0
	await frames(20)
	# Grounded damage and airborne dodge use the actual attack code.
	level.player.position = Vector3(boss.position.x - 3, 0.05, 0)
	GameManager.health = 100
	GameManager.shield = 80
	GameManager.hurt_invuln_timer = 0
	boss._colossus_slam()
	check(GameManager.shield < 80, "Grounded player within slam radius must take damage")
	level.player.position.y = 2.0
	GameManager.shield = 80
	GameManager.hurt_invuln_timer = 0
	boss._colossus_slam()
	check(GameManager.shield == 80, "Jumping player must evade direct ground slam")
	level.player.position.x = level.arena_entry + 8
	var grounded_y := boss.position.y
	boss.attack_state = 2
	boss._execute_attack()
	await frames(12)
	check(boss.position.y > grounded_y + 0.5 and boss._leap_pending, "Leap must be a physical velocity impulse")
	var paused_position := boss.position
	get_tree().paused = true
	for i in range(10): await get_tree().process_frame
	check(boss.position == paused_position, "Colossus must stop during pause")
	get_tree().paused = false
	await frames(90)
	check(boss.is_on_floor() and not boss._leap_pending, "Leap must resolve slam only after terrain landing")
	boss._impact_push = 0
	boss.take_damage(100)
	check(boss._impact_push != 0, "Heavy shots must impart mass-reduced knockback")
	boss.take_damage(10000)
	await frames(2)
	check(get_tree().get_nodes_in_group("boss_debris").size() == 8, "Fractured armor must fall as rigid-body debris")
	await frames(100)
	check(level.completed and level.hud.next_level_path.ends_with("level_03.tscn"), "Colossus defeat must advance to final mission")
	print("COLOSSUS PHYSICS CHECKS: ", "FAILED" if failed else "PASSED")
	get_tree().quit(1 if failed else 0)
