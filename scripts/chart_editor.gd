extends Control
class_name MusicDashChartEditor

signal load_requested
signal save_requested(chart: Dictionary)
signal play_requested(chart: Dictionary)
signal back_requested(chart: Dictionary)

const ChartDataScript = preload("res://scripts/chart_data.gd")
const ACCENT := Color("43f5ff")
const MUTED := Color("8a9bbc")

var _chart_data: RefCounted = ChartDataScript.new()
var _chart: Dictionary = {}
var _track_name := ""
var _scroll_speed := ChartDataScript.DEFAULT_SCROLL_SPEED
var _beat_grid: GridContainer
var _track_label: Label
var _status_label: Label
var _play_button: Button

func _ready() -> void:
	_build_interface()
	_refresh()

func configure(chart: Dictionary, track_name: String, scroll_speed: float = ChartDataScript.DEFAULT_SCROLL_SPEED) -> void:
	_scroll_speed = scroll_speed if is_finite(scroll_speed) and scroll_speed > 0.0 else ChartDataScript.DEFAULT_SCROLL_SPEED
	var validated: Dictionary = _chart_data.validate(chart, _scroll_speed)
	if validated.get("status") != &"ok":
		_set_status(String(validated.get("reason", "Chart is invalid.")))
		return
	_chart = validated.chart
	_track_name = track_name
	if is_node_ready():
		_refresh()

func current_chart() -> Dictionary:
	return _chart.duplicate(true)

func cycle_beat(beat_index: int) -> bool:
	if beat_index < 0 or beat_index >= _chart.get("beat_times", []).size():
		return false
	var candidate := current_chart()
	var event_index := _event_index_for_beat(candidate.events, beat_index)
	if event_index < 0:
		candidate.events.append({"beat_index": beat_index, "kind": ChartDataScript.OBSTACLE_KINDS[0]})
		candidate.events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.beat_index) < int(b.beat_index))
	else:
		var current_kind := StringName(candidate.events[event_index].kind)
		var kind_index := ChartDataScript.OBSTACLE_KINDS.find(current_kind)
		if kind_index >= ChartDataScript.OBSTACLE_KINDS.size() - 1:
			candidate.events.remove_at(event_index)
		else:
			candidate.events[event_index].kind = ChartDataScript.OBSTACLE_KINDS[kind_index + 1]
	var validated: Dictionary = _chart_data.validate(candidate, _scroll_speed)
	if validated.get("status") != &"ok":
		_set_status(String(validated.get("reason", "Chart edit is not valid.")))
		return false
	_chart = validated.chart
	_set_status("")
	_refresh()
	return true

func clear_chart() -> bool:
	var candidate := current_chart()
	candidate["events"] = []
	var validated: Dictionary = _chart_data.validate(candidate, _scroll_speed)
	if validated.get("status") != &"ok":
		_set_status(String(validated.get("reason", "Chart could not be cleared.")))
		return false
	_chart = validated.chart
	_set_status("")
	_refresh()
	return true

func load_chart() -> void:
	load_requested.emit()

func apply_loaded_chart(chart: Dictionary) -> bool:
	var validated: Dictionary = _chart_data.validate(chart, _scroll_speed)
	if validated.get("status") != &"ok":
		_set_status(String(validated.get("reason", "Chart file is invalid.")))
		return false
	_chart = validated.chart
	_set_status("")
	_refresh()
	return true

func save_chart() -> bool:
	var validated: Dictionary = _chart_data.validate(_chart, _scroll_speed)
	if validated.get("status") != &"ok":
		_set_status(String(validated.get("reason", "Chart is invalid.")))
		return false
	save_requested.emit(validated.chart)
	_set_status("Chart is ready to save.")
	return true

