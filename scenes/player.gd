extends CharacterBody2D

const BLACK_HOLE_EFFECT_SCRIPT: Script = preload("res://scenes/black_hole_effect.gd")
const SLASH_WAVE_SCRIPT: Script = preload("res://scenes/slash_wave.gd")

signal died
signal won
signal checkpoint_reached(position: Vector2)
signal dash_status_changed(seconds_remaining: float, enabled: bool)
signal gojo_domain_status_changed(seconds_remaining: float, enabled: bool, active: bool)
signal gojo_domain_started

@export var air_speed: float = 350.0
@export var gravity: float = 1000.0
@export var bounce_velocity: float = 700.0

const DASH_COOLDOWN: float = 5.0
const DASH_SPEED: float = 1100.0
const DASH_FALLBACK_DISTANCE: float = 440.0
const GOJO_DOMAIN_COOLDOWN: float = 10.0
const GOJO_DOMAIN_DURATION: float = 10.0
const GOJO_LIFT_SPEED: float = -520.0
const GOJO_LIFT_TIME: float = 0.32
const GOJO_HOVER_TIME: float = 9.65

var _is_dead: bool = false
var _land_timer: float = 0.0
var _hurt_timer: float = 0.0
var _dash_enabled: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown: float = 0.0
var _dash_direction: float = 1.0
var _facing_direction: float = 1.0
var _space_was_pressed: bool = false
var _gojo_domain_enabled: bool = false
var _gojo_domain_timer: float = 0.0
var _gojo_cooldown: float = 0.0
var _gojo_domain_duration: float = GOJO_DOMAIN_DURATION
var _gojo_lift_timer: float = 0.0
var _gojo_hover_timer: float = 0.0
var _gojo_hover_duration: float = GOJO_HOVER_TIME
var _black_hole_effect: Node2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var bounce_sound: AudioStreamPlayer = $BounceSound
@onready var death_sound: AudioStreamPlayer = $DeathSound
@onready var slash_sound: AudioStreamPlayer = $SlashSound

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_land_timer = maxf(_land_timer - delta, 0.0)
	_hurt_timer = maxf(_hurt_timer - delta, 0.0)
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	_gojo_cooldown = maxf(_gojo_cooldown - delta, 0.0)
	_gojo_domain_timer = maxf(_gojo_domain_timer - delta, 0.0)
	_gojo_lift_timer = maxf(_gojo_lift_timer - delta, 0.0)
	_gojo_hover_timer = maxf(_gojo_hover_timer - delta, 0.0)
	if _gojo_domain_timer <= 0.0:
		_hide_black_hole_effect()

	var move_left_pressed: bool = Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	var move_right_pressed: bool = Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
	var direction: float = float(move_right_pressed) - float(move_left_pressed)
	if direction != 0.0:
		_facing_direction = direction
		animated_sprite.flip_h = direction < 0.0
	var space_pressed: bool = Input.is_physical_key_pressed(KEY_SPACE)
	if _dash_enabled and space_pressed and not _space_was_pressed and _dash_cooldown <= 0.0:
		_dash_direction = _facing_direction
		_dash_timer = _dash_distance_to_next_sofa(_dash_direction) / DASH_SPEED
		_dash_cooldown = DASH_COOLDOWN
		slash_sound.play()
		_spawn_slash_wave(_dash_direction)
	elif _gojo_domain_enabled and space_pressed and not _space_was_pressed and _gojo_cooldown <= 0.0 and _gojo_domain_timer <= 0.0:
		_activate_gojo_domain()
	_space_was_pressed = space_pressed
	if _dash_timer > 0.0:
		_dash_timer = maxf(_dash_timer - delta, 0.0)
		velocity = Vector2(_dash_direction * DASH_SPEED, 0.0)
	else:
		if _gojo_lift_timer > 0.0:
			velocity.y = GOJO_LIFT_SPEED
		elif _gojo_hover_timer > 0.0:
			velocity.y = 0.0
		elif not is_on_floor():
			velocity.y += gravity * delta
		velocity.x = direction * air_speed
	emit_signal("dash_status_changed", _dash_cooldown, _dash_enabled)
	emit_signal("gojo_domain_status_changed", _gojo_cooldown, _gojo_domain_enabled, _gojo_domain_timer > 0.0)

	var was_falling: bool = velocity.y > 0.0
	move_and_slide()
	for collision_index: int in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(collision_index)
		var other: Object = collision.get_collider()
		if other is Node and other.name == "Ground":
			die()
			return
		if other is Node and other.is_in_group("sofas") and collision.get_normal().y < -0.5 and was_falling:
			velocity.y = -bounce_velocity
			if other is Node2D and (not other.has_method("is_temporary_platform") or not other.call("is_temporary_platform")):
				checkpoint_reached.emit(other.global_position)
			bounce_sound.play()
			_land_timer = 0.12
			animated_sprite.play("land")
			if other.has_method("play_bounce"):
				other.call("play_bounce")
		elif other is Node and other.is_in_group("sofas") and absf(collision.get_normal().x) > 0.5:
			_hurt_timer = 0.15
			animated_sprite.play("hurt")

	_update_animation()

func _update_animation() -> void:
	var next_animation: StringName = &"fall"
	if _dash_timer > 0.0:
		next_animation = &"jump"
	elif _hurt_timer > 0.0:
		next_animation = &"hurt"
	elif _land_timer > 0.0:
		next_animation = &"land"
	elif is_on_floor():
		next_animation = &"run" if absf(velocity.x) > 1.0 else &"idle"
	elif velocity.y < 0.0:
		next_animation = &"jump"
	if animated_sprite.animation != next_animation:
		animated_sprite.play(next_animation)

