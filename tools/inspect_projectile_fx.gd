extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var scenes := [
		"res://src/projectiles/projectile.tscn",
		"res://src/projectiles/spread_projectile.tscn",
		"res://src/projectiles/beam_projectile.tscn",
		"res://src/projectiles/enemy_projectile.tscn",
	]
	for path in scenes:
		var projectile = load(path).instantiate()
		world.add_child(projectile)
		await process_frame
		projectile.init_projectile(Vector3.RIGHT, projectile.speed, projectile.damage, projectile.color, projectile.is_enemy, projectile.penetrates)
		print("PROJECTILE QA: %s layered_children=%d" % [path.get_file(), projectile.get_child_count()])
	quit()
