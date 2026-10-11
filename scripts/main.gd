extends Control

const PlayerScene = preload("res://scenes/player.tscn")
const ObstacleScene = preload("res://scenes/obstacle.tscn")
const LevelControllerScript = preload("res://scripts/level_controller.gd")
const AudioConductorScript = preload("res://scripts/audio_conductor.gd")
const MusicAnalyzerScript = preload("res://scripts/music_analyzer.gd")
const ChartGeneratorScript = preload("res://scripts/procedural_chart_generator.gd")
const ObstacleChartScript = preload("res://scripts/obstacle_chart.gd")
const RunScorerScript = preload("res://scripts/run_scorer.gd")
const ProgressionStoreScript = preload("res://scripts/progression_store.gd")

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
var score_label: Label
var combo_label: Label
var accuracy_label: Label
var judgment_label: Label
var progress_bar: ProgressBar
var _overlay: PanelContainer
var _overlay_body_label: Label
var difficulty_selector: OptionButton
var _difficulty_info_label: Label
var _jump_count := 0
var _audio_conductor: Node
var _prepared_chart: Dictionary = {}
var _music_analysis: Dictionary = {}
var _scorer: RefCounted
var _progression_store: RefCounted
var _run_finalized := false
var selected_difficulty: StringName = &"Easy"
@export var progression_profile_path := "user://music_dash_profile.json"

func _ready() -> void:
	_ensure_input_actions()
	_progression_store = ProgressionStoreScript.new()
	_progression_store.load_profile(progression_profile_path)
	selected_difficulty = _progression_store.unlocked_difficulty()
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
	for judgment in _scorer.advance_to(song_position):
		_apply_judgment(judgment)
	_level.advance(song_position, _audio_conductor.audio_offset_seconds, _audio_conductor.bpm)
	if is_instance_valid(_player):
		_player.timing_position = song_position
	if is_instance_valid(_progress_label):
		var duration := float(_prepared_chart.get("duration_seconds", 21.0))
		_progress_label.text = "SYNCED AUDIO  •  %d BPM     %02d:%02d / %02d:%02d" % [int(_audio_conductor.bpm), int(_level.elapsed) / 60, int(_level.elapsed) % 60, int(duration) / 60, int(duration) % 60]
	if is_instance_valid(progress_bar):
		progress_bar.max_value = maxf(0.1, float(_prepared_chart.get("duration_seconds", 21.0)))
		progress_bar.value = clampf(song_position, 0.0, progress_bar.max_value)
	_update_hud_stats()

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
	column.position = Vector2(-300, -240)
	column.size = Vector2(600, 480)
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

	_difficulty_info_label = Label.new()
	_difficulty_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_difficulty_info_label.add_theme_color_override("font_color", MUTED)
	_difficulty_info_label.add_theme_font_size_override("font_size", 14)
	column.add_child(_difficulty_info_label)

	difficulty_selector = OptionButton.new()
	difficulty_selector.custom_minimum_size = Vector2(260, 42)
	difficulty_selector.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var difficulties: Array[StringName] = ProgressionStoreScript.DIFFICULTIES
	for index in range(difficulties.size()):
		difficulty_selector.add_item(String(difficulties[index]))
		difficulty_selector.set_item_disabled(index, not _progression_store.is_unlocked(difficulties[index]))
	difficulty_selector.select(difficulties.find(selected_difficulty))
	difficulty_selector.item_selected.connect(_on_difficulty_selected)
	column.add_child(difficulty_selector)
	_update_difficulty_info()

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
	if not _progression_store.is_unlocked(selected_difficulty):
		_build_menu()
		return
	_prepare_chart()
	_audio_conductor.bpm = float(_prepared_chart.bpm)
	_level.set_chart(_prepared_chart)
	_scorer = RunScorerScript.new()
	_scorer.configure(_target_times_for_chart(_prepared_chart))
	_clear_screen()
	screen_state = &"playing"
	_audio_conductor.start_from(0.0)
	_jump_count = 0
	_run_finalized = false
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
	if not _prepared_chart.is_empty() and _prepared_chart.get("difficulty", &"") == selected_difficulty:
		return
	if _music_analysis.is_empty():
		var stream: AudioStreamWAV = load("res://assets/audio/music_dash_prototype.wav") as AudioStreamWAV
		_music_analysis = MusicAnalyzerScript.new().analyze(stream)
	_prepared_chart = _chart_for_analysis(_music_analysis, 7341, selected_difficulty)

