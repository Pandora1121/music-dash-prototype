extends Control

const PlayerScene = preload("res://scenes/player.tscn")
const ObstacleScene = preload("res://scenes/obstacle.tscn")
const LevelControllerScript = preload("res://scripts/level_controller.gd")
const AudioConductorScript = preload("res://scripts/audio_conductor.gd")
const MusicAnalyzerScript = preload("res://scripts/music_analyzer.gd")
const ChartGeneratorScript = preload("res://scripts/procedural_chart_generator.gd")
const ObstacleChartScript = preload("res://scripts/obstacle_chart.gd")

const ACCENT := Color("43f5ff")
const MUTED := Color("8a9bbc")
const SCROLL_SPEED := 360.0

var screen_state: StringName = &"menu"
var start_button: Button
var _level: Node
var _world: Node2D
var _player: CharacterBody2D
var _hud_layer: CanvasLayer
var _status_label: Label
var _progress_label: Label
var _overlay: PanelContainer
var _jump_count := 0
var _audio_conductor: Node
var _prepared_chart: Dictionary = {}

func _ready() -> void:
	_ensure_input_actions()
	_audio_conductor = AudioConductorScript.new()
	_audio_conductor.name = "AudioConductor"
	add_child(_audio_conductor)
	_audio_conductor.beat_reached.connect(_on_beat_reached)
	_level = LevelControllerScript.new()
	_level.name = "LevelController"
	add_child(_level)
	_level.obstacle_due.connect(_spawn_obstacle)
	_level.completed.connect(_finish_level)
	_build_menu()

func _process(_delta: float) -> void:
	if screen_state != &"playing":
		return
	var song_position: float = _audio_conductor.song_position()
	_audio_conductor.consume_beats_until(song_position)
	_level.advance(song_position, _audio_conductor.audio_offset_seconds, _audio_conductor.bpm)
	if is_instance_valid(_player):
		_player.timing_position = song_position
	if is_instance_valid(_progress_label):
		_progress_label.text = "SYNCED AUDIO  •  %d BPM     %02d:%02d / 00:21" % [int(_audio_conductor.bpm), int(_level.elapsed) / 60, int(_level.elapsed) % 60]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if screen_state == &"playing":
			_pause_run()
		elif screen_state == &"paused":
			_resume_run()
	elif event.keycode == KEY_ENTER and screen_state in [&"crashed", &"results"]:
		_restart_run()

func _ensure_input_actions() -> void:
	if not InputMap.has_action("jump"):
		InputMap.add_action("jump")
	for key in [KEY_SPACE, KEY_UP]:
		var key_event := InputEventKey.new()
		key_event.keycode = key
		if not InputMap.action_has_event("jump", key_event):
			InputMap.action_add_event("jump", key_event)

func _build_menu() -> void:
	if is_instance_valid(_audio_conductor):
		_audio_conductor.stop_song()
	_clear_screen()
	screen_state = &"menu"
	var backdrop := ColorRect.new()
	backdrop.color = Color("080d20")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.position = Vector2(-300, -180)
	column.size = Vector2(600, 360)
	column.add_theme_constant_override("separation", 18)
	add_child(column)

	var eyebrow := Label.new()
	eyebrow.text = "RHYTHM // ACTION PROTOTYPE"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_color_override("font_color", ACCENT)
	eyebrow.add_theme_font_size_override("font_size", 16)
	column.add_child(eyebrow)

	var title := Label.new()
	title.text = "MUSIC DASH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_font_size_override("font_size", 64)
	column.add_child(title)

	var description := Label.new()
	description.text = "RUN THE BEAT. CLEAR THE LINE.\nDodge a deterministic lane of neon hazards."
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.add_theme_color_override("font_color", MUTED)
	description.add_theme_font_size_override("font_size", 18)
	column.add_child(description)

	start_button = Button.new()
	start_button.text = "START PROTOTYPE"
	start_button.custom_minimum_size = Vector2(240, 58)
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_button.add_theme_color_override("font_color", Color("06111c"))
	start_button.add_theme_stylebox_override("normal", _button_style(ACCENT))
	start_button.add_theme_stylebox_override("hover", _button_style(Color("9afaff")))
	start_button.pressed.connect(_start_run)
	column.add_child(start_button)

	var hint := Label.new()
	hint.text = "SPACE / UP TO JUMP    •    ESC TO PAUSE"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", MUTED)
	hint.add_theme_font_size_override("font_size", 14)
	column.add_child(hint)

