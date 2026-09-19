extends Node

## Automated combat demo driver for Emberfall Seraph (Level 3 Final Boss).
## Simulates high-level combat: weapon switching, core aiming, dodging, dashing.
var level: Node3D
var running := false
var tick := 0
var travel := 1.0

func _ready() -> void:
	process_physics_priority = -100
	run.call_deferred()

func run() -> void:
	level = load("res://src/levels/level_03.tscn").instantiate()
	add_child(level)
	await get_tree().create_timer(0.3).timeout
	
	for x in level.relay_positions:
		level.register_relay("relay_%d" % int(x))
		
	level.player.position = Vector3(level.arena_entry + 7, 0.05, 0)
	for weapon in range(4):
		GameManager.unlock_weapon(weapon)
	GameManager.select_weapon(3) # Start with Rocket Launcher!
	level.player.mouse_active = false
	GameManager.hurt_invuln_timer = 999.0 # Invulnerability for demo stability
	
	level._trigger_boss_fight()
	
	var camera: Camera3D = level.get_node("Camera3D")
	camera.set_physics_process(false)
	camera.position = Vector3(level.arena_entry + 16, 4.8, 17.5)
	camera.fov = 42
	camera.look_at(Vector3(level.arena_entry + 16, 2.8, 0))
	
	DirAccess.make_dir_recursive_absolute("/tmp/seraph-fight-demo")
	running = true
	var ending := 0
	
	for frame in range(120):
		await get_tree().physics_frame
		await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		if frame == 28:
			get_viewport().get_texture().get_image().save_png("/tmp/player_rocket_fire_boss.png")
		if level.completed or GameManager.health <= 0:
			ending += 1
			if ending > 40:
				break
				
	running = false
	for action in ["move_left", "move_right", "shoot", "jump", "dash"]:
		Input.action_release(action)
		
	print("SERAPH FIGHT DEMO COMPLETE: boss defeated=", level.completed)
	get_tree().quit()

func _physics_process(_delta: float) -> void:
	if not running or not is_instance_valid(level) or level.completed:
		return
		
	tick += 1
	var player = level.player
	
	# Patrol and strafe across arena floor
	if player.position.x < level.arena_entry + 6:
		travel = 1.0
	elif player.position.x > level.arena_entry + 24:
		travel = -1.0
		
	Input.action_release("move_left")
	Input.action_release("move_right")
	if tick % 140 < 75:
		Input.action_press("move_right" if travel > 0 else "move_left")
		
	Input.action_release("jump")
	Input.action_release("dash")
	
	# Jump and dash periodically to evade laser pylons and inferno volleys
	if tick % 110 == 15 and player.is_on_floor():
		Input.action_press("jump")
	if tick % 190 == 60:
		Input.action_press("dash")
		
	# Cycle weapons every few seconds
	if tick % 120 == 0:
		var slot := int(tick / 120) % 4
		GameManager.select_weapon(slot)
		
	# Aim and fire at the Seraph boss core
	if is_instance_valid(level.boss) and not level.boss.is_dead:
		player.mouse_active = false
		var target: Vector3 = level.boss.global_position + Vector3(0, 0.2, 0)
		var direction: Vector3 = target - player._muzzle_pos()
		direction.z = 0
		player.aim_direction = direction.normalized()
		player.aim_timer = 0.5
		Input.action_press("shoot")
	else:
		Input.action_release("shoot")
