extends Node

## Temporary QA driver: boots the real level, then simulates combat inputs so
## the whole weapon system runs end-to-end in a headless CI-style pass.
## Run: godot --headless --path . res://tools/qa_drive.tscn

func _ready() -> void:
	var level: Node = load("res://src/levels/level_01.tscn").instantiate()
	add_child(level)
	_run()

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _run() -> void:
	await _wait(0.6)
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		push_error("QA: no player found")
		get_tree().quit(1)
		return
	var player: Node = players[0]

	# --- Cycle through every weapon and fire it -------------------------
	for w in range(4):
		GameManager.unlock_weapon(w)
		await _wait(0.35)
		if GameManager.current_weapon != w:
			push_error("QA: weapon %d did not equip (active: %d)" % [w, GameManager.current_weapon])
		Input.action_press("shoot")
		await _wait(0.6)
		Input.action_release("shoot")

	# --- Rocket detonation path (aim up so it hits something/pits) ------
	GameManager.select_weapon(3)
	await _wait(0.3)
	Input.action_press("shoot")
	await _wait(0.9)
	Input.action_release("shoot")

	# --- EMP secondary ---------------------------------------------------
	player._launch_secondary_emp()
	await _wait(0.3)

	# --- Movement: run right, jump, double jump, dash --------------------
	Input.action_press("move_right")
	await _wait(1.0)
	Input.action_press("jump")
	await _wait(0.05)
	Input.action_release("jump")
	await _wait(0.3)
	Input.action_press("jump")
	await _wait(0.05)
	Input.action_release("jump")
	Input.action_press("dash")
	await _wait(0.05)
	Input.action_release("dash")
	Input.action_release("move_right")
	await _wait(1.0)

	# --- Heat/overheat path ----------------------------------------------
	player.heat = player.max_heat
	player.is_overheated = true
	player.overheat_timer = 0.1
	await _wait(0.3)

	# --- Report -----------------------------------------------------------
	print("QA: health=%.0f score=%d weapon=%d instances=%d" % [
		GameManager.health, GameManager.score, GameManager.current_weapon,
		player.weapon_instances.size()])
	for w in range(player.weapon_instances.size()):
		if player._find_muzzle(player.weapon_instances[w]) == null:
			push_error("QA: weapon %d has no muzzle marker" % w)
	print("QA DRIVE OK")
	get_tree().quit()
