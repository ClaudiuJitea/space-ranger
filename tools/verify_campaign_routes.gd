extends Node
var failed := false
func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	for index in range(1, 4):
		GameManager.reset_game()
		var level: Node3D = load("res://src/levels/level_%02d.tscn" % index).instantiate()
		add_child(level)
		await frames(5)
		for enemy in level.enemies.get_children():
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
		for prop in level.props.get_children():
			if prop is StaticBody3D:
				prop.collision_layer = 0
		for platform in level.platforms.get_children():
			if platform is AnimatableBody3D:
				platform.collision_layer = 0
		level.hazards.process_mode = Node.PROCESS_MODE_DISABLED
		var keys: Array = level.route_floors.keys()
		keys.sort()
		var count := 0
		for i in range(keys.size() - 1):
			var a: float = keys[i]
			var b: float = keys[i + 1]
			if a < 0:
				continue
			var player: CharacterBody3D = level.player
			player.position = Vector3(a, level.route_floors[a] + 0.05, 0)
			player.velocity = Vector3.ZERO
			GameManager.health = 100
			GameManager.hurt_invuln_timer = 100
			await frames(5)
			Input.action_press("jump")
			await frames(1)
			Input.action_release("jump")
			var landed := false
			for tick in range(100):
				if player.position.x < b - 0.2:
					Input.action_press("move_right")
				else:
					Input.action_release("move_right")
				if tick == 22 and player.can_double_jump:
					Input.action_press("jump")
				if tick == 23:
					Input.action_release("jump")
				await frames(1)
				if tick > 5 and player.is_on_floor() and absf(player.position.x - b) < 1.6 and player.position.y >= float(level.route_floors[b]) - 0.3:
					landed = true
					break
			Input.action_release("move_right")
			Input.action_release("jump")
			if not landed:
				failed = true
				push_error("Mission %d route jump %s to %s failed; ended at %s" % [index, a, b, player.position])
			count += 1
		# Verify lifts physically carry the actual character, without input.
		for platform in level.platforms.get_children():
			if platform is AnimatableBody3D and platform.travel.y > 0:
				platform.collision_layer = 1
				level.player.position = platform.position + Vector3(0, 0.1, 0)
				level.player.velocity = Vector3.ZERO
				await frames(8)
				await frames(45)
				if absf(level.player.position.y - platform.position.y) > 0.3:
					failed = true
					push_error("Mission lift must carry player")
				break
		print("MISSION ", index, " ROUTE JUMPS CHECKED: ", count)
		level.queue_free()
		await frames(5)
	print("CAMPAIGN ROUTES: ", "FAILED" if failed else "PASSED")
	get_tree().quit(1 if failed else 0)
