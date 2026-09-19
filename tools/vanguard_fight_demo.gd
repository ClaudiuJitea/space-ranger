extends Node
## Demo driver uses real player inputs and projectiles; boss AI and damage are unchanged.
var level: Node3D
var running := false
var tick := 0
var travel := 1.0
func _ready() -> void:
	process_physics_priority = -100
	run.call_deferred()
func run() -> void:
	level = load("res://src/levels/level_01.tscn").instantiate()
	add_child(level)
	await get_tree().create_timer(0.3).timeout
	for x in level.relay_positions: level.register_relay("relay_%d" % int(x))
	level.player.position = Vector3(level.arena_entry + 7, 0.05, 0)
	for weapon in range(4): GameManager.unlock_weapon(weapon)
	GameManager.select_weapon(0)
	level.player.mouse_active = false
	level._trigger_boss_fight()
	var camera: Camera3D = level.get_node("Camera3D")
	camera.set_physics_process(false)
	camera.position = Vector3(level.arena_entry + 15, 5.3, 17)
	camera.fov = 39
	camera.look_at(Vector3(level.arena_entry + 15, 2.5, 0))
	DirAccess.make_dir_recursive_absolute("/tmp/vanguard-fight-demo")
	running = true
	var ending := 0
	for frame in range(540):
		await get_tree().physics_frame
		await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/vanguard-fight-demo/frame_%04d.png" % frame)
		if level.completed or GameManager.health <= 0:
			ending += 1
			if ending > 45: break
	running = false
	for action in ["move_left", "move_right", "shoot", "jump", "dash"]: Input.action_release(action)
	print("FIGHT DEMO COMPLETE: player health=", GameManager.health, " boss defeated=", level.completed)
	get_tree().quit()
func _physics_process(_delta: float) -> void:
	if not running or not is_instance_valid(level) or level.completed or GameManager.health <= 0: return
	tick += 1
	var player = level.player
	if player.position.x < level.arena_entry + 6: travel = 1
	elif player.position.x > level.arena_entry + 25: travel = -1
	Input.action_release("move_left")
	Input.action_release("move_right")
	# Cross the arena in short strafes, stopping periodically to fire.
	if tick % 150 < 65:
		Input.action_press("move_right" if travel > 0 else "move_left")
	Input.action_release("jump")
	Input.action_release("dash")
	if tick % 130 == 10 and player.is_on_floor(): Input.action_press("jump")
	if tick % 220 == 80: Input.action_press("dash")
	if tick % 180 == 0: GameManager.select_weapon((tick / 180) as int % 4)
	if is_instance_valid(level.boss) and not level.boss.is_dead:
		player.mouse_active = false
		var target: Vector3 = level.boss.global_position + Vector3(0, 0.45, 0)
		var direction: Vector3 = target - player._muzzle_pos()
		direction.z = 0
		player.aim_direction = direction.normalized()
		player.aim_timer = 0.5
		Input.action_press("shoot")
	else: Input.action_release("shoot")
