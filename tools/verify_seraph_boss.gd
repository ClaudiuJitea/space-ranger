extends Node

var failed := false

func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run.call_deferred()

func run() -> void:
	GameManager.reset_game()
	var level: Node3D = load("res://src/levels/level_03.tscn").instantiate()
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	await frames(5)
	
	for x in level.relay_positions:
		level.register_relay("relay_%d" % int(x))
		
	level.player.position = Vector3(level.arena_entry + 8, 0.05, 0)
	level.player.set_physics_process(false)
	level._trigger_boss_fight()
	
	var boss: CharacterBody3D = level.boss
	boss.state_timer = 100
	await frames(45)
	
	check(boss._seraph != null, "Seraph visual animator must bind successfully")
	check(boss._seraph.wing_upper_l != null and boss._seraph.wing_upper_r != null, "Upper razor wings must bind")
	check(boss._seraph.wing_lower_l != null and boss._seraph.wing_lower_r != null, "Lower stabilizer wings must bind")
	check(boss._seraph.thruster_l != null and boss._seraph.thruster_r != null, "Dual inferno jet turbines must bind")
	check(boss._seraph.flames.size() == 2, "Both jet exhaust flames must be attached to turbine nozzles")
	check(boss._muzzles.size() >= 2, "Both heavy siege cannon muzzles must bind")
	
	# Test attack patterns
	boss.attack_state = 0 # Inferno volley
	boss._execute_attack()
	await frames(15)
	
	boss.attack_state = 1 # Wing sweep
	boss._execute_attack()
	await frames(15)
	
	boss.attack_state = 2 # Solar strikes
	var solar_targets: Array[float] = [float(level.arena_entry + 10), float(level.arena_entry + 15)]
	boss._targets = solar_targets
	boss._execute_attack()
	await frames(15)
	
	# Test phase transition
	boss.take_damage(boss.max_health * 0.4)
	check(boss.phase >= 2, "Seraph must transition to phase 2 when taking significant damage")
	
	# Test defeat and debris
	boss.take_damage(boss.health)
	await frames(10)
	check(boss.is_dead, "Seraph must enter reactor collapse death state")
	var debris_count := get_tree().get_nodes_in_group("boss_debris").size()
	check(debris_count >= 8, "Seraph defeat must spawn physical armor and ember debris chunks")
	
	if not failed:
		print("EMBERFALL SERAPH SYSTEM & GRAPHICS CHECKS: PASSED")
	else:
		print("EMBERFALL SERAPH CHECKS FAILED")
	get_tree().quit(1 if failed else 0)
