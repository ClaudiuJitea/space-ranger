extends Control

## Mouse-following tactical crosshair. Reads the current weapon color so the
## reticle always matches the active gun.

var gap: float = 8.0
var arm_len: float = 11.0
var _pulse: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(delta: float) -> void:
	_pulse += delta
	var mouse := get_viewport().get_mouse_position()
	position = mouse - size * 0.5
	queue_redraw()

func _draw() -> void:
	var col: Color = GameManager.WEAPON_COLORS[GameManager.current_weapon]
	col.a = 0.9
	var hot := Color(1.0, 1.0, 1.0, 0.95)
	var bloom := col
	bloom.a = 0.16
	draw_circle(Vector2.ZERO, 18.0 + sin(_pulse * 3.0), bloom, false, 1.0)
	# Four arms
	draw_line(Vector2(-gap - arm_len, 0), Vector2(-gap, 0), col, 2.0)
	draw_line(Vector2(gap, 0), Vector2(gap + arm_len, 0), col, 2.0)
	draw_line(Vector2(0, -gap - arm_len), Vector2(0, -gap), col, 2.0)
	draw_line(Vector2(0, gap), Vector2(0, gap + arm_len), col, 2.0)
	# Center dot
	draw_circle(Vector2.ZERO, 1.8, hot)
	draw_arc(Vector2.ZERO, 24.0, -2.62, -1.92, 8, col, 1.5)
	draw_arc(Vector2.ZERO, 24.0, 0.52, 1.22, 8, col, 1.5)
	# Corner ticks for a techy frame
	var c := gap + arm_len + 3.0
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := Vector2(sx * c, sy * c)
			draw_line(corner, corner + Vector2(-sx * 4.0, 0), col * Color(1, 1, 1, 0.5), 1.5)
			draw_line(corner, corner + Vector2(0, -sy * 4.0), col * Color(1, 1, 1, 0.5), 1.5)
