extends Node

var _failed := false
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)

func _frames(count := 5) -> void:
	for i in count:
		await get_tree().physics_frame

func _crate(location: Vector3) -> Node3D:
	var crate := preload("res://src/environment/prop_crate.tscn").instantiate()
	crate.max_health = 1000
	crate.position = location
	add_child(crate)
	return crate

func _ready() -> void:
	_run()

func _run() -> void:
	GameManager.reset_game()
	var first := _crate(Vector3(4, 0, 0))
	var second := _crate(Vector3(6, 0, 0))
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.1, 2, 2)
	collision.shape = shape
	wall.add_child(collision)
	wall.position = Vector3(8, 0.5, 0)
	add_child(wall)
	await _frames()
	var beam := preload("res://src/projectiles/beam_projectile.tscn").instantiate()
	beam.position = Vector3(0, 0.45, 0.35)
	add_child(beam)
	beam.init_projectile(Vector3.RIGHT, 6000, 85, Color(0.1, 1, 0.7), false, true)
	_check(beam._visual.global_position.distance_to(Vector3(0, 0.45, 0.35)) < 0.001, "Shot must begin at exact muzzle depth")
	await _frames()
	_check(first.health == 915 and second.health == 915, "Fast rail shot must hit both targets exactly once")
	_check(not is_instance_valid(beam), "Rail shot must stop at solid walls")
	var target := _crate(Vector3(4, 10, 0))
	await _frames()
	var pulse := preload("res://src/projectiles/projectile.tscn").instantiate()
	pulse.position = Vector3(0, 10.45, 0)
	add_child(pulse)
	pulse.init_projectile(Vector3.RIGHT, 6000, 26, Color.CYAN)
	await _frames()
	_check(target.health == 974, "Fast bolt must not tunnel through target")
	_check(not is_instance_valid(pulse), "Pulse must retire after one impact")
	# Vertical aiming and profile swaps must stay finite and keep distinct geometry.
	for profile in ["pulse", "scatter", "rail", "enemy", "emp"]:
		var shot := preload("res://src/projectiles/projectile.tscn").instantiate()
		shot.position = Vector3(-20, 30, 0.3)
		add_child(shot)
		shot.fx_profile = profile
		shot.init_projectile(Vector3.UP, 20, 1, Color.CYAN)
		await _frames(2)
		_check(shot.global_transform.is_finite(), "Vertical shot orientation must be valid")
		_check(shot._visual.profile == profile, "Weapon profile must select matching visuals")
		shot._retire()
	await _frames(15)
	print("PROJECTILE DESIGN CHECKS: ", "FAILED" if _failed else "PASSED")
	get_tree().quit(1 if _failed else 0)
