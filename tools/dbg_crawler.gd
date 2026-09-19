extends Node

## Temporary crawler debug probe.

func _ready() -> void:
	var level: Node = load("res://src/levels/level_01.tscn").instantiate()
	add_child(level)
	_run()

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _run() -> void:
	await _wait(1.5)
	var players := get_tree().get_nodes_in_group("player")
	var player: Node = players[0]
	player.global_position = Vector3(30.2, 1.4, 0.0)
	await _wait(1.0)
	for crawler in get_tree().get_nodes_in_group("enemies"):
		if crawler.name.begins_with("Crawler"):
			print("CRAWLER %s pos=%s vel=%s state=%d floor=%s model=%s vis_children=%d" % [
				crawler.name, crawler.global_position, crawler.velocity,
				crawler.state, crawler.is_on_floor(),
				crawler.get_node("Visual/Model") != null,
				crawler.get_node("Visual").get_child_count()])
	# Freeze crawler1 next to the player for a clean close-up
	var c1: Node = get_tree().get_nodes_in_group("enemies")[0]
	for crawler in get_tree().get_nodes_in_group("enemies"):
		if crawler.name == "Crawler1":
			crawler.set_physics_process(false)
			crawler.global_position = Vector3(31.8, 0.05, 0.0)
	player.aim_direction = Vector3(1.0, -0.05, 0.0)
	await _wait(0.5)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/qa_crawler_closeup.png")
	print("PROBE DONE")
	get_tree().quit()
