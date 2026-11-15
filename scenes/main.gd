extends Node2D

const SOFA_SCENE: PackedScene = preload("res://scenes/sofa.tscn")
const COIN_SCENE: PackedScene = preload("res://scenes/coin.tscn")
const BIRD_SCENE: PackedScene = preload("res://scenes/bird.tscn")
const SPIKE_ROW_SCENE: PackedScene = preload("res://scenes/spike_row.tscn")
const STORM_CLOUD_SCRIPT: Script = preload("res://scenes/storm_cloud.gd")
const TANJIRO_SPRITE_FRAMES: SpriteFrames = preload("res://assets/player/tanjiro/tanjiro_frames.tres")
const GOJO_SPRITE_FRAMES: SpriteFrames = preload("res://assets/player/gojo/gojo_frames.tres")
const PLAYER_AIR_SPEED: float = 350.0
const PLAYER_GRAVITY: float = 1000.0
const PLAYER_BOUNCE_VELOCITY: float = 700.0
const MAX_HEARTS: int = 3

@onready var player: CharacterBody2D = $Player
@onready var goal: Area2D = $Goal
@onready var door_sprite: Sprite2D = $Goal/DoorSprite
@onready var door_opening: Polygon2D = $Goal/DoorOpening
@onready var spike_row: Area2D = $SpikeRow
@onready var level_menu: CanvasLayer = $LevelMenu
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var level_label: Label = $HUD/LevelLabel
@onready var coin_label: Label = $HUD/CoinLabel
@onready var dash_plate: Panel = $HUD/DashPlate
@onready var dash_label: Label = $HUD/DashLabel
@onready var hearts_label: Label = $HUD/HeartsLabel
@onready var score_label: Label = $HUD/ScoreLabel
@onready var score_plate: Panel = $HUD/ScorePlate
@onready var hud: CanvasLayer = $HUD
@onready var start_menu: CanvasLayer = $StartMenu
@onready var play_button: Button = $StartMenu/CenterContainer/VBoxContainer/PlayButton
@onready var death_screen: CanvasLayer = $DeathScreen
@onready var death_title: Label = $DeathScreen/CenterContainer/VBoxContainer/Title
@onready var death_message: Label = $DeathScreen/CenterContainer/VBoxContainer/Message
@onready var win_screen: CanvasLayer = $WinScreen
@onready var win_title: Label = $WinScreen/CenterContainer/VBoxContainer/Title
@onready var win_message: Label = $WinScreen/CenterContainer/VBoxContainer/Message
@onready var restart_button: Button = $DeathScreen/CenterContainer/VBoxContainer/RestartButton
@onready var win_restart_button: Button = $WinScreen/CenterContainer/VBoxContainer/RestartButton

var selected_level: int = 1
var coins_collected: int = 0
var coins_available: int = 0
var coin_rng := RandomNumberGenerator.new()
var sofa_flip_rng := RandomNumberGenerator.new()
var respawn_position: Vector2 = Vector2(400, 500)
var hearts_left: int = MAX_HEARTS
var _door_transition_running: bool = false
var selected_theme: int = 1
var selected_character: int = 0
var _penguin_sprite_frames: SpriteFrames
var _menu_penguin: AnimatedSprite2D
var _menu_penguin_idle: Sprite2D
var _menu_penguin_tween: Tween
var _gojo_domain_audio: AudioStreamPlayer
var _theme_music_player: AudioStreamPlayer
var _theme_music_streams: Array[AudioStreamWAV] = []
var _theme_music_tween: Tween
var endless_score: int = 0
var endless_high_score: int = 0
var _endless_last_platform_x: float = 0.0
var _endless_last_platform_position: Vector2 = Vector2.ZERO
var _endless_platform_index: int = 0
var _endless_hazard_end_x: float = 7000.0
var _endless_high_score_config := ConfigFile.new()

func _process(_delta: float) -> void:
	if selected_level != 5 or not player.visible or not player.is_physics_processing():
		return
	endless_score = maxi(endless_score, maxi(0, int((player.position.x - 400.0) / 10.0)))
	if endless_score > endless_high_score:
		endless_high_score = endless_score
		_endless_high_score_config.set_value("scores", "level_5_high_score", endless_high_score)
		_endless_high_score_config.save("user://sofa_hop_scores.cfg")
	_update_score_display()
	_extend_endless_level()

func _update_score_display() -> void:
	var current_text := "%05d" % endless_score
	var high_text := "%05d" % endless_high_score
	score_label.text = "SCORE %s   HI %s" % [current_text, high_text]

