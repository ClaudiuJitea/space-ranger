extends Control

@export var accent := Color(0.0, 0.82, 1.0, 0.75)
@export_enum("generic", "vitals", "weapon", "score", "strip") var variant := "generic"
var _time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var tick := Color(accent.r, accent.g, accent.b, 0.55)
	# Layered registration brackets give every module the same manufactured
	# command-console silhouette without requiring baked panel textures.
	draw_line(Vector2(0, 12), Vector2(0, 0), tick, 1.0)
	draw_line(Vector2(0, 0), Vector2(minf(44.0, w * 0.22), 0), tick, 1.0)
	draw_line(Vector2(w, h - 12), Vector2(w, h), tick, 1.0)
	draw_line(Vector2(w, h), Vector2(w - minf(28.0, w * 0.14), h), tick, 1.0)
	draw_line(Vector2(7, 17), Vector2(7, 7), Color(tick, 0.28), 1.0)
	draw_line(Vector2(7, 7), Vector2(26, 7), Color(tick, 0.28), 1.0)
	draw_line(Vector2(w - 7, 17), Vector2(w - 7, 7), Color(tick, 0.28), 1.0)
	draw_line(Vector2(w - 7, 7), Vector2(w - 26, 7), Color(tick, 0.28), 1.0)
	for x in range(54, int(maxf(55.0, w - 34.0)), 7):
		draw_line(Vector2(x, 1), Vector2(x + 2, 1), Color(tick, 0.2), 1.0)

	match variant:
		"vitals":
			# Header shelf, right-side data notch, and the two telemetry tiers.
			draw_line(Vector2(17, 40), Vector2(w - 17, 40), Color(tick, 0.34), 1.0)
			draw_line(Vector2(17, 82), Vector2(w - 17, 82), Color(tick, 0.26), 1.0)
			draw_line(Vector2(w - 79, 8), Vector2(w - 55, 8), Color(tick, 0.5), 1.0)
			for x in range(int(w - 48), int(w - 15), 7):
				draw_circle(Vector2(x, 8), 0.8, Color(tick, 0.48))
		"weapon":
			# The lower rule creates a dedicated ability bay, as in the suit HUD.
			draw_line(Vector2(14, h - 39), Vector2(w - 14, h - 39), Color(tick, 0.38), 1.0)
			draw_line(Vector2(w - 83, 8), Vector2(w - 55, 8), Color(tick, 0.46), 1.0)
			for x in range(int(w - 48), int(w - 18), 7):
				draw_circle(Vector2(x, 8), 0.75, Color(tick, 0.42))
		"score":
			draw_line(Vector2(18, h - 26), Vector2(w - 18, h - 26), Color(tick, 0.25), 1.0)
		"strip":
			draw_line(Vector2(28, h - 4), Vector2(w - 28, h - 4), Color(tick, 0.22), 1.0)
