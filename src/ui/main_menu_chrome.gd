extends Control

## Purely visual command-deck overlay for the main menu. Keeping the chrome in
## one draw call makes the layout crisp at every aspect ratio without needing a
## folder of resolution-specific textures.

var _time := 0.0
var _sweep := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	_sweep = fmod(_sweep + delta * 46.0, maxf(size.y, 1.0))
	queue_redraw()


func _draw() -> void:
	var viewport_size := size
	if viewport_size.x < 2.0 or viewport_size.y < 2.0:
		return

	var panel_w := clampf(viewport_size.x * 0.405, 500.0, 650.0)
	var h := viewport_size.y
	var cyan := Color(0.25, 0.78, 1.0, 0.72)
	var line := Color(0.32, 0.55, 0.7, 0.46)
	var faint := Color(0.28, 0.52, 0.68, 0.16)
	var font := get_theme_default_font()

	# The reference uses an offset, clipped-corner command pane rather than a
	# conventional opaque card. The layered fills preserve the live 3D scene.
	var panel := PackedVector2Array([
		Vector2(15, 23), Vector2(panel_w - 53, 23), Vector2(panel_w, 70),
		Vector2(panel_w, h - 24), Vector2(43, h - 24), Vector2(15, h - 51)
	])
	draw_colored_polygon(panel, Color(0.003, 0.012, 0.021, 0.87))
	var panel_outline := PackedVector2Array([
		Vector2(15, 23), Vector2(panel_w - 53, 23), Vector2(panel_w, 70),
		Vector2(panel_w, h - 24), Vector2(43, h - 24), Vector2(15, h - 51), Vector2(15, 23)
	])
	draw_polyline(panel_outline, line, 1.0, true)

	# Fine scan lines and a slow phosphor sweep give the panel a living display
	# feel, but remain deliberately quiet behind the labels.
	for y in range(28, int(h - 28), 5):
		draw_line(Vector2(18, y), Vector2(panel_w - 3, y), Color(0.2, 0.65, 0.85, 0.018), 1.0)
	draw_line(Vector2(19, _sweep), Vector2(panel_w - 4, _sweep), Color(0.24, 0.8, 1.0, 0.055), 1.0)

	# Header enclosure.
	var header := PackedVector2Array([
		Vector2(38, 51), Vector2(panel_w - 50, 51), Vector2(panel_w - 17, 82),
		Vector2(panel_w - 17, 202), Vector2(panel_w - 27, 212), Vector2(38, 212), Vector2(38, 51)
	])
	draw_polyline(header, line, 1.0, true)
	draw_line(Vector2(38, 51), Vector2(38, 76), cyan, 1.0)
	draw_line(Vector2(38, 51), Vector2(61, 51), cyan, 1.0)
	draw_line(Vector2(panel_w - 62, 63), Vector2(panel_w - 42, 63), faint, 1.0)
	draw_line(Vector2(panel_w - 52, 53), Vector2(panel_w - 52, 73), faint, 1.0)

	# Small technical marks around the command deck.
	for y in [246.0, 412.0, h - 132.0]:
		draw_line(Vector2(21, y), Vector2(30, y), faint, 1.0)
	draw_line(Vector2(39, h - 82), Vector2(panel_w - 139, h - 82), line, 1.0)
	draw_line(Vector2(panel_w - 108, h - 109), Vector2(panel_w - 108, h - 51), faint, 1.0)
	draw_line(Vector2(39, h - 92), Vector2(39, h - 70), cyan, 2.0)

	# Sparse telemetry in the open space keeps the composition feeling like a
	# navigational display instead of a menu pasted over a background.
	var cx := viewport_size.x * 0.775
	var cy := viewport_size.y * 0.42
	var pulse := 0.62 + sin(_time * 1.5) * 0.12
	draw_arc(Vector2(cx, cy), viewport_size.y * 0.37, -1.55, 1.35, 96, Color(0.2, 0.55, 0.82, 0.18), 1.0, true)
	draw_arc(Vector2(cx, cy), viewport_size.y * 0.51, -2.5, 0.55, 96, Color(0.2, 0.55, 0.82, 0.12), 1.0, true)
	var target := Vector2(viewport_size.x * 0.765, viewport_size.y * 0.395)
	var bracket := 8.0
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := target + Vector2(sx * 12.0, sy * 12.0)
			draw_line(corner, corner - Vector2(sx * bracket, 0), Color(0.58, 0.75, 0.88, pulse), 1.0)
			draw_line(corner, corner - Vector2(0, sy * bracket), Color(0.58, 0.75, 0.88, pulse), 1.0)
	draw_string(font, target + Vector2(27, -4), "SR-07", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.48, 0.67, 0.82, 0.72))
	draw_string(font, target + Vector2(27, 11), "ORBIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.36, 0.52, 0.67, 0.58))

	var right_x := viewport_size.x - 84.0
	draw_line(Vector2(right_x - 18, 47), Vector2(right_x + 18, 47), line, 1.0)
	draw_line(Vector2(right_x, 32), Vector2(right_x, 62), line, 1.0)
	draw_string(font, Vector2(right_x - 43, 132), "SILENT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.55, 0.68, 0.58))
	draw_string(font, Vector2(right_x - 43, 148), "SYSTEMS", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.55, 0.68, 0.58))
	draw_string(font, Vector2(right_x - 43, 174), "BRIGHTER", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.55, 0.68, 0.58))
	draw_string(font, Vector2(right_x - 43, 190), "HORIZONS", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.55, 0.68, 0.58))
	draw_line(Vector2(right_x - 43, 202), Vector2(right_x - 25, 202), Color(0.52, 0.7, 0.82, 0.65), 1.0)

	draw_string(font, Vector2(viewport_size.x - 194, h - 62), "SOME PLACES", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.35, 0.5, 0.62, 0.52))
	draw_string(font, Vector2(viewport_size.x - 194, h - 47), "STILL BELONG TO DISCOVERY", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.35, 0.5, 0.62, 0.52))
	draw_line(Vector2(viewport_size.x - 49, h - 50), Vector2(viewport_size.x - 31, h - 50), Color(0.42, 0.69, 0.85, 0.7), 1.0)

