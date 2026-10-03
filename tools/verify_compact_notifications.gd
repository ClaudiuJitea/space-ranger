extends Node
var failed := false
func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	GameManager.reset_game()
	var level: Node3D = load("res://src/levels/level_01.tscn").instantiate()
	add_child(level)
	await get_tree().create_timer(0.1).timeout
	level.player.set_physics_process(false)
	for enemy in level.enemies.get_children(): enemy.set_physics_process(false)
	var hud: Control = level.get_node("HUD")
	for i in range(3): hud._on_notify_requested("HULL PATCHED  +15", Color(1, 0.8, 0.2))
	await get_tree().process_frame
	check(hud._toast_box.get_child_count() == 1, "Pickups must never create a stack")
	check(hud._toast_label.text == "+45 HULL", "Repeated repairs must aggregate")
	check(hud._toast_box.size.y <= 36 and hud._toast_box.size.x <= 262, "Readout must stay compact")
	check(hud._toast_box.position.x > get_viewport().get_visible_rect().size.x * 0.65, "Readout must stay outside the centre")
	if not DisplayServer.get_name() == "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/screenshots/arsenal/compact_hud.png")
	await get_tree().create_timer(0.9).timeout
	hud._on_notify_requested("HULL PATCHED  +15", Color.YELLOW)
	await get_tree().create_timer(0.7).timeout
	check(hud._toast_box.visible, "An earlier fade must not erase a newer pickup")
	await get_tree().create_timer(1.1).timeout
	check(not hud._toast_box.visible, "Pickup readout must expire")
	hud._on_notify_requested("WEAPON ACQUIRED [2] TITAN-8", Color.CYAN)
	check(hud._toast_label.text.contains("[2]"), "New weapons must retain equip hints")
	print("COMPACT NOTIFICATIONS: ", "FAILED" if failed else "PASSED")
	get_tree().quit(1 if failed else 0)