func _ready() -> void:
	_endless_high_score_config.load("user://sofa_hop_scores.cfg")
	endless_high_score = int(_endless_high_score_config.get_value("scores", "level_5_high_score", 0))
	_update_score_display()
	coin_rng.randomize()
	sofa_flip_rng.randomize()
	_penguin_sprite_frames = $Player/AnimatedSprite2D.sprite_frames
	player.connect("dash_status_changed", _on_dash_status_changed)
	player.connect("gojo_domain_status_changed", _on_gojo_domain_status_changed)
	player.connect("gojo_domain_started", _play_gojo_domain_audio)
	player.died.connect(_on_player_died)
	player.won.connect(_on_player_won)
	player.checkpoint_reached.connect(_on_checkpoint_reached)
	goal.body_entered.connect(_on_goal_body_entered)
	spike_row.body_entered.connect(_on_spike_row_body_entered)
	restart_button.pressed.connect(_on_death_button_pressed)
	win_restart_button.pressed.connect(_on_restart_pressed)
	$WinScreen/CenterContainer/VBoxContainer/MenuButton.pressed.connect(_back_to_level_menu)
	$WinScreen/CenterContainer/VBoxContainer/QuitButton.pressed.connect(_quit_game)
	$LevelMenu/CenterContainer/VBoxContainer/MenuColumns/LevelsColumn/LevelButtonGrid/Level1Button.pressed.connect(_on_level_selected.bind(1))
	$LevelMenu/CenterContainer/VBoxContainer/MenuColumns/LevelsColumn/LevelButtonGrid/Level2Button.pressed.connect(_on_level_selected.bind(2))
	$LevelMenu/CenterContainer/VBoxContainer/MenuColumns/LevelsColumn/LevelButtonGrid/Level3Button.pressed.connect(_on_level_selected.bind(3))
	$LevelMenu/CenterContainer/VBoxContainer/MenuColumns/LevelsColumn/LevelButtonGrid/Level4Button.pressed.connect(_on_level_selected.bind(4))
	$LevelMenu/CenterContainer/VBoxContainer/MenuColumns/LevelsColumn/LevelButtonGrid/Level5Button.pressed.connect(_on_level_selected.bind(5))
	$LevelMenu/CenterContainer/VBoxContainer/MenuColumns/LevelsColumn/LevelButtonGrid/Level6Button.pressed.connect(_on_level_selected.bind(6))
	$LevelMenu/CenterContainer/VBoxContainer/MenuColumns/OptionsColumn/ThemeButtons/LivingRoomButton.pressed.connect(_select_theme.bind(0))
	$LevelMenu/CenterContainer/VBoxContainer/MenuColumns/OptionsColumn/ThemeButtons/RooftopButton.pressed.connect(_select_theme.bind(1))
	$LevelMenu/CenterContainer/VBoxContainer/MenuColumns/OptionsColumn/ThemeButtons/SpaceButton.pressed.connect(_select_theme.bind(2))
	play_button.pressed.connect(_open_level_menu)
	play_button.mouse_entered.connect(_start_menu_penguin_bounce)
	play_button.mouse_exited.connect(_stop_menu_penguin_bounce)
	$LevelMenu/CenterContainer/VBoxContainer/MenuColumns/OptionsColumn/CharacterOptions/PenguinButton.pressed.connect(_select_character.bind(0))
	$LevelMenu/CenterContainer/VBoxContainer/MenuColumns/OptionsColumn/CharacterOptions/TanjiroButton.pressed.connect(_select_character.bind(1))
	$LevelMenu/CenterContainer/VBoxContainer/MenuColumns/OptionsColumn/CharacterOptions/GojoButton.pressed.connect(_select_character.bind(2))
	$PauseMenu/CenterContainer/VBoxContainer/ResumeButton.pressed.connect(_resume_game)
	$PauseMenu/CenterContainer/VBoxContainer/MenuButton.pressed.connect(_back_to_level_menu)
	$PauseMenu/CenterContainer/VBoxContainer/QuitButton.pressed.connect(_quit_game)
	player.hide()
	player.set_physics_process(false)
	start_menu.show()
	level_menu.hide()
	death_screen.hide()
	win_screen.hide()
	pause_menu.hide()
	hud.hide()
	_menu_penguin = AnimatedSprite2D.new()
	_menu_penguin.name = "MenuPenguin"
	_menu_penguin.sprite_frames = TANJIRO_SPRITE_FRAMES
	_menu_penguin.animation = &"idle"
	_menu_penguin.scale = Vector2(0.32, 0.32)
	_menu_penguin.z_index = 10
	_menu_penguin.visible = false
	start_menu.add_child(_menu_penguin)
	_menu_penguin_idle = Sprite2D.new()
	_menu_penguin_idle.name = "MenuPenguinIdle"
	_menu_penguin_idle.texture = TANJIRO_SPRITE_FRAMES.get_frame_texture(&"idle", 0)
	_menu_penguin_idle.scale = Vector2(0.35, 0.35)
	_menu_penguin_idle.z_index = 10
	start_menu.add_child(_menu_penguin_idle)
	_create_gojo_domain_audio()
	_create_theme_music()
	call_deferred("_position_idle_menu_penguin")
	_select_character(0)
	_create_space_stars()
	_apply_theme()
	_play_theme_music()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
		if pause_menu.visible:
			_resume_game()
		elif not start_menu.visible and not level_menu.visible and not death_screen.visible and not win_screen.visible:
			pause_menu.show()
			get_tree().paused = true
		get_viewport().set_input_as_handled()

