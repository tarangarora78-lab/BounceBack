extends Node2D

const LIGHTNING_WARNING: float = 0.6
const LIGHTNING_FLASH: float = 0.24
const LIGHTNING_BOTTOM: float = 690.0

var _player: Node2D
var _rng := RandomNumberGenerator.new()
var _strike_cooldown: float = 2.2
var _warning_timer: float = 0.0
var _bolt_timer: float = 0.0
var _bolt_x: float = 0.0
var _bolt_seed: float = 0.0
var _time: float = 0.0

func _ready() -> void:
	z_index = 2
	_rng.randomize()
	_strike_cooldown = _rng.randf_range(1.7, 3.0)
	queue_redraw()

func configure(player: Node2D) -> void:
	_player = player

func _process(delta: float) -> void:
	_time += delta
	if is_instance_valid(_player):
		var follow_x: float = _player.global_position.x + 70.0 + sin(_time * 0.55) * 95.0
		global_position.x = move_toward(global_position.x, follow_x, 150.0 * delta)

	if _warning_timer > 0.0:
		_warning_timer = maxf(_warning_timer - delta, 0.0)
		if _warning_timer <= 0.0:
			_bolt_timer = LIGHTNING_FLASH
	elif _bolt_timer > 0.0:
		_bolt_timer = maxf(_bolt_timer - delta, 0.0)
		_check_lightning_hit()
	else:
		_strike_cooldown -= delta
		if _strike_cooldown <= 0.0:
			_begin_lightning_warning()
	queue_redraw()

func _begin_lightning_warning() -> void:
	_strike_cooldown = _rng.randf_range(1.8, 3.2)
	_bolt_seed = _rng.randf_range(0.0, TAU)
	var target_x: float = global_position.x
	if is_instance_valid(_player):
		target_x = _player.global_position.x + _rng.randf_range(-110.0, 110.0)
	_bolt_x = clampf(target_x, global_position.x - 125.0, global_position.x + 125.0)
	_warning_timer = LIGHTNING_WARNING

func _check_lightning_hit() -> void:
	if not is_instance_valid(_player):
		return
	var player_y: float = _player.global_position.y
	if player_y >= global_position.y + 58.0 and player_y <= LIGHTNING_BOTTOM:
		if absf(_player.global_position.x - _bolt_x) <= 32.0:
			if _player.has_method("die"):
				_player.call("die")

func _draw() -> void:
	var cloud_color := Color(0.045, 0.065, 0.11, 0.98)
	var cloud_rim := Color(0.28, 0.39, 0.58, 0.92)
	var cloud_points := PackedVector2Array([
		Vector2(-110.0, 6.0), Vector2(-105.0, -17.0), Vector2(-88.0, -32.0),
		Vector2(-66.0, -34.0), Vector2(-51.0, -57.0), Vector2(-23.0, -68.0),
		Vector2(3.0, -61.0), Vector2(20.0, -79.0), Vector2(51.0, -74.0),
		Vector2(73.0, -51.0), Vector2(98.0, -49.0), Vector2(117.0, -28.0),
		Vector2(116.0, -4.0), Vector2(93.0, 14.0), Vector2(-86.0, 18.0)
	])
	draw_colored_polygon(cloud_points, cloud_color)
	draw_polyline(PackedVector2Array([Vector2(-102.0, -8.0), Vector2(-88.0, -31.0), Vector2(-63.0, -31.0), Vector2(-48.0, -53.0), Vector2(-22.0, -63.0), Vector2(1.0, -57.0), Vector2(22.0, -74.0), Vector2(49.0, -69.0), Vector2(69.0, -47.0), Vector2(95.0, -44.0), Vector2(111.0, -25.0)]), cloud_rim, 3.0, true)
	draw_circle(Vector2(-65.0, 1.0), 28.0, cloud_color)
	draw_circle(Vector2(-18.0, -12.0), 38.0, cloud_color)
	draw_circle(Vector2(34.0, -17.0), 43.0, cloud_color)
	draw_circle(Vector2(81.0, -4.0), 31.0, cloud_color)

	if _warning_timer > 0.0:
		var warning_alpha: float = 0.35 + 0.25 * sin(_time * 18.0)
		var warning_points := _make_bolt_points()
		draw_polyline(warning_points, Color(0.8, 0.9, 1.0, warning_alpha), 3.0, true)
	elif _bolt_timer > 0.0:
		var bolt_points := _make_bolt_points()
		draw_polyline(bolt_points, Color(0.58, 0.88, 1.0, 0.95), 12.0, true)
		draw_polyline(bolt_points, Color(1.0, 1.0, 0.96, 1.0), 4.0, true)

func _make_bolt_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	var segment_count: int = 10
	var start_y: float = global_position.y + 40.0
	var height: float = LIGHTNING_BOTTOM - start_y
	for index in range(segment_count + 1):
		var progress: float = float(index) / float(segment_count)
		var offset_x: float = sin(_bolt_seed + float(index) * 2.7) * 22.0
		var point_x: float = _bolt_x + offset_x
		if index == 0 or index == segment_count:
			point_x = _bolt_x
		points.append(Vector2(point_x - global_position.x, start_y + height * progress - global_position.y))
	return points
