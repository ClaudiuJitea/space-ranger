extends Node

var failed := false
func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
func frames(count := 5) -> void:
	for i in count:
		await get_tree().physics_frame
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	for index in range(1, 4):
		GameManager.reset_game()
		var path := "res://src/levels/level_%02d.tscn" % index
		var level: Node3D = load(path).instantiate()
		add_child(level)
		await frames()
		check(level.route_length >= [240, 288, 320][index - 1], "Mission must have expanded route")
		check(level.boss.boss_profile == index - 1, "Mission must have unique boss")
		check(level.boss._muzzles.size() == 2, "Blender boss must expose both weapon sockets")
		check(not level.gate_open and not level.boss.active, "Arena must begin sealed and boss dormant")
		for checkpoint in level.props.get_children():
			if checkpoint.get_script() == preload("res://src/environment/mission_checkpoint.gd"):
				level.player.position = checkpoint.position + Vector3(0, 0.05, 0)
				level.player.velocity = Vector3.ZERO
				await frames()
				check(checkpoint.triggered, "Suit anchor must activate on actual player overlap")
				break
		# Use actual keyboard dispatch and player/terminal proximity.
		for relay in get_tree().get_nodes_in_group("mission_relays"):
			level.player.position = relay.position + Vector3(-1, 0.05, 0)
			level.player.velocity = Vector3.ZERO
			await frames()
			check(relay.nearby, "Relay must be reachable from its deck")
			var event := InputEventAction.new()
			event.action = "interact"
			event.pressed = true
			Input.parse_input_event(event)
			await frames()
			check(relay.active, "F must sync mission relay: %s" % relay.relay_id)
			event.pressed = false
			Input.parse_input_event(event)
		check(level.gate_open, "All relays must open arena")
		level.register_checkpoint(Vector3(level.arena_entry - 12, level._floor_at(level.arena_entry - 12) + 0.2, 0))
		var saved_position: Vector3 = GameManager.mission_checkpoint.position
		var saved_score: int = GameManager.score
		GameManager.retry_pending = true
		GameManager.score += 900
		GameManager.mission_relays.clear()
		var restored: Vector3 = GameManager.prepare_mission(path, 0)
		check(restored == saved_position and GameManager.score == saved_score, "Retry must restore anchor position and score")
		check(GameManager.mission_relays.size() == level.relay_positions.size(), "Retry must restore synced relays")
		level.player.position = Vector3(level.arena_entry + 10, 0.05, 0)
		level._trigger_boss_fight()
		await frames()
		check(level.boss.active and GameManager.boss_active, "Arena must activate boss and HUD")
		for phase in range(1, 4):
			if phase > 1:
				level.boss._exposed = 0
				level.boss._shield_active = false
				level.boss.take_damage(level.boss.max_health * 0.34)
			check(level.boss.phase == phase, "Boss must enter combat phase %d" % phase)
			for attack in range(4):
				GameManager.health = 100
				level.boss.attack_state = attack - 1
				level.boss._telegraph()
				check(level.boss._warning.text.length() > 0, "Attack must have dodge telegraph")
				level.boss._execute_attack()
				level.boss._clear_markers()
				await frames(15)
		level.boss._shield_active = false
		level.boss.take_damage(10000)
		await frames(120)
		check(level.completed and level.hud.victory_panel.visible, "Boss defeat must complete mission")
		check(level.hud.final_mission == (index == 3), "Final mission must offer campaign replay")
		if index < 3:
			check(ResourceLoader.exists(level.hud.next_level_path), "Next mission must exist")
		print("MISSION ", index, " SYSTEM CHECKS COMPLETE")
		level.queue_free()
		await frames(10)
		GameManager.retry_pending = true
		var resumed: Node3D = load(path).instantiate()
		add_child(resumed)
		check(resumed.player.position.distance_to(saved_position) < 0.1, "Recreated mission must spawn at saved anchor")
		check(resumed.gate_open and not resumed.boss.active, "Recreated mission must preserve relays and reset boss")
		check(GameManager.health == GameManager.max_health, "Redeploy must restore full hull")
		# Reproduce arriving at a locked gate; verify F removes the actual collider.
		GameManager.mission_relays.clear()
		resumed._update_gate()
		resumed.player.set_physics_process(false)
		resumed.player.position = Vector3(resumed.gate.position.x - 1, 8, 0)
		await frames()
		var blocked: KinematicCollision3D = resumed.player.move_and_collide(Vector3(2, 0, 0))
		check(blocked != null and blocked.get_collider() == resumed.gate, "Locked gate must block actual player motion")
		resumed.player.position = Vector3(resumed.gate.position.x - 1, 8, 0)
		var override_event := InputEventAction.new()
		override_event.action = "interact"
		override_event.pressed = true
		Input.parse_input_event(override_event)
		await frames()
		check(resumed.gate_open and not resumed._gate_visual.visible, "F at gate must override lock and remove beams")
		check(resumed.player.move_and_collide(Vector3(2, 0, 0)) == null, "Unlocked gate must allow actual player passage")
		check(GameManager.mission_checkpoint.relays.size() == resumed.relay_positions.size(), "Newly synced relays must persist even after an earlier anchor")
		override_event.pressed = false
		Input.parse_input_event(override_event)
		resumed.queue_free()
		await frames(10)
	print("CAMPAIGN CHECKS: ", "FAILED" if failed else "PASSED")
	get_tree().quit(1 if failed else 0)