func _on_level_selected(level_number: int) -> void:
	_stop_gojo_domain_audio()
	selected_level = level_number
	hearts_left = MAX_HEARTS
	_update_hearts_display()
	var platforms: Array[Vector2] = []
	var platform_scale: float = 1.0
	var sofa_motion_amplitude: float = 0.0
	var sofa_motion_speed: float = 0.0
	var finish_position: Vector2 = Vector2(4900, 470)

	match level_number:
		2:
			platform_scale = 0.84
			sofa_motion_amplitude = 32.0
			sofa_motion_speed = 1.6
			platforms = [Vector2(400, 560), Vector2(720, 500), Vector2(1040, 570), Vector2(1360, 480), Vector2(1680, 550), Vector2(2000, 470), Vector2(2320, 560), Vector2(2640, 480), Vector2(2960, 550), Vector2(3280, 460), Vector2(3600, 550), Vector2(3920, 470), Vector2(4240, 560), Vector2(4560, 480), Vector2(4880, 560)]
			finish_position = Vector2(5180, 470)
		3:
			platform_scale = 0.68
			sofa_motion_amplitude = 32.0
			sofa_motion_speed = 1.7
			platforms = [Vector2(400, 560), Vector2(790, 465), Vector2(1180, 560), Vector2(1570, 455), Vector2(1960, 550), Vector2(2350, 460), Vector2(2740, 570), Vector2(3130, 465), Vector2(3520, 560), Vector2(3910, 450), Vector2(4300, 560), Vector2(4690, 460), Vector2(5080, 560), Vector2(5470, 455), Vector2(5860, 550)]
			finish_position = Vector2(6250, 430)
		4:
			platform_scale = 0.58
			sofa_motion_amplitude = 55.0
			sofa_motion_speed = 2.5
			platforms = [Vector2(400, 560), Vector2(830, 470), Vector2(1260, 560), Vector2(1690, 460), Vector2(2120, 550), Vector2(2550, 455), Vector2(2980, 560), Vector2(3410, 460), Vector2(3840, 550), Vector2(4270, 450), Vector2(4700, 560), Vector2(5130, 460), Vector2(5560, 550), Vector2(5990, 450), Vector2(6420, 520)]
			finish_position = Vector2(6740, 430)
		5:
			platform_scale = 0.54
			sofa_motion_amplitude = 48.0
			sofa_motion_speed = 2.2
			platforms = [Vector2(400, 560), Vector2(850, 470), Vector2(1300, 560), Vector2(1750, 455), Vector2(2200, 550), Vector2(2650, 465), Vector2(3100, 560), Vector2(3550, 455), Vector2(4000, 550), Vector2(4450, 460), Vector2(4900, 560), Vector2(5350, 455), Vector2(5800, 550), Vector2(6250, 460), Vector2(6700, 540)]
			finish_position = Vector2(7140, 430)
		6:
			platform_scale = 0.52
			sofa_motion_amplitude = 42.0
			sofa_motion_speed = 2.0
			platforms = [Vector2(400, 560), Vector2(850, 470), Vector2(1300, 555), Vector2(1750, 455), Vector2(2200, 550), Vector2(2650, 465), Vector2(3100, 560), Vector2(3550, 455), Vector2(4000, 550), Vector2(4450, 460), Vector2(4900, 560), Vector2(5350, 455), Vector2(5800, 550), Vector2(6250, 460), Vector2(6700, 540)]
			finish_position = Vector2(7140, 430)

	for child in get_children():
		if child.is_in_group("generated_platforms") or child.is_in_group("generated_coins") or child.is_in_group("generated_birds") or child.is_in_group("generated_storm_clouds") or child.is_in_group("generated_ground") or child.is_in_group("generated_spike_rows"):
			remove_child(child)
			child.queue_free()

	for child in get_children():
		if child is StaticBody2D and child.is_in_group("sofas") and not child.is_in_group("generated_platforms"):
			var sofa_number: int = str(child.name).trim_prefix("Sofa").to_int()
			var should_show_sofa: bool = level_number == 1 and sofa_number <= 15
			child.call("set_art_flipped", sofa_flip_rng.randf() < 0.5)
			child.visible = should_show_sofa
			var shape: CollisionShape2D = child.get_node_or_null("CollisionShape2D")
			if shape != null:
				shape.set_deferred("disabled", not should_show_sofa)

	if level_number > 1:
		for platform_index in range(platforms.size()):
			var platform_position: Vector2 = platforms[platform_index]
			var sofa: StaticBody2D = SOFA_SCENE.instantiate()
			sofa.position = platform_position
			sofa.scale = Vector2.ONE * platform_scale
			if sofa_motion_amplitude > 0.0 and platform_index > 0:
				var phase: float = float(platform_index) * 0.83
				var moves_horizontally: bool = (level_number == 2 and platform_index % 4 == 0) or (level_number == 3 and platform_index % 4 == 1) or (level_number == 4 and platform_index % 3 == 2) or (level_number == 5 and platform_index % 2 == 0) or (level_number == 6 and platform_index % 4 == 0)
				if moves_horizontally:
					var horizontal_amplitude: float = 58.0 if level_number >= 5 else sofa_motion_amplitude
					sofa.call("configure_horizontal_motion", horizontal_amplitude, sofa_motion_speed, phase)
				elif level_number != 2:
					sofa.call("configure_vertical_motion", sofa_motion_amplitude, sofa_motion_speed, phase)
			if level_number == 6 and platform_index % 3 == 2:
				sofa.call("configure_crumbling")
			sofa.add_to_group("generated_platforms")
			add_child(sofa)
			sofa.call("set_art_flipped", sofa_flip_rng.randf() < 0.5)
			_apply_sofa_theme(sofa)

	var coin_platforms: Array[Vector2] = []
	for child in get_children():
		if child is StaticBody2D and child.is_in_group("sofas") and child.visible:
			coin_platforms.append(child.position)
	coin_platforms.append(finish_position)
	_spawn_coins(coin_platforms)
	_spawn_birds(finish_position)

	goal.position = finish_position
	goal.visible = level_number != 5
	goal.set_deferred("monitoring", level_number != 5)
	endless_score = 0
	_endless_last_platform_x = platforms[platforms.size() - 1].x if level_number == 5 else 0.0
	_endless_last_platform_position = platforms[platforms.size() - 1] if level_number == 5 else Vector2.ZERO
	_endless_platform_index = 0
	_endless_hazard_end_x = 7000.0
	_update_score_display()
	_reset_door_appearance()
	respawn_position = Vector2(400, 500)
	player.position = respawn_position
	player.reset_for_level()
	if level_number == 6:
		_spawn_storm_cloud()
	player.show()
	player.set_physics_process(true)
	level_label.text = "LEVEL 5  ∞" if level_number == 5 else "LEVEL %d" % level_number
	score_plate.visible = level_number == 5
	hud.show()
	level_menu.hide()
	death_screen.hide()
	win_screen.hide()
	start_menu.hide()

