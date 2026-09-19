extends Control

const MENU_STYLE := preload("res://src/ui/suit_menu_style.gd")

var _transitioning := false
@onready var card: PanelContainer = $Card
@onready var dim: Panel = $BackgroundDim

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	MENU_STYLE.decorate(card, Vector2(30, 25))
	var box := $Card/VBox as VBoxContainer
	var status := MENU_STYLE.eyebrow("SR-07 // TACTICAL HOLD")
	box.add_child(status)
	box.move_child(status, 0)
	$Card/VBox/Title.add_theme_font_size_override("font_size", 27)
	$Card/VBox/Subtitle.text = "COMBAT LINK HELD // AWAITING COMMAND"
	$Card/VBox/QuitBtn.text = "EXIT TO COMMAND"
	$Card/VBox/RestartBtn.text = "RESTART FROM ANCHOR"
	# UI feedback on every button in the menu.
	for btn in find_children("*", "Button", true, false):
		var b := btn as Button
		_style_button(b)
		b.mouse_entered.connect(func(): SoundManager.play("ui_hover", 1.0, -8.0))
		b.pressed.connect(func(): SoundManager.play("ui_click", 1.0, -4.0))

func _unhandled_input(event: InputEvent) -> void:
	var mission := get_tree().current_scene
	if mission and mission.get("completed") == true:
		return
	if event.is_action_pressed("pause") and GameManager.health > 0:
		toggle_pause()

func toggle_pause() -> void:
	if _transitioning:
		return
	_transitioning = true
	if not get_tree().paused:
		visible = true
		dim.modulate.a = 1.0
		card.modulate.a = 1.0
		card.scale = Vector2.ONE
		card.pivot_offset = card.size * 0.5
		SoundManager.play("alarm", 1.2, -6.0)
		get_tree().paused = true
		$Card/VBox/ResumeBtn.grab_focus()
	else:
		get_tree().paused = false
		var tw := create_tween().set_parallel(true)
		tw.tween_property(dim, "modulate:a", 0.0, 0.16)
		tw.tween_property(card, "modulate:a", 0.0, 0.16)
		tw.tween_property(card, "scale", Vector2(0.94, 0.94), 0.18)
		await tw.finished
		visible = false
	_transitioning = false

func _style_button(btn: Button) -> void:
	MENU_STYLE.button(btn, btn == $Card/VBox/ResumeBtn)

func _on_resume_pressed() -> void:
	toggle_pause()

func _on_restart_pressed() -> void:
	var mission := get_tree().current_scene
	if mission and mission.has_method("restart_mission"):
		mission.restart_mission()
		return
	get_tree().paused = false
	GameManager.reset_game()
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	# Abort back to the main menu (the menu itself owns quitting the app).
	get_tree().paused = false
	SoundManager.set_music_mood("menu")
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")
