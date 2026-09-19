extends Control

## Resolution-independent menu pictograms. These are drawn as vectors instead
## of font glyphs so their proportions and stroke weights stay consistent.

var icon_type := "deploy":
	set(value):
		icon_type = value
		queue_redraw()
var accent := false:
	set(value):
		accent = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var color := Color(0.3, 0.87, 1.0, 1.0) if accent else Color(0.62, 0.76, 0.86, 0.96)
	match icon_type:
		"deploy":
			_draw_deploy(center, color)
		"controls":
			_draw_controller(center, color)
		"settings":
			_draw_settings(center, color)
		"quit":
			_draw_exit(center, color)


func _draw_deploy(c: Vector2, color: Color) -> void:
	# Compact fighter silhouette used by DEPLOY MISSION.
	var hull := PackedVector2Array([
		c + Vector2(-11.0, 0.0),
		c + Vector2(-6.0, -3.5),
		c + Vector2(2.0, -2.2),
		c + Vector2(11.0, 0.0),
		c + Vector2(2.0, 2.2),
		c + Vector2(-6.0, 3.5),
	])
	draw_colored_polygon(hull, color)
	draw_polyline(PackedVector2Array([
		c + Vector2(-2.0, -2.0), c + Vector2(-7.0, -9.0), c + Vector2(1.0, -2.4)
	]), color, 1.6, true)
	draw_polyline(PackedVector2Array([
		c + Vector2(-2.0, 2.0), c + Vector2(-7.0, 9.0), c + Vector2(1.0, 2.4)
	]), color, 1.6, true)
	draw_line(c + Vector2(-11.0, 0.0), c + Vector2(-7.5, 0.0), Color(0.7, 0.96, 1.0, 0.85), 1.5, true)


func _draw_controller(c: Vector2, color: Color) -> void:
	var body := PackedVector2Array([
		c + Vector2(-12, 8), c + Vector2(-11, -4), c + Vector2(-7, -10),
		c + Vector2(-3, -11), c + Vector2(0, -8), c + Vector2(3, -11),
		c + Vector2(7, -10), c + Vector2(11, -4), c + Vector2(12, 8),
		c + Vector2(9, 12), c + Vector2(5, 5), c + Vector2(-5, 5),
		c + Vector2(-9, 12), c + Vector2(-12, 8)
	])
	draw_polyline(body, color, 1.7, true)
	# D-pad.
	draw_line(c + Vector2(-7, -3), c + Vector2(-7, 3), color, 1.6, true)
	draw_line(c + Vector2(-10, 0), c + Vector2(-4, 0), color, 1.6, true)
	# Face buttons.
	draw_circle(c + Vector2(6, -2), 1.45, color, true, -1.0, true)
	draw_circle(c + Vector2(9, 1), 1.45, color, true, -1.0, true)


func _draw_settings(c: Vector2, color: Color) -> void:
	var teeth := PackedVector2Array()
	var points := 24
	for i in range(points + 1):
		var angle := TAU * float(i) / float(points)
		var tooth_phase := i % 3
		var radius := 12.0 if tooth_phase == 0 else (9.4 if tooth_phase == 1 else 10.3)
		teeth.append(c + Vector2(cos(angle), sin(angle)) * radius)
	draw_polyline(teeth, color, 1.55, true)
	draw_circle(c, 4.0, color, false, 1.55, true)
	# Small cardinal cuts make the silhouette read as a machined gear.
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(c + direction * 9.2, c + direction * 12.0, color, 2.2, true)


func _draw_exit(c: Vector2, color: Color) -> void:
	# Open hatch.
	var door := Rect2(c + Vector2(0, -12), Vector2(12, 24))
	draw_line(door.position, door.position + Vector2(door.size.x, 0), color, 1.55, true)
	draw_line(door.position + Vector2(door.size.x, 0), door.end, color, 1.55, true)
	draw_line(door.end, door.position + Vector2(0, door.size.y), color, 1.55, true)
	# Outbound arrow.
	draw_line(c + Vector2(-12, 0), c + Vector2(6, 0), color, 1.8, true)
	draw_line(c + Vector2(-12, 0), c + Vector2(-6, -6), color, 1.8, true)
	draw_line(c + Vector2(-12, 0), c + Vector2(-6, 6), color, 1.8, true)
