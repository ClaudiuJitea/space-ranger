extends Node

## Temporary visual QA: drives the real level, cycles through each weapon
## while firing, and saves a screenshot of every state for inspection.

func _ready() -> void:
	# _run() stages each scene (menu, then level) itself.
	_run()

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)

func _run() -> void:
	# --- Main menu --------------------------------------------------------
	var menu: Node = load("res://src/ui/main_menu.tscn").instantiate()
	add_child(menu)
	await _wait(1.0)
	await _shot("/tmp/qa_menu.png")
	menu.queue_free()
	await _wait(0.2)

	var level: Node = load("res://src/levels/level_01.tscn").instantiate()
	add_child(level)
	await _wait(0.7)
	await _shot("/tmp/qa_idle.png")

	var players := get_tree().get_nodes_in_group("player")
	var player: Node = players[0]

	for w in range(4):
		GameManager.unlock_weapon(w)
		GameManager.select_weapon(w)
		await _wait(0.5) # let the equip flourish finish
		player.aim_direction = Vector3(1.0, 0.15, 0.0).normalized()
		player.aim_timer = 2.0
		Input.action_press("shoot")
		await _wait(0.12) # catch the muzzle flash frame
		await _shot("/tmp/qa_weapon%d.png" % w)
		await _wait(0.5)
		Input.action_release("shoot")

	# Rocket in flight
	GameManager.select_weapon(3)
	await _wait(0.4)
	player.aim_direction = Vector3(1.0, 0.05, 0.0).normalized()
	Input.action_press("shoot")
	await _wait(0.08)
	Input.action_release("shoot")
	await _wait(0.35)
	await _shot("/tmp/qa_rocket_flight.png")

	# Weapon pickup: drop the player right next to it so it collects on camera
	# (toast + shockwave + in-world weapon model).
	player.global_position = Vector3(21.4, 5.6, 0.0)
	player.aim_direction = Vector3(1.0, 0.0, 0.0)
	await _wait(0.35)
	await _shot("/tmp/qa_pickup.png")

	# Crawler melee enemy on its platform, aggroed and closing in
	player.global_position = Vector3(30.2, 1.4, 0.0)
	player.aim_direction = Vector3(1.0, -0.1, 0.0)
	await _wait(1.1)
	await _shot("/tmp/qa_crawler.png")

	# Boss fight arena
	for x in level.relay_positions:
		level.register_relay("relay_%d" % int(x))
	player.global_position = Vector3(level.arena_entry + 10, 0.2, 0.0)
	level._trigger_boss_fight()
	await _wait(1.2)
	player.aim_direction = Vector3(1.0, 0.4, 0.0).normalized()
	Input.action_press("shoot")
	await _wait(0.12)
	await _shot("/tmp/qa_boss.png")
	Input.action_release("shoot")

	print("QA SHOTS DONE")
	get_tree().quit()