func _chart_for_analysis(analysis: Dictionary, seed: int, difficulty: StringName = &"Easy") -> Dictionary:
	var generated: Dictionary = ChartGeneratorScript.new().generate(analysis, difficulty, seed, SCROLL_SPEED)
	if generated.status == &"ok" and not generated.events.is_empty():
		generated.source = &"procedural"
		return generated
	return {
		"status": &"ok",
		"source": &"authored",
		"seed": seed,
		"difficulty": difficulty,
		"bpm": ObstacleChartScript.BEATS_PER_MINUTE,
		"duration_seconds": 21.0,
		"beat_times": [],
		"events": ObstacleChartScript.new().events(),
	}

func _target_times_for_chart(chart: Dictionary) -> Array[float]:
	var target_times: Array[float] = []
	var raw_events: Variant = chart.get("events", [])
	if not (raw_events is Array):
		return target_times
	var raw_beat_times: Variant = chart.get("beat_times", [])
	var beat_times: Array = raw_beat_times if raw_beat_times is Array else []
	var bpm := float(chart.get("bpm", 0.0))
	if not is_finite(bpm) or bpm <= 0.0:
		return target_times
	for event in raw_events:
		if not (event is Dictionary):
			continue
		var beat_index := int(event.get("beat_index", -1))
		if beat_index < 0:
			continue
		var target_time := float(beat_times[beat_index]) if beat_index < beat_times.size() else float(beat_index) * 60.0 / bpm
		target_time += _audio_conductor.audio_offset_seconds
		if is_finite(target_time) and target_time >= 0.0:
			target_times.append(target_time)
	return target_times

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

	progress_bar = ProgressBar.new()
	progress_bar.position = Vector2(28, 72)
	progress_bar.size = Vector2(1224, 8)
	progress_bar.show_percentage = false
	progress_bar.max_value = maxf(0.1, float(_prepared_chart.get("duration_seconds", 21.0)))
	_hud_layer.add_child(progress_bar)

	score_label = Label.new()
	score_label.position = Vector2(28, 94)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	score_label.add_theme_font_size_override("font_size", 20)
	_hud_layer.add_child(score_label)

	combo_label = Label.new()
	combo_label.position = Vector2(350, 96)
	combo_label.add_theme_color_override("font_color", ACCENT)
	combo_label.add_theme_font_size_override("font_size", 18)
	_hud_layer.add_child(combo_label)

	accuracy_label = Label.new()
	accuracy_label.position = Vector2(760, 96)
	accuracy_label.add_theme_color_override("font_color", MUTED)
	accuracy_label.add_theme_font_size_override("font_size", 18)
	_hud_layer.add_child(accuracy_label)

	judgment_label = Label.new()
	judgment_label.position = Vector2(28, 164)
	judgment_label.size = Vector2(1224, 54)
	judgment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	judgment_label.add_theme_color_override("font_color", ACCENT)
	judgment_label.add_theme_font_size_override("font_size", 38)
	judgment_label.text = "HIT THE BEAT"
	_hud_layer.add_child(judgment_label)

	_status_label = Label.new()
	_status_label.position = Vector2(28, 138)
	_status_label.add_theme_color_override("font_color", Color.WHITE)
	_status_label.add_theme_font_size_override("font_size", 18)
	_hud_layer.add_child(_status_label)

	var instruction := Label.new()
	instruction.text = "JUMP OVER THE PINK HAZARDS  •  SPACE / UP"
	instruction.position = Vector2(28, 650)
	instruction.add_theme_color_override("font_color", MUTED)
	_hud_layer.add_child(instruction)
	_update_hud_stats()

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

