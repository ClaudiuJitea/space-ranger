extends Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()

func toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	visible = paused
	if paused:
		SoundManager.play("alarm", 1.2, -6.0)

func _on_resume_pressed() -> void:
	toggle_pause()

func _on_restart_pressed() -> void:
	get_tree().paused = false
	GameManager.reset_game()
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	get_tree().quit()