func _start_run() -> void:
	_prepare_chart()
	_audio_conductor.bpm = float(_prepared_chart.bpm)
	_level.set_chart(_prepared_chart)
	_clear_screen()
	screen_state = &"playing"
	_audio_conductor.start_from(0.0)
	_jump_count = 0
	_world = Node2D.new()
	_world.set_script(load("res://scripts/game_world.gd"))
	_world.name = "GameWorld"
	add_child(_world)

	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(640, 625)
	_world.add_child(floor_body)
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(1400, 70)
	floor_shape.shape = floor_rect
	floor_body.add_child(floor_shape)

	_player = PlayerScene.instantiate()
	_player.position = Vector2(240, 562)
	_player.crashed.connect(_on_player_crashed, CONNECT_DEFERRED)
	_player.jumped.connect(_on_player_jumped)
	_world.add_child(_player)

	_build_hud()
	_level.begin_level()

func _prepare_chart() -> void:
	if not _prepared_chart.is_empty():
		return
	var stream: AudioStreamWAV = load("res://assets/audio/music_dash_prototype.wav") as AudioStreamWAV
	var analysis: Dictionary = MusicAnalyzerScript.new().analyze(stream)
	_prepared_chart = _chart_for_analysis(analysis, 7341)

func _chart_for_analysis(analysis: Dictionary, seed: int) -> Dictionary:
	var generated: Dictionary = ChartGeneratorScript.new().generate(analysis, &"Normal", seed, SCROLL_SPEED)
	if generated.status == &"ok" and not generated.events.is_empty():
		generated.source = &"procedural"
		return generated
	return {
		"status": &"ok",
		"source": &"authored",
		"seed": seed,
		"difficulty": &"Normal",
		"bpm": ObstacleChartScript.BEATS_PER_MINUTE,
		"duration_seconds": 21.0,
		"beat_times": [],
		"events": ObstacleChartScript.new().events(),
	}

func _spawn_obstacle(event: Dictionary) -> void:
	if not is_instance_valid(_world) or screen_state != &"playing":
		return
	var obstacle: Area2D = ObstacleScene.instantiate()
	obstacle.position = Vector2(1360, 562)
	obstacle.scroll_speed = SCROLL_SPEED
	obstacle.kind = event.kind
	_world.add_child(obstacle)

func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_hud_layer)
	var top := HBoxContainer.new()
	top.position = Vector2(28, 22)
	top.size = Vector2(1224, 54)
	top.add_theme_constant_override("separation", 22)
	_hud_layer.add_child(top)

	var brand := Label.new()
	brand.text = "MUSIC DASH"
	brand.add_theme_color_override("font_color", ACCENT)
	brand.add_theme_font_size_override("font_size", 20)
	top.add_child(brand)

	_progress_label = Label.new()
	_progress_label.text = "SYNCED AUDIO  •  %d BPM     00:00 / 00:21" % int(_audio_conductor.bpm)
	_progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.add_theme_color_override("font_color", MUTED)
	top.add_child(_progress_label)

	var pause_button := Button.new()
	pause_button.text = "PAUSE  [ESC]"
	pause_button.add_theme_color_override("font_color", Color.WHITE)
	pause_button.pressed.connect(_pause_run)
	top.add_child(pause_button)

	_status_label = Label.new()
	_status_label.position = Vector2(28, 92)
	_status_label.add_theme_color_override("font_color", Color.WHITE)
	_status_label.add_theme_font_size_override("font_size", 18)
	_hud_layer.add_child(_status_label)

	var instruction := Label.new()
	instruction.text = "JUMP OVER THE PINK HAZARDS  •  SPACE / UP"
	instruction.position = Vector2(28, 650)
	instruction.add_theme_color_override("font_color", MUTED)
	_hud_layer.add_child(instruction)

