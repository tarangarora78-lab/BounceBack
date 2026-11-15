extends Node2D

func _ready() -> void:
	_add_ellipse(Vector2(0, 13), Vector2(100, 28), Color(0.49, 0.77, 0.93, 0.45))
	_add_ellipse(Vector2(-48, 0), Vector2(43, 34), Color(0.98, 0.99, 1.0, 0.96))
	_add_ellipse(Vector2(-8, -22), Vector2(48, 48), Color(0.98, 0.99, 1.0, 0.96))
	_add_ellipse(Vector2(39, -5), Vector2(42, 35), Color(0.98, 0.99, 1.0, 0.96))
	_add_ellipse(Vector2(70, 9), Vector2(30, 24), Color(0.98, 0.99, 1.0, 0.96))

func _add_ellipse(center: Vector2, radius: Vector2, tint: Color) -> void:
	var points := PackedVector2Array()
	for index in range(32):
		var angle := TAU * float(index) / 32.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	var lobe := Polygon2D.new()
	lobe.polygon = points
	lobe.color = tint
	add_child(lobe)
