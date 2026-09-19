extends Node

func _ready() -> void:
	capture.call_deferred()

func capture() -> void:
	var menu: Node = load("res://src/ui/main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/qa_menu_with_gun.png")
	print("SAVED /tmp/qa_menu_with_gun.png")
	get_tree().quit()
