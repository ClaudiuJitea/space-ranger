extends Control

## Cut-metal console backing shared by suit notifications and mission reports.
var accent := Color(0.15, 0.8, 1.0)
var report := false
var remaining := 1.0:
	set(value):
		remaining = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)

func _draw() -> void:
	var w := size.x
	var h := size.y
	var cut := 18.0 if report else 10.0
	var outline := PackedVector2Array([Vector2(cut, 0), Vector2(w, 0),
		Vector2(w, h - cut), Vector2(w - cut, h), Vector2(0, h), Vector2(0, cut)])
	draw_colored_polygon(outline, Color(0.018, 0.035, 0.05, 0.97))
	var closed := outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, Color(accent, 0.35), 1.0, true)
	for y in range(8, int(h), 4):
		draw_line(Vector2(2, y), Vector2(w - 2, y), Color(0.3, 0.6, 0.75, 0.025))
	draw_line(Vector2(cut, 0), Vector2(minf(w * 0.45, 150.0), 0), accent, 2.0)
	draw_line(Vector2(0, cut), Vector2(0, h - 12), Color(accent, 0.8), 3.0)
	draw_line(Vector2(w - 44, h), Vector2(w - cut, h), accent, 2.0)
	if report:
		draw_line(Vector2(28, 56), Vector2(w - 28, 56), Color(accent, 0.2), 1.0)
		for i in range(6):
			var x := w - 80.0 + i * 7.0
			draw_line(Vector2(x, 15), Vector2(x + 3, 10), Color(accent, 0.5), 2.0)
	else:
		draw_line(Vector2(14, h - 5), Vector2(14 + (w - 28) * remaining, h - 5), Color(accent, 0.65), 2.0)