func _open_level_menu() -> void:
	start_menu.hide()
	level_menu.show()

func _select_character(character_index: int) -> void:
	selected_character = character_index
	dash_plate.hide()
	dash_label.hide()
	var active_frames: SpriteFrames = _penguin_sprite_frames
	if selected_character == 1:
		active_frames = TANJIRO_SPRITE_FRAMES
	elif selected_character == 2:
		active_frames = GOJO_SPRITE_FRAMES
	$Player/AnimatedSprite2D.sprite_frames = active_frames
	$Player/AnimatedSprite2D.play(&"idle")
	player.call("set_dash_enabled", selected_character == 1)
	player.call("set_gojo_domain_enabled", selected_character == 2)
	if _menu_penguin != null:
		_menu_penguin.play(&"idle")
	$LevelMenu/CenterContainer/VBoxContainer/MenuColumns/OptionsColumn/CharacterOptions/PenguinButton.button_pressed = selected_character == 0
	$LevelMenu/CenterContainer/VBoxContainer/MenuColumns/OptionsColumn/CharacterOptions/TanjiroButton.button_pressed = selected_character == 1
	$LevelMenu/CenterContainer/VBoxContainer/MenuColumns/OptionsColumn/CharacterOptions/GojoButton.button_pressed = selected_character == 2

