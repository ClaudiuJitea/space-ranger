class_name SegmentedTelemetryBar
extends Control

@export var max_value: float = 100.0:
	set(v):
		max_value = maxf(v, 0.001)
		queue_redraw()
@export var value: float = 100.0:
	set(v):
		value = clampf(v, 0.0, max_value)
		queue_redraw()
@export var fill_color := Color(0.05, 0.82, 1.0)
@export var empty_color := Color(0.025, 0.07, 0.10, 0.92)
@export var segment_count: int = 14
@export var solid_fill := false

var _time := 0.0
var _impact := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func flash_damage() -> void:
	_impact = 1.0
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	_impact = maxf(_impact - delta * 2.8, 0.0)
	queue_redraw()

func _draw() -> void:
	if solid_fill:
		_draw_solid_bar()
		return
	var count := maxi(segment_count, 1)
	var gap := 2.0
	var cut := 4.0
	var w := (size.x - gap * float(count - 1)) / float(count)
	var ratio := clampf(value / max_value, 0.0, 1.0)
	var lit := ratio * float(count)
	for i in range(count):
		var x := float(i) * (w + gap)
		var poly := PackedVector2Array([
			Vector2(x + cut, 1.0), Vector2(x + w, 1.0),
			Vector2(x + w - cut, size.y - 1.0), Vector2(x, size.y - 1.0)])
		var active := lit >= float(i) + 0.15
		var c := fill_color if active else empty_color
		if active:
			var sweep := 0.82 + 0.18 * sin(_time * 2.1 + float(i) * 0.42)
			c = c * sweep
			c.a = 1.0
		if _impact > 0.0 and active:
			c = c.lerp(Color.WHITE, _impact * (0.35 + 0.25 * sin(_time * 32.0)))
		draw_colored_polygon(poly, c)
		draw_polyline(poly + PackedVector2Array([poly[0]]), c.lightened(0.28) if active else Color(0.1, 0.27, 0.32, 0.7), 1.0, true)
	var scan_x := fmod(_time * 46.0, maxf(size.x, 1.0))
	draw_line(Vector2(scan_x, 2.0), Vector2(scan_x - 5.0, size.y - 2.0), Color(fill_color, 0.24), 2.0, true)

func _draw_solid_bar() -> void:
	var ratio := clampf(value / max_value, 0.0, 1.0)
	var cut := minf(5.0, size.x * 0.08)
	var background := PackedVector2Array([
		Vector2(cut, 1.0), Vector2(size.x, 1.0),
		Vector2(size.x - cut, size.y - 1.0), Vector2(0.0, size.y - 1.0), Vector2(cut, 1.0)
	])
	draw_colored_polygon(background, empty_color)
	draw_polyline(background, Color(0.19, 0.42, 0.5, 0.8), 1.0, true)
	if ratio <= 0.001:
		return
	var fill_w := maxf(cut + 1.0, size.x * ratio)
	var fill := PackedVector2Array([
		Vector2(cut, 2.0), Vector2(fill_w, 2.0),
		Vector2(maxf(0.0, fill_w - cut), size.y - 2.0), Vector2(1.0, size.y - 2.0)
	])
	var c := fill_color
	if _impact > 0.0:
		c = c.lerp(Color.WHITE, _impact * (0.35 + 0.25 * sin(_time * 32.0)))
	draw_colored_polygon(fill, c)
	var shine_y := 3.0
	draw_line(Vector2(cut + 1.0, shine_y), Vector2(maxf(cut + 1.0, fill_w - 2.0), shine_y), Color(0.85, 1.0, 1.0, 0.42), 1.0, true)
