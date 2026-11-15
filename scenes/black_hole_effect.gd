extends Node2D

var _spin: float = 0.0

func _ready() -> void:
	z_index = -1
	show_behind_parent = true
	queue_redraw()

func _process(delta: float) -> void:
	_spin = wrapf(_spin + delta * 0.8, 0.0, TAU)
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = Vector2(0.0, -12.0)
	draw_circle(center, 104.0, Color(0.23, 0.08, 0.64, 0.12))
	draw_arc(center, 100.0, 0.0, TAU, 96, Color(0.63, 0.24, 1.0, 0.38), 13.0, true)

	draw_set_transform(center, _spin, Vector2(1.55, 0.5))
	draw_arc(Vector2.ZERO, 82.0, 0.0, TAU, 100, Color(1.0, 0.38, 0.74, 0.9), 13.0, true)
	draw_arc(Vector2.ZERO, 69.0, 0.0, TAU, 96, Color(0.36, 0.78, 1.0, 0.95), 6.0, true)
	draw_arc(Vector2.ZERO, 53.0, 0.0, TAU, 80, Color(0.69, 0.39, 1.0, 0.82), 5.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	draw_circle(center, 43.0, Color(0.015, 0.008, 0.035, 1.0))
	draw_arc(center, 44.0, 0.0, TAU, 80, Color(0.16, 0.8, 1.0, 0.92), 4.0, true)
	draw_arc(center, 49.0, 0.15, 2.55, 48, Color(1.0, 0.58, 0.35, 0.95), 5.0, true)

	for index in range(10):
		var angle: float = _spin * 1.6 + TAU * float(index) / 10.0
		var inner: Vector2 = center + Vector2.from_angle(angle) * 91.0
		var outer: Vector2 = center + Vector2.from_angle(angle + 0.12) * 102.0
		draw_line(inner, outer, Color(0.63, 0.83, 1.0, 0.68), 2.0, true)