func _on_dash_status_changed(seconds_remaining: float, enabled: bool) -> void:
	if selected_character != 1:
		return
	dash_plate.visible = enabled
	dash_label.visible = enabled
	if not enabled:
		return
	if seconds_remaining > 0.0:
		dash_label.text = "SPACE DASH: %ds" % maxi(1, int(ceil(seconds_remaining)))
	else:
		dash_label.text = "SPACE DASH READY"

func _on_gojo_domain_status_changed(seconds_remaining: float, enabled: bool, active: bool) -> void:
	if selected_character != 2:
		return
	dash_plate.visible = enabled
	dash_label.visible = enabled
	if not enabled:
		return
	if active:
		dash_label.text = "DOMAIN EXPANSION"
	elif seconds_remaining > 0.0:
		dash_label.text = "DOMAIN RECHARGING"
	else:
		dash_label.text = "DOMAIN READY"

func _create_gojo_domain_audio() -> void:
	_gojo_domain_audio = AudioStreamPlayer.new()
	_gojo_domain_audio.name = "GojoDomainAudio"
	_gojo_domain_audio.process_mode = Node.PROCESS_MODE_PAUSABLE
	var audio_path: String = "res://assets/audio/gojo_domain.wav"
	if ResourceLoader.exists(audio_path):
		_gojo_domain_audio.stream = load(audio_path)
	_gojo_domain_audio.finished.connect(_on_gojo_domain_audio_finished)
	add_child(_gojo_domain_audio)
	if _gojo_domain_audio.stream != null:
		player.call("set_gojo_domain_duration", _gojo_domain_audio.stream.get_length())

func _play_gojo_domain_audio() -> void:
	if selected_character == 2 and _gojo_domain_audio.stream != null:
		_gojo_domain_audio.play()

func _stop_gojo_domain_audio() -> void:
	if _gojo_domain_audio != null:
		_gojo_domain_audio.stop()

func _on_gojo_domain_audio_finished() -> void:
	if player.has_method("end_gojo_domain"):
		player.call("end_gojo_domain")

