extends Node

## Exercises actual physics overlap, projectile contact and keyboard interaction.
var _failed := false

func _ready() -> void:
	_run()

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)

func _frames(count := 5) -> void:
	for i in count:
		await get_tree().physics_frame

func _spawn(path: String, location: Vector3) -> Node3D:
	var object: Node3D = load(path).instantiate()
	object.position = location
	add_child(object)
	return object

func _shoot(location: Vector3) -> void:
	var projectile := _spawn("res://src/projectiles/projectile.tscn", location)
	projectile.init_projectile(Vector3.RIGHT, 32, 25, Color.CYAN)
	await _frames(8)

func _run() -> void:
	GameManager.reset_game()
	var player := CharacterBody3D.new()
	player.collision_layer = 2
	player.collision_mask = 1
	player.add_to_group("player")
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.85
	collision.shape = shape
	collision.position.y = 0.92
	player.add_child(collision)
	player.position = Vector3(-2, 0, 0)
	add_child(player)

	var barrel := _spawn("res://src/environment/explosive_barrel.tscn", Vector3.ZERO)
	var chain := _spawn("res://src/environment/explosive_barrel.tscn", Vector3(2.5, 0, 0))
	await _frames()
	var hit := player.move_and_collide(Vector3(4, 0, 0))
	_check(hit != null and hit.get_collider() == barrel, "Player must collide with barrels")
	_check(not barrel.is_in_group("enemies"), "Props must not inflate hostile counts")
	player.position = Vector3(-2, 0, 0)
	await _shoot(Vector3(-1.5, 0.55, 0))
	await _frames()
	_check(not is_instance_valid(barrel), "Projectile must destroy barrel")
	_check(not is_instance_valid(chain), "Barrel blast must trigger nearby barrels")
	_check(GameManager.shield < GameManager.max_shield, "Barrel blast must damage nearby player")

	player.position = Vector3(-20, 0, 0)
	var crate := _spawn("res://src/environment/prop_crate.tscn", Vector3(10, 0, 0))
	await _frames()
	await _shoot(Vector3(8.5, 0.45, 0))
	_check(is_instance_valid(crate) and crate.health == 5, "Crate must absorb first shot")
	await _shoot(Vector3(8.5, 0.45, 0))
	_check(not is_instance_valid(crate), "Crate must break after sufficient damage")
	var supplies: Node3D = null
	for child in get_children():
		if child is Area3D and child.get_script() == preload("res://src/entities/pickups/pickup.gd"):
			supplies = child
	_check(supplies != null, "Broken crate must release a pickup")
	if supplies:
		supplies.queue_free()

	var rocket_crate := _spawn("res://src/environment/prop_crate.tscn", Vector3(20, 0, 0))
	await _frames()
	var rocket := _spawn("res://src/projectiles/rocket_projectile.tscn", Vector3(20, 0.5, 0))
	await _frames()
	_check(not is_instance_valid(rocket_crate), "Rocket blast must damage props")

	GameManager.health = 50
	GameManager.shield = 0
	var terminal := _spawn("res://src/environment/prop_terminal.tscn", Vector3(30, 0, 0))
	player.position = Vector3(28.5, 0, 0)
	await _frames()
	_check(terminal._prompt.visible, "Terminal must show nearby interaction prompt")
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	Input.parse_input_event(event)
	await _frames()
	_check(terminal.activated, "F interaction action must activate terminal")
	_check(GameManager.health == 75 and GameManager.shield == 40, "Terminal must restore hull and shield")
	var score := GameManager.score
	terminal.activate()
	_check(GameManager.score == score, "Terminal rewards must only apply once")
	_check(InputMap.action_get_events("interact")[0].keycode == KEY_F, "Interaction must bind to F")

	for type in range(3):
		player.position = Vector3(40 + type * 4, 0, 0)
		GameManager.health = 50
		GameManager.shield = 0
		var pickup: Area3D = load("res://src/entities/pickups/pickup.tscn").instantiate()
		pickup.pickup_type = type
		pickup.position = player.position + Vector3.UP * 1.2
		add_child(pickup)
		await _frames(10)
		_check(not is_instance_valid(pickup), "Pickup type %d must collect on contact" % type)
		if type == 0: _check(GameManager.health == 65, "Energy pickup must heal player")
		if type == 1: _check(GameManager.shield == 40, "Shield pickup must recharge shield")
		if type == 2: _check(GameManager.unlocked_weapons[1], "Weapon pickup must unlock weapon")

	print("OBJECT INTERACTION CHECKS: ", "FAILED" if _failed else "PASSED")
	get_tree().quit(1 if _failed else 0)
