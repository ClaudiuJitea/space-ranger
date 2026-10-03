extends Node
var failed := false
func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame
func bolts(parent: Node) -> int:
	var count := 0
	for child in parent.get_children():
		if child is Area3D and child.get_script() == preload("res://src/projectiles/projectile.gd"):
			count += 1
	return count
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	GameManager.reset_game()
	var level: Node3D = load("res://src/levels/level_04.tscn").instantiate()
	add_child(level)
	await frames(5)
	for foe in level.enemies.get_children(): foe.set_physics_process(false)
	level.player.set_physics_process(false)
	GameManager.hurt_invuln_timer = 100
	level.player.position = Vector3(344, 0.2, 0)
	var hound: CharacterBody3D = preload("res://src/entities/enemies/armed_hound.tscn").instantiate()
	hound.position = Vector3(336, 0.15, 0)
	level.enemies.add_child(hound)
	hound.set_physics_process(false)
	hound.player_ref = level.player
	hound.rail_timer = 0
	var before := bolts(level.enemies)
	hound._physics_process(0.3)
	check(bolts(level.enemies) == before and hound.rail_charge > 0, "K-9 must charge before firing")
	hound._physics_process(0.4)
	check(bolts(level.enemies) > before, "K-9 must fire from the Blender weapon socket")
	check(hound.legs.size() == 4 and hound.muzzle != null, "K-9 must bind four articulated legs and rail muzzle")
	hound._start_windup(1)
	check(hound.state == hound.State.WINDUP, "Armed hound must retain melee lunge telegraph")
	var wasp: CharacterBody3D = preload("res://src/entities/enemies/interceptor.tscn").instantiate()
	wasp.position = Vector3(336, 4.5, 0)
	level.enemies.add_child(wasp)
	wasp.set_physics_process(false)
	wasp.player_ref = level.player
	wasp.timer = 0
	before = bolts(level.enemies)
	wasp._physics_process(0.3)
	check(bolts(level.enemies) == before and wasp.charge > 0, "Wasp must warn before its burst")
	wasp._physics_process(0.3)
	check(bolts(level.enemies) == before + 2 and wasp.rotors.size() == 2, "Wasp must fire two bolts and bind both fans")
	# Clear line of sight must matter: a deck wall blocks both ranged enemies.
	var wall := StaticBody3D.new()
	wall.position = Vector3(340, 3, 0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 8, 2)
	collision.shape = shape
	wall.add_child(collision)
	level.add_child(wall)
	await frames(2)
	before = bolts(level.enemies)
	wasp.timer = 0
	wasp.charge = 0.5
	wasp._physics_process(0.15)
	check(bolts(level.enemies) == before, "Wasp must not fire through solid scenery")
	hound.rail_timer = 0
	hound.rail_charge = 0.65
	hound.state = hound.State.CHASE
	hound._physics_process(0.1)
	check(bolts(level.enemies) == before, "K-9 must not fire through solid scenery")
	wall.queue_free()
	for foe in [hound, wasp]:
		var score_before: int = GameManager.score
		foe.take_damage(1000)
		check(GameManager.score > score_before, "New enemy defeat must award score")
	await frames(2)
	check(level.player.anim_player.has_animation("Idle") and level.player.anim_player.has_animation("Run"), "Restyled ranger must retain locomotion clips")
	check(level.player.aim_solver.is_ready(), "Restyled ranger must retain weapon aiming IK")
	print("ECLIPSE COMBAT CHECKS: ", "FAILED" if failed else "PASSED")
	level.queue_free()
	await frames(2)
	get_tree().quit(1 if failed else 0)
