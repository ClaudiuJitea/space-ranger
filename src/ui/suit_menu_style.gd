extends RefCounted

const CYAN := Color(0.15, 0.8, 1.0)
const MONO := preload("res://assets/fonts/ShareTechMono-Regular.ttf")

static func decorate(panel: PanelContainer, padding: Vector2, accent := CYAN) -> Control:
	var style := StyleBoxEmpty.new()
	style.content_margin_left = padding.x
	style.content_margin_right = padding.x
	style.content_margin_top = padding.y
	style.content_margin_bottom = padding.y
	panel.add_theme_stylebox_override("panel", style)
	var backing := Control.new()
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(backing)
	panel.move_child(backing, 0)
	var chrome := Control.new()
	chrome.set_script(preload("res://src/ui/message_chrome.gd"))
	chrome.set("accent", accent)
	chrome.set("report", true)
	backing.add_child(chrome)
	chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	chrome.offset_left = -padding.x
	chrome.offset_right = padding.x
	chrome.offset_top = -padding.y
	chrome.offset_bottom = padding.y
	return chrome

static func button(button: Button, primary := false, accent := CYAN) -> void:
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color(0.9, 0.96, 1) if primary else Color(0.68, 0.78, 0.85))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.025, 0.045, 0.07, 0.94)
		style.border_color = accent if primary or state != "normal" else Color(0.2, 0.36, 0.48)
		style.set_border_width_all(1)
		style.border_width_left = 3
		if state == "hover":
			style.bg_color = Color(accent.r * 0.15, accent.g * 0.15, accent.b * 0.15, 1)
		elif state == "pressed":
			style.bg_color = Color(accent.r * 0.25, accent.g * 0.25, accent.b * 0.25, 1)
		elif state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.set_border_width_all(2)
		style.content_margin_left = 18
		style.content_margin_right = 18
		button.add_theme_stylebox_override(state, style)

static func eyebrow(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", MONO)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", CYAN)
	return label

static func slider(slider: HSlider) -> void:
	for state in ["slider", "grabber_area", "grabber_area_highlight"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.17, 0.23) if state == "slider" else CYAN
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		slider.add_theme_stylebox_override(state, style)
	# Tiny rectangular handles keep the telemetry rail consistent with the HUD.
	var image := Image.create(8, 16, false, Image.FORMAT_RGBA8)
	image.fill(CYAN)
	var texture := ImageTexture.create_from_image(image)
	slider.add_theme_icon_override("grabber", texture)
	slider.add_theme_icon_override("grabber_highlight", texture)

static func separator() -> HSeparator:
	var rule := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = Color(CYAN, 0.25)
	style.thickness = 1
	rule.add_theme_stylebox_override("separator", style)
	return rule
