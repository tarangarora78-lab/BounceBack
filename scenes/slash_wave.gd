extends Node2D

const WAVE_SPEED: float = 1050.0
const WAVE_LIFETIME: float = 0.72

var _direction: float = 1.0
var _remaining: float = WAVE_LIFETIME
var _age: float = 0.0

func _ready() -> void:
	z_index = 1
	queue_redraw()

func configure(direction: float) -> void:
	_direction = -1.0 if direction < 0.0 else 1.0
	scale.x = _direction

func _process(delta: float) -> void:
	_age += delta
	_remaining -= delta
	position.x += _direction * WAVE_SPEED * delta
	_hit_birds()
	queue_redraw()
	if _remaining <= 0.0:
		queue_free()

func _hit_birds() -> void:
	var scene_root: Node = get_parent()
	if scene_root == null:
		return
	for child in scene_root.get_children():
		if child is Node2D and child.is_in_group("generated_birds") and not child.is_queued_for_deletion():
			if global_position.distance_to(child.global_position) <= 62.0:
				child.queue_free()

func _draw() -> void:
	var fade_in: float = clampf(_age / 0.055, 0.0, 1.0)
	var fade_out: float = clampf(_remaining / 0.16, 0.0, 1.0)
	var alpha: float = minf(fade_in, fade_out)
	var blade := PackedVector2Array([
		Vector2(-48.0, 23.0), Vector2(-41.0, 5.0), Vector2(-28.0, -15.0),
		Vector2(-10.0, -34.0), Vector2(12.0, -47.0), Vector2(31.0, -51.0),
		Vector2(18.0, -35.0), Vector2(4.0, -17.0), Vector2(-9.0, 3.0),
		Vector2(-20.0, 24.0), Vector2(-31.0, 39.0)
	])
	var glow_color: Color = Color(0.08, 0.62, 1.0, 0.42 * alpha)
	var edge_color: Color = Color(0.42, 0.9, 1.0, 0.95 * alpha)
	var core_color: Color = Color(1.0, 0.98, 0.9, 0.96 * alpha)
	draw_colored_polygon(blade, glow_color)
	var outline := blade.duplicate()
	outline.append(blade[0])
	draw_polyline(outline, edge_color, 4.0, true)
	draw_arc(Vector2(-8.0, -3.0), 42.0, -2.38, 0.72, 32, edge_color, 5.0, true)
	draw_arc(Vector2(-7.0, -3.0), 35.0, -2.28, 0.62, 32, core_color, 2.0, true)
	for streak in range(3):
		var offset: float = float(streak) * 12.0
		draw_line(Vector2(-56.0 - offset, 26.0 + offset * 0.18), Vector2(-39.0 - offset, 4.0 + offset * 0.18), Color(0.2, 0.76, 1.0, (0.42 - streak * 0.1) * alpha), 2.0, true)
