class_name WeaponSilhouette
extends Control

var weapon_index := 0:
	set(v):
		weapon_index = v
		queue_redraw()
var accent := Color(0.1, 0.86, 1.0):
	set(v):
		accent = v
		queue_redraw()
var _time := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(152, 56)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var pulse := 0.84 + sin(_time * 2.4) * 0.08
	var core := Color(accent.r, accent.g, accent.b, pulse)
	var glow := Color(accent.r, accent.g, accent.b, 0.16)
	var scale := Vector2(size.x / 240.0, size.y / 70.0)
	# A restrained offset glow separates the icon from gameplay without turning
	# it into an unreadable solid blob.
	draw_set_transform(Vector2(2, 2), 0.0, scale)
	_draw_weapon(glow, false)
	draw_set_transform(Vector2.ZERO, 0.0, scale)
	_draw_weapon(core, true)
	draw_set_transform(Vector2.ZERO)

func _draw_weapon(color: Color, details: bool) -> void:
	match clampi(weapon_index, 0, 3):
		0: _draw_px9(color, details)
		1: _draw_titan8(color, details)
		2: _draw_lr77(color, details)
		3: _draw_hv4(color, details)

func _cut() -> Color:
	return Color(0.005, 0.025, 0.035, 0.94)

func _draw_px9(c: Color, details: bool) -> void:
	# PX-9: compact stock, deep receiver, optic and ventilated pulse shroud.
	draw_colored_polygon(PackedVector2Array([
		Vector2(10,31), Vector2(25,24), Vector2(52,24), Vector2(65,29),
		Vector2(59,38), Vector2(36,38), Vector2(23,46), Vector2(10,44)
	]), c)
	draw_colored_polygon(PackedVector2Array([
		Vector2(55,21), Vector2(137,21), Vector2(151,27), Vector2(151,42),
		Vector2(132,47), Vector2(58,43), Vector2(48,34)
	]), c)
	draw_colored_polygon(PackedVector2Array([
		Vector2(142,26), Vector2(218,26), Vector2(231,31), Vector2(218,38),
		Vector2(143,39)
	]), c)
	draw_colored_polygon(PackedVector2Array([
		Vector2(78,42), Vector2(101,42), Vector2(96,64), Vector2(79,64)
	]), c)
	draw_colored_polygon(PackedVector2Array([
		Vector2(88,13), Vector2(127,13), Vector2(136,19), Vector2(83,19)
	]), c)
	if details:
		var cut := _cut()
		for x in [161.0, 174.0, 187.0, 200.0]:
			draw_line(Vector2(x,29), Vector2(x - 5,36), cut, 3.0)
		draw_rect(Rect2(63, 27, 60, 4), Color(0.75, 0.96, 1.0, 0.55))
		draw_circle(Vector2(133,34), 4.0, cut)

func _draw_titan8(c: Color, details: bool) -> void:
	# TITAN-8: chunky breach, twin barrels, ribbed pump and pressure cylinder.
	draw_colored_polygon(PackedVector2Array([
		Vector2(8,29), Vector2(34,19), Vector2(64,20), Vector2(78,27),
		Vector2(68,41), Vector2(41,41), Vector2(24,49), Vector2(8,45)
	]), c)
	draw_colored_polygon(PackedVector2Array([
		Vector2(61,18), Vector2(145,18), Vector2(159,25), Vector2(153,43),
		Vector2(70,47), Vector2(55,35)
	]), c)
	draw_rect(Rect2(145,22,78,7), c)
	draw_rect(Rect2(145,35,78,7), c)
	draw_rect(Rect2(218,19,14,12), c)
	draw_rect(Rect2(218,33,14,12), c)
	draw_colored_polygon(PackedVector2Array([
		Vector2(143,44), Vector2(190,44), Vector2(183,54), Vector2(149,54)
	]), c)
	draw_colored_polygon(PackedVector2Array([
		Vector2(81,43), Vector2(105,43), Vector2(99,65), Vector2(80,65)
	]), c)
	draw_circle(Vector2(126,51), 9.0, c)
	if details:
		var cut := _cut()
		draw_circle(Vector2(126,51), 4.0, cut)
		for x in [153.0, 163.0, 173.0, 183.0]:
			draw_line(Vector2(x,45), Vector2(x - 4,53), cut, 2.0)
		draw_rect(Rect2(72,24,66,5), Color(0.8, 0.97, 1.0, 0.48))

func _draw_lr77(c: Color, details: bool) -> void:
	# LR-77: skeletal stock, narrow accelerator spine and separated coil banks.
	draw_colored_polygon(PackedVector2Array([
		Vector2(8,31), Vector2(25,21), Vector2(49,21), Vector2(65,28),
		Vector2(55,37), Vector2(34,37), Vector2(20,47), Vector2(8,43)
	]), c)
	draw_colored_polygon(PackedVector2Array([
		Vector2(50,24), Vector2(117,24), Vector2(132,30), Vector2(124,42),
		Vector2(54,42), Vector2(42,34)
	]), c)
	draw_rect(Rect2(112,30,112,6), c)
	for x in range(128, 207, 13):
		draw_rect(Rect2(float(x), 22, 8, 22), c)
	draw_colored_polygon(PackedVector2Array([
		Vector2(214,24), Vector2(234,28), Vector2(238,33), Vector2(232,39),
		Vector2(214,42)
	]), c)
	draw_rect(Rect2(72,13,48,5), c)
	draw_rect(Rect2(84,17,5,7), c)
	draw_colored_polygon(PackedVector2Array([
		Vector2(76,40), Vector2(99,40), Vector2(94,64), Vector2(76,64)
	]), c)
	if details:
		var cut := _cut()
		for x in range(136, 202, 13):
			draw_line(Vector2(float(x),24), Vector2(float(x),42), cut, 2.0)
		draw_line(Vector2(120,33), Vector2(222,33), Color(0.82, 0.98, 1.0, 0.72), 2.0)
		draw_rect(Rect2(57,29,54,4), cut)

func _draw_hv4(c: Color, details: bool) -> void:
	# HV-4: unmistakable oversized launch tube, aft brace and loaded nose cone.
	draw_colored_polygon(PackedVector2Array([
		Vector2(8,25), Vector2(25,17), Vector2(55,17), Vector2(69,24),
		Vector2(62,45), Vector2(39,45), Vector2(23,53), Vector2(8,48)
	]), c)
	draw_colored_polygon(PackedVector2Array([
		Vector2(48,15), Vector2(198,15), Vector2(216,22), Vector2(216,48),
		Vector2(198,55), Vector2(48,52)
	]), c)
	draw_colored_polygon(PackedVector2Array([
		Vector2(214,20), Vector2(235,29), Vector2(239,35), Vector2(234,41),
		Vector2(214,48)
	]), c)
	for x in [68.0, 94.0, 170.0, 195.0]:
		draw_rect(Rect2(x,12,6,44), Color(c.r, c.g, c.b, minf(c.a + 0.08, 1.0)))
	draw_rect(Rect2(91,7,69,6), c)
	draw_colored_polygon(PackedVector2Array([
		Vector2(82,48), Vector2(106,48), Vector2(101,66), Vector2(83,66)
	]), c)
	draw_circle(Vector2(141,52), 11.0, c)
	if details:
		var cut := _cut()
		draw_circle(Vector2(141,52), 5.0, cut)
		draw_line(Vector2(56,25), Vector2(205,25), Color(0.82, 0.98, 1.0, 0.48), 3.0)
		draw_rect(Rect2(183,31,28,8), cut)
