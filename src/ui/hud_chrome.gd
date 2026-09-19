extends Control

## Resolution-independent cockpit/suit overlay. Drawn in-engine so it stays
## razor sharp at any resolution and adds no texture memory.

var pulse: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()

func _draw() -> void:
	var viewport_size := size
	if viewport_size.x < 320.0 or viewport_size.y < 200.0:
		return
	var cyan := Color(0.16, 0.72, 0.9, 0.34)
	var faint := Color(0.22, 0.55, 0.7, 0.12)
	var alert := Color(1.0, 0.3, 0.08, 0.28 + sin(pulse * 2.4) * 0.06)
	var margin := 17.0
	var corner := 58.0
	# Chamfered visor corners.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var anchor := Vector2(margin if sx < 0 else viewport_size.x - margin, margin if sy < 0 else viewport_size.y - margin)
			draw_line(anchor, anchor + Vector2(sx * corner, 0), cyan, 2.0)
			draw_line(anchor, anchor + Vector2(0, sy * corner), cyan, 2.0)
			var notch := anchor + Vector2(sx * (corner + 5.0), sy * 5.0)
			draw_line(notch, notch + Vector2(sx * 22.0, 0), faint, 1.0)
	# Thin horizon datum sells the suit-camera layer without obscuring combat.
	var cy := viewport_size.y * 0.5
	for sx in [-1.0, 1.0]:
		var edge_x := 18.0 if sx < 0 else viewport_size.x - 18.0
		draw_line(Vector2(edge_x, cy), Vector2(edge_x + sx * 34.0, cy), faint, 1.0)
		draw_line(Vector2(edge_x, cy - 5.0), Vector2(edge_x, cy + 5.0), cyan, 1.0)
	# Arena alert datum on the far right.
	draw_line(Vector2(viewport_size.x - 28.0, viewport_size.y * 0.38), Vector2(viewport_size.x - 28.0, viewport_size.y * 0.62), alert, 1.0)

	# Sparse optical calibration marks in the negative space. These echo the
	# reference HUD's suit-glass overlay without competing with gameplay.
	var grid_origin := Vector2(viewport_size.x - 67.0, viewport_size.y - 91.0)
	for gx in range(5):
		for gy in range(5):
			var strength := 0.22 if (gx + gy) % 2 == 0 else 0.11
			draw_circle(grid_origin + Vector2(gx * 7.0, gy * 7.0), 0.8, Color(0.25, 0.74, 0.9, strength))
	draw_line(Vector2(viewport_size.x - 155.0, viewport_size.y - 58.0), Vector2(viewport_size.x - 52.0, viewport_size.y - 58.0), faint, 1.0)
	draw_line(Vector2(viewport_size.x - 52.0, viewport_size.y - 58.0), Vector2(viewport_size.x - 39.0, viewport_size.y - 71.0), cyan, 1.0)
	for i in range(4):
		var y := viewport_size.y * 0.43 + float(i) * 9.0
		draw_line(Vector2(18.0, y), Vector2(21.0 + float(i % 2) * 3.0, y), faint, 1.0)