func _start_menu_penguin_bounce() -> void:
	if _menu_penguin == null or _menu_penguin_idle == null:
		return
	if _menu_penguin_tween != null and _menu_penguin_tween.is_running():
		_menu_penguin_tween.kill()
	_position_idle_menu_penguin()
	var landing_position: Vector2 = _menu_penguin_idle.position
	_menu_penguin.position = landing_position + Vector2(0.0, 14.0)
	_menu_penguin_idle.visible = false
	_menu_penguin.visible = true
	_menu_penguin.play(&"jump")
	_menu_penguin_tween = create_tween()
	_menu_penguin_tween.tween_property(_menu_penguin, "position", landing_position, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_menu_penguin_tween.tween_callback(_continue_menu_penguin_bounce.bind(landing_position))

func _continue_menu_penguin_bounce(landing_position: Vector2) -> void:
	if not play_button.is_hovered() or not start_menu.visible:
		return
	_menu_penguin_tween = create_tween().set_loops()
	_menu_penguin_tween.tween_property(_menu_penguin, "position", landing_position + Vector2(0.0, -14.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_menu_penguin_tween.tween_property(_menu_penguin, "position", landing_position, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _stop_menu_penguin_bounce() -> void:
	if _menu_penguin_tween != null and _menu_penguin_tween.is_running():
		_menu_penguin_tween.kill()
	if _menu_penguin != null:
		_menu_penguin.visible = false
		_menu_penguin.play(&"idle")
	if _menu_penguin_idle != null:
		_position_idle_menu_penguin()
		_menu_penguin_idle.visible = start_menu.visible

func _position_idle_menu_penguin() -> void:
	if _menu_penguin_idle == null or not is_instance_valid(play_button):
		return
	var button_rect: Rect2 = play_button.get_global_rect()
	_menu_penguin_idle.position = Vector2(button_rect.position.x + button_rect.size.x * 0.10, button_rect.position.y - button_rect.size.y * 0.40)

func _on_player_died() -> void:
	_stop_gojo_domain_audio()
	death_title.text = "OOPS!"
	death_message.text = "Respawning at your last sofa..."
	restart_button.text = "Respawn Now"
	death_screen.show()
	await get_tree().create_timer(1.2).timeout
	if death_screen.visible:
		_respawn_player()

func _on_checkpoint_reached(sofa_position: Vector2) -> void:
	respawn_position = sofa_position + Vector2(0, -65)

func _respawn_player() -> void:
	hearts_left = maxi(hearts_left - 1, 0)
	_update_hearts_display()
	if hearts_left <= 0:
		death_title.text = "GAME OVER"
		death_message.text = "You ran out of hearts!"
		restart_button.text = "Play Again"
		return
	death_screen.hide()
	player.position = respawn_position
	player.reset_for_level()
	player.set_physics_process(true)

func _on_death_button_pressed() -> void:
	if hearts_left <= 0:
		_on_restart_pressed()
	else:
		_respawn_player()

func _update_hearts_display() -> void:
	hearts_label.text = "LIVES %d / %d" % [hearts_left, MAX_HEARTS]

func _on_player_won() -> void:
	_stop_gojo_domain_audio()
	if _door_transition_running:
		return
	_door_transition_running = true
	player.set_physics_process(false)
	door_opening.visible = true
	door_opening.scale = Vector2(0.05, 0.05)
	door_opening.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(door_opening, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(door_opening, "modulate:a", 1.0, 0.25)
	tween.tween_property(door_sprite, "position", Vector2(0, -112), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_property(player, "position", goal.position + Vector2(0, -75), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(player, "modulate:a", 0.0, 0.55)
	tween.tween_callback(_advance_to_next_level)

func _advance_to_next_level() -> void:
	if selected_level < 6:
		_on_level_selected(selected_level + 1)
	else:
		win_title.text = "YOU WIN!"
		win_message.text = "You finished every level!"
		win_screen.show()

func _reset_door_appearance() -> void:
	_door_transition_running = false
	door_sprite.position = Vector2(0, -102)
	door_sprite.modulate = Color.WHITE
	door_opening.visible = false
	door_opening.scale = Vector2.ONE
	door_opening.modulate = Color.WHITE

func _on_goal_body_entered(body: Node2D) -> void:
	if body == player and selected_level != 5:
		player.finish_level()

func _extend_endless_level() -> void:
	if player.position.x + 1500.0 < _endless_last_platform_x:
		return
	var previous_position := _endless_last_platform_position
	for i in range(5):
		_endless_platform_index += 1
		var gap := coin_rng.randf_range(370.0, 410.0)
		var y := clampf(previous_position.y + coin_rng.randf_range(-75.0, 75.0), 445.0, 565.0)
		var position := Vector2(previous_position.x + gap, y)
		var sofa: StaticBody2D = SOFA_SCENE.instantiate()
		sofa.position = position
		sofa.scale = Vector2.ONE * 0.54
		var phase := float(_endless_platform_index) * 0.83
		if _endless_platform_index % 2 == 0:
			sofa.call("configure_horizontal_motion", 58.0, 2.2, phase)
		else:
			sofa.call("configure_vertical_motion", 38.0, 2.0, phase)
		sofa.add_to_group("generated_platforms")
		add_child(sofa)
		sofa.call("set_art_flipped", sofa_flip_rng.randf() < 0.5)
		_apply_sofa_theme(sofa)
		_spawn_endless_coin(previous_position, position)
		previous_position = position
		_endless_last_platform_x = position.x
		_endless_last_platform_position = position
	_extend_endless_hazards()

func _extend_endless_hazards() -> void:
	while _endless_hazard_end_x < _endless_last_platform_x + 3000.0:
		var segment_start := _endless_hazard_end_x
		var segment_length := 8000.0
		var ground := StaticBody2D.new()
		ground.name = "Ground"
		ground.position = Vector2(segment_start + segment_length * 0.5, 700.0)
		ground.add_to_group("generated_ground")
		var ground_shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(segment_length, 40.0)
		ground_shape.shape = rectangle
		ground.add_child(ground_shape)
		var ground_art := ColorRect.new()
		ground_art.position = Vector2(-segment_length * 0.5, -20.0)
		ground_art.size = Vector2(segment_length, 40.0)
		ground_art.color = Color(0.04, 0.53, 0.0, 1.0)
		ground_art.z_index = -2
		ground.add_child(ground_art)
		add_child(ground)
		var spikes: Area2D = SPIKE_ROW_SCENE.instantiate()
		spikes.position = Vector2(segment_start + segment_length * 0.5, 680.0)
		spikes.add_to_group("generated_spike_rows")
		spikes.body_entered.connect(_on_spike_row_body_entered)
		add_child(spikes)
		_endless_hazard_end_x += segment_length

func _spawn_endless_coin(start: Vector2, finish: Vector2) -> void:
	var coin_x := (start.x + finish.x) * 0.5
	var travel_time := (coin_x - start.x) / PLAYER_AIR_SPEED
	var coin_y := start.y - 46.0 - PLAYER_BOUNCE_VELOCITY * travel_time + 0.5 * PLAYER_GRAVITY * travel_time * travel_time
	var coin: Area2D = COIN_SCENE.instantiate()
	coin.position = Vector2(coin_x, coin_y + coin_rng.randf_range(-18.0, 18.0))
	coin.add_to_group("generated_coins")
	coin.collected.connect(_on_coin_collected)
	add_child(coin)

func _on_spike_row_body_entered(body: Node2D) -> void:
	if body == player:
		player.die()

func _on_bird_body_entered(body: Node2D) -> void:
	if body == player:
		if selected_character == 2 and player.call("is_domain_active"):
			return
		player.call("die")

func _spawn_birds(finish_position: Vector2) -> void:
	var flight_heights: Array[float] = [350.0, 405.0, 325.0, 385.0, 340.0, 420.0]
	var bird_x: float = 900.0
	var bird_index: int = 0
	while bird_x < finish_position.x - 200.0:
		var bird: Area2D = BIRD_SCENE.instantiate()
		var bird_y: float = flight_heights[bird_index % flight_heights.size()]
		bird.call("configure_flight", bird_x, bird_y, 110.0, 1.8 + float(bird_index % 3) * 0.2, float(bird_index) * 0.9)
		bird.add_to_group("generated_birds")
		bird.body_entered.connect(_on_bird_body_entered)
		add_child(bird)
		bird_x += 850.0
		bird_index += 1

func _spawn_storm_cloud() -> void:
	var cloud := Node2D.new()
	cloud.name = "Level6StormCloud"
	cloud.set_script(STORM_CLOUD_SCRIPT)
	cloud.add_to_group("generated_storm_clouds")
	cloud.process_mode = Node.PROCESS_MODE_PAUSABLE
	cloud.position = Vector2(player.position.x + 80.0, 190.0)
	add_child(cloud)
	cloud.call("configure", player)

func _spawn_coins(platform_positions: Array[Vector2]) -> void:
	coins_collected = 0
	coins_available = maxi(platform_positions.size() - 1, 0)
	coin_label.text = "COINS 0" if selected_level == 5 else "COINS 0/%d" % coins_available
	for index in range(coins_available):
		var start: Vector2 = platform_positions[index]
		var finish: Vector2 = platform_positions[index + 1]
		var segment: float = finish.x - start.x
		var coin_x: float = start.x + segment * coin_rng.randf_range(0.42, 0.58)
		var travel_time: float = (coin_x - start.x) / PLAYER_AIR_SPEED
		var flight_height: float = -PLAYER_BOUNCE_VELOCITY * travel_time + 0.5 * PLAYER_GRAVITY * travel_time * travel_time
		var coin_y: float = start.y - 46.0 + flight_height + coin_rng.randf_range(-18.0, 18.0)
		var coin: Area2D = COIN_SCENE.instantiate()
		coin.position = Vector2(coin_x, coin_y)
		coin.add_to_group("generated_coins")
		coin.collected.connect(_on_coin_collected)
		add_child(coin)

func _on_coin_collected() -> void:
	coins_collected += 1
	coin_label.text = "COINS %d" % coins_collected if selected_level == 5 else "COINS %d/%d" % [coins_collected, coins_available]

func _on_restart_pressed() -> void:
	_on_level_selected(selected_level)

func _resume_game() -> void:
	pause_menu.hide()
	get_tree().paused = false

func _back_to_level_menu() -> void:
	_stop_gojo_domain_audio()
	get_tree().paused = false
	pause_menu.hide()
	for child in get_children():
		if child.is_in_group("generated_platforms") or child.is_in_group("generated_coins") or child.is_in_group("generated_birds") or child.is_in_group("generated_storm_clouds"):
			remove_child(child)
			child.queue_free()
	for child in get_children():
		if child is StaticBody2D and child.is_in_group("sofas") and not child.is_in_group("generated_platforms"):
			var sofa_number: int = str(child.name).trim_prefix("Sofa").to_int()
			var should_show_sofa: bool = sofa_number <= 15
			child.visible = should_show_sofa
			var shape: CollisionShape2D = child.get_node_or_null("CollisionShape2D")
			if shape != null:
				shape.set_deferred("disabled", not should_show_sofa)
	goal.position = Vector2(4900, 470)
	_reset_door_appearance()
	player.set_physics_process(false)
	player.position = Vector2(400, 500)
	player.reset_for_level()
	player.hide()
	level_menu.show()
	death_screen.hide()
	win_screen.hide()
	hud.hide()

func _quit_game() -> void:
	get_tree().paused = false
	get_tree().quit()

func _select_theme(theme_index: int) -> void:
	selected_theme = theme_index
	_apply_theme()
	_play_theme_music()

func _create_theme_music() -> void:
	_theme_music_player = AudioStreamPlayer.new()
	_theme_music_player.name = "ThemeMusicPlayer"
	_theme_music_player.volume_db = -17.0
	_theme_music_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_theme_music_player)
	for path in [
		"res://assets/audio/theme_living_room.wav",
		"res://assets/audio/theme_rooftop.wav",
		"res://assets/audio/theme_space.wav"
	]:
		var stream: AudioStreamWAV = load(path) as AudioStreamWAV
		if stream == null:
			continue
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		_theme_music_streams.append(stream)

func _play_theme_music() -> void:
	if _theme_music_player == null or selected_theme >= _theme_music_streams.size():
		return
	var target: AudioStreamWAV = _theme_music_streams[selected_theme]
	if _theme_music_player.stream == target and _theme_music_player.playing:
		return
	if _theme_music_tween != null and _theme_music_tween.is_running():
		_theme_music_tween.kill()
	_theme_music_tween = create_tween()
	if _theme_music_player.playing:
		_theme_music_tween.tween_property(_theme_music_player, "volume_db", -36.0, 0.2)
		_theme_music_tween.tween_callback(_switch_theme_music.bind(target))
		_theme_music_tween.tween_property(_theme_music_player, "volume_db", -17.0, 0.4)
	else:
		_theme_music_player.stream = target
		_theme_music_player.volume_db = -36.0
		_theme_music_player.play()
		_theme_music_tween.tween_property(_theme_music_player, "volume_db", -17.0, 0.7)

func _switch_theme_music(stream: AudioStreamWAV) -> void:
	_theme_music_player.stream = stream
	_theme_music_player.play()
	_theme_music_player.volume_db = -36.0

func _apply_theme() -> void:
	var sky: ColorRect = $Environment/SkyBackground
	var ground: ColorRect = $Ground/ColorRect
	var sun: CanvasItem = $Environment/Sun
	var sky_tint: Color
	var ground_tint: Color
	match selected_theme:
		1:
			sky_tint = Color(0.48, 0.72, 0.91, 1.0)
			ground_tint = Color(0.32, 0.37, 0.47, 1.0)
			sun.visible = true
		2:
			sky_tint = Color(0.035, 0.045, 0.16, 1.0)
			ground_tint = Color(0.19, 0.11, 0.34, 1.0)
			sun.visible = false
		_:
			sky_tint = Color(0.94, 0.76, 0.62, 1.0)
			ground_tint = Color(0.57, 0.22, 0.32, 1.0)
			sun.visible = false
	sky.color = sky_tint
	ground.color = ground_tint
	for child in $Environment.get_children():
		if child is CanvasItem and child.name.begins_with("Cloud"):
			child.visible = selected_theme != 0 and selected_theme != 2
		elif child is CanvasItem and child.is_in_group("space_stars"):
			child.visible = selected_theme == 2
	for child in get_children():
		if child is StaticBody2D and child.is_in_group("sofas"):
			_apply_sofa_theme(child)
	$LevelMenu/CenterContainer/VBoxContainer/MenuColumns/OptionsColumn/ThemeButtons/LivingRoomButton/SelectedCoin.visible = selected_theme == 0
	$LevelMenu/CenterContainer/VBoxContainer/MenuColumns/OptionsColumn/ThemeButtons/RooftopButton/SelectedCoin.visible = selected_theme == 1
	$LevelMenu/CenterContainer/VBoxContainer/MenuColumns/OptionsColumn/ThemeButtons/SpaceButton/SelectedCoin.visible = selected_theme == 2

func _apply_sofa_theme(sofa: StaticBody2D) -> void:
	var tint := Color.WHITE
	if selected_theme == 1:
		tint = Color(0.9, 0.97, 1.0, 1.0)
	elif selected_theme == 2:
		tint = Color(0.82, 0.74, 1.0, 1.0)
	sofa.modulate = tint

func _create_space_stars() -> void:
	var star_rng := RandomNumberGenerator.new()
	star_rng.seed = 58421
	for index in range(64):
		var star := ColorRect.new()
		star.name = "SpaceStar%02d" % index
		star.add_to_group("space_stars")
		star.position = Vector2(star_rng.randf_range(40.0, 7400.0), star_rng.randf_range(25.0, 635.0))
		var star_size := star_rng.randf_range(2.0, 5.0)
		star.size = Vector2(star_size, star_size)
		star.color = Color(0.76, 0.86, 1.0, star_rng.randf_range(0.55, 1.0))
		star.z_index = -90
		$Environment.add_child(star)