func finish_level() -> void:
	if _is_dead:
		return
	_is_dead = true
	velocity = Vector2.ZERO
	_gojo_domain_timer = 0.0
	_gojo_lift_timer = 0.0
	_gojo_hover_timer = 0.0
	_hide_black_hole_effect()
	won.emit()

func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	velocity = Vector2.ZERO
	_gojo_domain_timer = 0.0
	_gojo_lift_timer = 0.0
	_gojo_hover_timer = 0.0
	_hide_black_hole_effect()
	animated_sprite.play("die")
	death_sound.play()
	died.emit()

func reset_for_level() -> void:
	_is_dead = false
	_land_timer = 0.0
	_hurt_timer = 0.0
	_dash_timer = 0.0
	_dash_cooldown = 0.0
	_gojo_domain_timer = 0.0
	_gojo_lift_timer = 0.0
	_gojo_hover_timer = 0.0
	_hide_black_hole_effect()
	_gojo_cooldown = 0.0
	_space_was_pressed = Input.is_physical_key_pressed(KEY_SPACE)
	velocity = Vector2.ZERO
	modulate = Color.WHITE
	animated_sprite.play("idle")
	emit_signal("dash_status_changed", _dash_cooldown, _dash_enabled)
	emit_signal("gojo_domain_status_changed", _gojo_cooldown, _gojo_domain_enabled, false)

func set_dash_enabled(enabled: bool) -> void:
	_dash_enabled = enabled
	_dash_timer = 0.0
	_dash_cooldown = 0.0
	_space_was_pressed = Input.is_physical_key_pressed(KEY_SPACE)
	emit_signal("dash_status_changed", _dash_cooldown, _dash_enabled)

func set_gojo_domain_enabled(enabled: bool) -> void:
	_gojo_domain_enabled = enabled
	_gojo_domain_timer = 0.0
	_gojo_lift_timer = 0.0
	_gojo_hover_timer = 0.0
	_hide_black_hole_effect()
	_gojo_cooldown = 0.0
	_space_was_pressed = Input.is_physical_key_pressed(KEY_SPACE)
	emit_signal("gojo_domain_status_changed", _gojo_cooldown, _gojo_domain_enabled, false)

func is_domain_active() -> bool:
	return _gojo_domain_timer > 0.0

func set_gojo_domain_duration(duration: float) -> void:
	if duration <= 0.0:
		return
	_gojo_domain_duration = duration
	_gojo_hover_duration = maxf(_gojo_domain_duration - GOJO_LIFT_TIME, 0.0)

func end_gojo_domain() -> void:
	_gojo_domain_timer = 0.0
	_gojo_lift_timer = 0.0
	_gojo_hover_timer = 0.0
	_hide_black_hole_effect()

func _activate_gojo_domain() -> void:
	_gojo_domain_timer = _gojo_domain_duration
	_gojo_lift_timer = GOJO_LIFT_TIME
	_gojo_hover_timer = _gojo_hover_duration
	_gojo_cooldown = GOJO_DOMAIN_COOLDOWN
	_show_black_hole_effect()
	gojo_domain_started.emit()
	var scene_root: Node = get_parent()
	if scene_root == null:
		return
	var nearby_birds: Array[Node2D] = []
	for child in scene_root.get_children():
		if child.is_in_group("generated_birds") and child is Node2D:
			nearby_birds.append(child)
	nearby_birds.sort_custom(func(first: Node2D, second: Node2D) -> bool:
		return global_position.distance_squared_to(first.global_position) < global_position.distance_squared_to(second.global_position)
	)
	var birds_to_drop: int = mini(2, nearby_birds.size())
	for index in range(birds_to_drop):
		nearby_birds[index].call("fall_after_domain")

func _show_black_hole_effect() -> void:
	if _black_hole_effect == null:
		_black_hole_effect = Node2D.new()
		_black_hole_effect.name = "GojoBlackHole"
		_black_hole_effect.set_script(BLACK_HOLE_EFFECT_SCRIPT)
		_black_hole_effect.position = Vector2(0.0, -28.0)
		add_child(_black_hole_effect)
	_black_hole_effect.show()

func _hide_black_hole_effect() -> void:
	if _black_hole_effect != null:
		_black_hole_effect.hide()

func _spawn_slash_wave(direction: float) -> void:
	var scene_root: Node = get_parent()
	if scene_root == null:
		return
	var slash_wave := Node2D.new()
	slash_wave.name = "TanjiroSlashWave"
	slash_wave.set_script(SLASH_WAVE_SCRIPT)
	slash_wave.global_position = global_position + Vector2(direction * 34.0, -12.0)
	scene_root.add_child(slash_wave)
	slash_wave.call("configure", direction)

func _dash_distance_to_next_sofa(direction: float) -> float:
	var scene_root: Node = get_parent()
	if scene_root == null:
		return DASH_FALLBACK_DISTANCE
	var nearest_distance: float = -1.0
	for child in scene_root.get_children():
		if child is StaticBody2D and child.is_in_group("sofas") and child.visible:
			var forward_distance: float = (child.global_position.x - global_position.x) * direction
			if forward_distance > 80.0 and (nearest_distance < 0.0 or forward_distance < nearest_distance):
				nearest_distance = forward_distance
	if nearest_distance < 0.0:
		return DASH_FALLBACK_DISTANCE
	return clampf(nearest_distance, 90.0, 500.0)