func _on_difficulty_selected(index: int) -> void:
	var difficulties: Array[StringName] = ProgressionStoreScript.DIFFICULTIES
	if index < 0 or index >= difficulties.size() or not _progression_store.is_unlocked(difficulties[index]):
		return
	selected_difficulty = difficulties[index]
	_update_difficulty_info()

func _update_difficulty_info() -> void:
	if not is_instance_valid(_difficulty_info_label):
		return
	_difficulty_info_label.text = "BEST %06d  •  UNLOCKED THROUGH %s" % [int(_progression_store.best_score(selected_difficulty)), String(_progression_store.unlocked_difficulty()).to_upper()]

func _on_player_jumped(position_seconds: float) -> void:
	_jump_count += 1
	for missed_judgment in _scorer.advance_to(position_seconds):
		_apply_judgment(missed_judgment)
	var judgment: Dictionary = _scorer.record_jump(position_seconds)
	if not judgment.is_empty():
		_apply_judgment(judgment)
	if is_instance_valid(_status_label):
		_status_label.text = "JUMP  %02d" % _jump_count

func _apply_judgment(judgment: Dictionary) -> void:
	if is_instance_valid(judgment_label):
		judgment_label.text = String(judgment.judgment).to_upper()
		judgment_label.add_theme_color_override("font_color", ACCENT if judgment.judgment != &"Miss" else Color("ff5c9a"))
	_update_hud_stats()

func _update_hud_stats() -> void:
	if _scorer == null:
		return
	var stats: Dictionary = _scorer.get_summary()
	if is_instance_valid(score_label):
		score_label.text = "SCORE %06d" % int(stats.score)
	if is_instance_valid(combo_label):
		combo_label.text = "COMBO %02d  •  BEST %02d" % [int(stats.combo), int(stats.best_combo)]
	if is_instance_valid(accuracy_label):
		accuracy_label.text = "ACCURACY %05.1f%%" % (float(stats.accuracy) * 100.0)

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
	_show_run_result(false)

func _finish_level() -> void:
	if screen_state != &"playing":
		return
	screen_state = &"results"
	_audio_conductor.stop_song()
	_world.process_mode = Node.PROCESS_MODE_DISABLED
	_show_run_result(true)

func _show_run_result(completed: bool) -> void:
	if _run_finalized:
		return
	_run_finalized = true
	var stats: Dictionary = _scorer.finalize()
	_progression_store.record_run(selected_difficulty, int(stats.score), completed, progression_profile_path)
	var title := "LEVEL CLEAR" if completed else "CRASHED"
	var action := "PLAY AGAIN" if completed else "RESTART"
	var next_line := "UNLOCKED THROUGH %s" % String(_progression_store.unlocked_difficulty()).to_upper() if completed else "TRY THE CHART AGAIN"
	var best_score: int = _progression_store.best_score(selected_difficulty)
	var body := "SCORE %06d  •  BEST %06d\nACCURACY %05.1f%%  •  BEST COMBO %d\nPERFECT %d  GREAT %d  GOOD %d  MISS %d\nDIFFICULTY %s  •  %s" % [int(stats.score), best_score, float(stats.accuracy) * 100.0, int(stats.best_combo), int(stats.perfect), int(stats.great), int(stats.good), int(stats.miss), String(selected_difficulty).to_upper(), next_line]
	_show_overlay(title, body, action, _restart_run)

func _restart_run() -> void:
	_level.reset_level()
	_remove_overlay()
	_start_run()

func _show_overlay(title_text: String, body_text: String, action_text: String, action: Callable) -> void:
	_remove_overlay()
	_overlay = PanelContainer.new()
	_overlay.set_anchors_preset(Control.PRESET_CENTER)
	_overlay.position = Vector2(-250, -195)
	_overlay.size = Vector2(500, 390)
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
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(440, 124)
	body.add_theme_color_override("font_color", MUTED)
	content.add_child(body)
	_overlay_body_label = body
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
	_overlay_body_label = null

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
	score_label = null
	combo_label = null
	accuracy_label = null
	judgment_label = null
	progress_bar = null
	difficulty_selector = null
	_difficulty_info_label = null
	_overlay_body_label = null

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