func _pause_run() -> void:
	if screen_state != &"playing":
		return
	screen_state = &"paused"
	_audio_conductor.pause_song()
	_world.process_mode = Node.PROCESS_MODE_DISABLED
	_show_overlay("PAUSED", "The chart is frozen. Take a breath.", "RESUME", _resume_run)

func _resume_run() -> void:
	if screen_state != &"paused":
		return
	_remove_overlay()
	_audio_conductor.resume_song()
	_world.process_mode = Node.PROCESS_MODE_INHERIT
	screen_state = &"playing"

func _on_player_jumped(_position_seconds: float) -> void:
	_jump_count += 1
	if is_instance_valid(_status_label):
		_status_label.text = "JUMP  %02d" % _jump_count

func _on_beat_reached(beat_index: int, _song_position: float) -> void:
	if screen_state != &"playing":
		return
	var pulse_strength := 1.0 if beat_index % 4 == 0 else 0.52
	if is_instance_valid(_world):
		_world.on_beat(beat_index)
	if is_instance_valid(_player):
		_player.apply_beat_pulse(pulse_strength)

func _on_player_crashed() -> void:
	if screen_state != &"playing":
		return
	screen_state = &"crashed"
	_audio_conductor.stop_song()
	_level.reset_level()
	_world.process_mode = Node.PROCESS_MODE_DISABLED
	_show_overlay("CRASHED", "You cleared %02d jumps. Try the pattern again." % _jump_count, "RESTART", _restart_run)

func _finish_level() -> void:
	if screen_state != &"playing":
		return
	screen_state = &"results"
	_audio_conductor.stop_song()
	_world.process_mode = Node.PROCESS_MODE_DISABLED
	_show_overlay("LEVEL CLEAR", "The first chart is complete.", "PLAY AGAIN", _restart_run)

func _restart_run() -> void:
	_level.reset_level()
	_remove_overlay()
	_start_run()

func _show_overlay(title_text: String, body_text: String, action_text: String, action: Callable) -> void:
	_remove_overlay()
	_overlay = PanelContainer.new()
	_overlay.set_anchors_preset(Control.PRESET_CENTER)
	_overlay.position = Vector2(-210, -150)
	_overlay.size = Vector2(420, 300)
	_overlay.add_theme_stylebox_override("panel", _panel_style())
	_hud_layer.add_child(_overlay)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 16)
	_overlay.add_child(content)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", ACCENT)
	title.add_theme_font_size_override("font_size", 34)
	content.add_child(title)
	var body := Label.new()
	body.text = body_text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_color_override("font_color", MUTED)
	content.add_child(body)
	var action_button := Button.new()
	action_button.text = action_text
	action_button.custom_minimum_size = Vector2(200, 52)
	action_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	action_button.add_theme_color_override("font_color", Color("06111c"))
	action_button.add_theme_stylebox_override("normal", _button_style(ACCENT))
	action_button.pressed.connect(action)
	content.add_child(action_button)
	if title_text != "PAUSED":
		var menu_button := Button.new()
		menu_button.text = "MAIN MENU"
		menu_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		menu_button.pressed.connect(_build_menu)
		content.add_child(menu_button)

func _remove_overlay() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null

func _clear_screen() -> void:
	for child in get_children():
		if child != _level and child != _audio_conductor:
			child.queue_free()
	_world = null
	_player = null
	_hud_layer = null
	_overlay = null
	_status_label = null
	_progress_label = null

func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 28
	style.content_margin_right = 28
	return style

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111a37")
	style.border_color = Color(0.26, 0.91, 1.0, 0.56)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	return style