func play_chart() -> bool:
	var gameplay_chart: Dictionary = _chart_data.to_gameplay(_chart, _scroll_speed)
	if gameplay_chart.get("status") != &"ok":
		_set_status(String(gameplay_chart.get("reason", "Add an obstacle before playing.")))
		_refresh_controls()
		return false
	play_requested.emit(gameplay_chart)
	return true

func back() -> void:
	back_requested.emit(current_chart())

func set_status_message(message: String) -> void:
	_set_status(message)

func _build_interface() -> void:
	var content := VBoxContainer.new()
	content.name = "EditorContent"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 28.0
	content.offset_top = 24.0
	content.offset_right = -28.0
	content.offset_bottom = -24.0
	content.add_theme_constant_override("separation", 12)
	add_child(content)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 18)
	content.add_child(header)
	var title := Label.new()
	title.text = "LEVEL EDITOR"
	title.add_theme_color_override("font_color", ACCENT)
	title.add_theme_font_size_override("font_size", 28)
	header.add_child(title)
	_track_label = Label.new()
	_track_label.name = "TrackName"
	_track_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_track_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_track_label.add_theme_color_override("font_color", MUTED)
	header.add_child(_track_label)

	var info := Label.new()
	info.text = "Click a beat to cycle EMPTY → SPIKE → BLOCK → SAW → CRYSTAL → EMPTY. Obstacle spacing is checked as you edit."
	info.add_theme_color_override("font_color", MUTED)
	content.add_child(info)

	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("separation", 10)
	content.add_child(actions)
	_add_action(actions, "BackButton", "BACK", back)
	_add_action(actions, "LoadButton", "LOAD CHART", load_chart)
	_add_action(actions, "ClearButton", "CLEAR", clear_chart)
	_add_action(actions, "SaveButton", "SAVE CHART", save_chart)
	_play_button = _add_action(actions, "PlayButton", "PLAY CHART", play_chart)

	_status_label = Label.new()
	_status_label.name = "Status"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", Color("ff789f"))
	content.add_child(_status_label)

	var timeline := ScrollContainer.new()
	timeline.name = "Timeline"
	timeline.size_flags_vertical = Control.SIZE_EXPAND_FILL
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(timeline)
	_beat_grid = GridContainer.new()
	_beat_grid.name = "BeatGrid"
	_beat_grid.columns = 8
	_beat_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_beat_grid.add_theme_constant_override("h_separation", 8)
	_beat_grid.add_theme_constant_override("v_separation", 8)
	timeline.add_child(_beat_grid)

func _add_action(parent: HBoxContainer, node_name: String, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = caption
	button.custom_minimum_size = Vector2(142, 44)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _refresh() -> void:
	if not is_instance_valid(_beat_grid):
		return
	_track_label.text = _track_name
	for child in _beat_grid.get_children():
		child.queue_free()
	var beat_times: Array = _chart.get("beat_times", [])
	for beat_index in range(beat_times.size()):
		var event_index := _event_index_for_beat(_chart.get("events", []), beat_index)
		var kind := "EMPTY" if event_index < 0 else String(_chart.events[event_index].kind).to_upper()
		var beat := Button.new()
		beat.custom_minimum_size = Vector2(92, 62)
		beat.text = "%03d\n%s" % [beat_index, kind]
		beat.tooltip_text = "%.3f seconds" % float(beat_times[beat_index])
		beat.add_theme_color_override("font_color", Color.WHITE if event_index < 0 else ACCENT)
		beat.pressed.connect(cycle_beat.bind(beat_index))
		_beat_grid.add_child(beat)
	_refresh_controls()

func _refresh_controls() -> void:
	if not is_instance_valid(_play_button):
		return
	_play_button.disabled = _chart.is_empty() or _chart.get("events", []).is_empty() or _chart_data.to_gameplay(_chart).get("status") != &"ok"

func _event_index_for_beat(events: Array, beat_index: int) -> int:
	for index in range(events.size()):
		if int(events[index].get("beat_index", -1)) == beat_index:
			return index
	return -1

func _set_status(message: String) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = message
