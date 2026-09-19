class_name AbilityIndicator
extends Control

var ratio := 1.0:
	set(v):
		ratio = clampf(v, 0.0, 1.0)
		queue_redraw()
var seconds := 0.0
var _time := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(230, 34)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var center := Vector2(22, size.y * 0.5)
	var ready := ratio >= 0.999
	var c := Color(0.18, 0.86, 1.0)
	var glow := 0.55 + 0.35 * sin(_time * 4.0) if ready else 0.65
	draw_arc(center, 11.0, -PI*0.5, PI*1.5, 32, Color(0.1,0.22,0.28,0.85), 3.0, true)
	draw_arc(center, 11.0, -PI*0.5, -PI*0.5 + TAU*ratio, 32, Color(c.r,c.g,c.b,glow), 3.0, true)
	if ready:
		draw_circle(center, 4.0 + sin(_time*4.0), Color(c.r,c.g,c.b,0.22))
	var font := get_theme_default_font()
	var label := "[E/Q]  EMP ARRAY  //  READY" if ready else "[E/Q]  EMP ARRAY  //  %.1fs" % seconds
	draw_string(font, Vector2(48, center.y + 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c if ready else Color(0.48,0.56,0.62))
