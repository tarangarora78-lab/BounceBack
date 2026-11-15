extends StaticBody2D

@onready var art: Sprite2D = $Sprite2D
var _bounce_tween: Tween
var _base_position: Vector2 = Vector2.ZERO
var _motion_amplitude: float = 0.0
var _motion_speed: float = 0.0
var _motion_phase: float = 0.0
var _motion_time: float = 0.0
var _motion_axis: Vector2 = Vector2.DOWN
var _crumble_enabled: bool = false
var _crumble_state: int = 0
var _crumble_timer: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func configure_vertical_motion(amplitude: float, speed: float, phase: float) -> void:
	configure_motion(Vector2.DOWN, amplitude, speed, phase)

func configure_horizontal_motion(amplitude: float, speed: float, phase: float) -> void:
	configure_motion(Vector2.RIGHT, amplitude, speed, phase)

func configure_motion(axis: Vector2, amplitude: float, speed: float, phase: float) -> void:
	_base_position = position
	_motion_axis = axis.normalized()
	_motion_amplitude = amplitude
	_motion_speed = speed
	_motion_phase = phase

func set_art_flipped(flipped: bool) -> void:
	art.flip_h = flipped

func configure_crumbling() -> void:
	_crumble_enabled = true

func is_temporary_platform() -> bool:
	return _crumble_enabled

func _physics_process(delta: float) -> void:
	if _motion_amplitude > 0.0:
		_motion_time += delta
		position = _base_position + _motion_axis * sin(_motion_time * _motion_speed + _motion_phase) * _motion_amplitude
	if _crumble_state == 1:
		_crumble_timer -= delta
		art.modulate = Color(1.0, 0.55, 0.55, 1.0) if int(_crumble_timer * 14.0) % 2 == 0 else Color.WHITE
		if _crumble_timer <= 0.0:
			visible = false
			collision_shape.set_deferred("disabled", true)
			_crumble_state = 2
			_crumble_timer = 1.25
	elif _crumble_state == 2:
		_crumble_timer -= delta
		if _crumble_timer <= 0.0:
			visible = true
			collision_shape.set_deferred("disabled", false)
			art.modulate = Color.WHITE
			_crumble_state = 0

func play_bounce() -> void:
	if _crumble_enabled and _crumble_state == 0:
		_crumble_state = 1
		_crumble_timer = 0.65
	if _bounce_tween != null and _bounce_tween.is_running():
		_bounce_tween.kill()
	_bounce_tween = create_tween()
	_bounce_tween.tween_property(art, "scale", Vector2(0.25, 0.16), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(art, "scale", Vector2(0.195, 0.245), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(art, "scale", Vector2(0.22, 0.22), 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
