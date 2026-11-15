extends Area2D

var _center_x: float = 0.0
var _base_y: float = 0.0
var _horizontal_range: float = 110.0
var _flight_speed: float = 1.8
var _phase: float = 0.0
var _time: float = 0.0
var _domain_falling: bool = false
var _fall_velocity: float = 0.0

@onready var art: Node2D = $Art
@onready var left_wing: Polygon2D = $Art/LeftWing
@onready var right_wing: Polygon2D = $Art/RightWing
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func configure_flight(center_x: float, base_y: float, horizontal_range: float, flight_speed: float, phase: float) -> void:
	_center_x = center_x
	_base_y = base_y
	_horizontal_range = horizontal_range
	_flight_speed = flight_speed
	_phase = phase
	position = Vector2(center_x, base_y)

func _physics_process(delta: float) -> void:
	if _domain_falling:
		_fall_velocity += 950.0 * delta
		position.y += _fall_velocity * delta
		art.rotation += 2.8 * delta
		if position.y > 900.0:
			queue_free()
		return
	_time += delta
	var flight_angle: float = _time * _flight_speed + _phase
	position.x = _center_x + sin(flight_angle) * _horizontal_range
	position.y = _base_y + sin(flight_angle * 1.8) * 20.0
	left_wing.rotation = sin(_time * 13.0 + _phase) * 0.45
	right_wing.rotation = -sin(_time * 13.0 + _phase) * 0.45
	art.scale.x = -1.0 if cos(flight_angle) < 0.0 else 1.0

func fall_after_domain() -> void:
	if _domain_falling:
		return
	_domain_falling = true
	_fall_velocity = -80.0
	collision_shape.set_deferred("disabled", true)
	art.modulate = Color(0.72, 0.68, 1.0, 1.0)
