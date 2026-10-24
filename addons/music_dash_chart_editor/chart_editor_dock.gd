extends VBoxContainer
class_name MusicDashChartEditorDock

const ChartDataScript = preload("res://scripts/chart_data.gd")

var _chart_data: RefCounted = ChartDataScript.new()
var _chart: Dictionary = {}
var _name_edit: LineEdit
var _bpm_input: SpinBox
var _duration_input: SpinBox
var _beat_input: SpinBox
var _kind_selector: OptionButton
var _event_list: ItemList
var _status_label: Label
var _open_dialog: FileDialog
var _save_dialog: FileDialog

func _ready() -> void:
	var charts_directory := ProjectSettings.globalize_path("res://charts")
	DirAccess.make_dir_recursive_absolute(charts_directory)
	_build_interface()
	create_empty_chart("new_chart", 120.0, 30.0)

func configure_chart(chart: Dictionary) -> bool:
	var validated: Dictionary = _chart_data.validate(chart)
	if validated.get("status") != &"ok":
		_set_status(String(validated.get("reason", "Chart is invalid.")))
		return false
	_chart = validated.chart
	_refresh()
	_set_status("Chart loaded.")
	return true

func create_empty_chart(name: String, bpm: float, duration_seconds: float) -> bool:
	var candidate: Dictionary = _chart_data.new_empty(name, bpm, duration_seconds)
	var validated: Dictionary = _chart_data.validate(candidate)
	if validated.get("status") != &"ok":
		_set_status(String(validated.get("reason", "Chart settings are invalid.")))
		return false
	_chart = validated.chart
	_refresh()
	_set_status("Empty chart grid created.")
	return true

func current_chart() -> Dictionary:
	return _chart.duplicate(true)

func set_beat_event(beat_index: int, kind: StringName) -> bool:
	if kind not in ChartDataScript.OBSTACLE_KINDS:
		_set_status("Choose spike, block, saw, or crystal.")
		return false
	if beat_index < 0 or beat_index >= _chart.get("beat_times", []).size():
		_set_status("Choose a beat inside the chart grid.")
		return false
	var candidate := current_chart()
	var event_index := _event_index_for_beat(candidate.events, beat_index)
	var event := {"beat_index": beat_index, "kind": kind}
	if event_index >= 0:
		candidate.events[event_index] = event
	else:
		candidate.events.append(event)
	candidate.events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.beat_index) < int(b.beat_index))
	return _commit_candidate(candidate)

func remove_beat_event(beat_index: int) -> bool:
	var candidate := current_chart()
	var event_index := _event_index_for_beat(candidate.events, beat_index)
	if event_index < 0:
		_set_status("There is no obstacle on that beat.")
		return false
	candidate.events.remove_at(event_index)
	return _commit_candidate(candidate)

func load_chart_from_path(path: String) -> bool:
	if path.get_extension().to_lower() != "json":
		_set_status("Choose a .json chart file.")
		return false
	var result: Dictionary = _chart_data.load_file(path)
	if result.get("status") != &"ok":
		_set_status(String(result.get("reason", "Chart could not be loaded.")))
		return false
	return configure_chart(result.chart)

func save_chart_to_path(path: String) -> bool:
	if path.get_extension().to_lower() != "json":
		_set_status("Choose a .json file for chart data.")
		return false
	var candidate := current_chart()
	candidate.name = _name_edit.text.strip_edges()
	var validated: Dictionary = _chart_data.validate(candidate)
	if validated.get("status") != &"ok":
		_set_status(String(validated.get("reason", "Chart settings are invalid.")))
		return false
	var result: Dictionary = _chart_data.save_file(path, validated.chart)
	if result.get("status") != &"ok":
		_set_status(String(result.get("reason", "Chart could not be saved.")))
		return false
	_chart = validated.chart
	_set_status("Chart saved to %s." % path)
	return true

func _build_interface() -> void:
	name = "MUSIC DASH Charts"
	custom_minimum_size = Vector2(350, 0)
	add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "MUSIC DASH CHART EDITOR"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)

	_name_edit = LineEdit.new()
	_name_edit.name = "ChartName"
	_name_edit.placeholder_text = "Chart name"
	add_child(_name_edit)

	var grid_settings := HBoxContainer.new()
	grid_settings.add_theme_constant_override("separation", 8)
	add_child(grid_settings)
	_bpm_input = _add_spin_box(grid_settings, "BPM", 1.0, 400.0, 1.0, 120.0)
	_duration_input = _add_spin_box(grid_settings, "SECONDS", 1.0, 3600.0, 1.0, 30.0)
	_add_button(grid_settings, "NEW GRID", _on_new_pressed)

	var file_actions := HBoxContainer.new()
	file_actions.add_theme_constant_override("separation", 8)
	add_child(file_actions)
	_add_button(file_actions, "OPEN JSON", _open_chart_dialog)
	_add_button(file_actions, "SAVE JSON", _save_chart_dialog_action)

	var event_controls := HBoxContainer.new()
	event_controls.add_theme_constant_override("separation", 8)
	add_child(event_controls)
	_beat_input = SpinBox.new()
	_beat_input.name = "BeatIndex"
	_beat_input.min_value = 0
	_beat_input.max_value = 0
	_beat_input.step = 1
	_beat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_controls.add_child(_beat_input)
	_kind_selector = OptionButton.new()
	for kind in ChartDataScript.OBSTACLE_KINDS:
		_kind_selector.add_item(String(kind).to_upper())
		_kind_selector.set_item_metadata(_kind_selector.item_count - 1, kind)
	event_controls.add_child(_kind_selector)
	_add_button(event_controls, "SET", _on_set_event_pressed)
	_add_button(event_controls, "REMOVE", _on_remove_event_pressed)

	_event_list = ItemList.new()
	_event_list.name = "Events"
	_event_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_event_list.item_selected.connect(_on_event_selected)
	add_child(_event_list)

	_status_label = Label.new()
	_status_label.name = "Status"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status_label)

	_open_dialog = FileDialog.new()
	_open_dialog.title = "Open Music Dash chart"
	_open_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_open_dialog.use_native_dialog = false
	_open_dialog.filters = PackedStringArray(["*.json ; Music Dash chart (*.json)"])
	_open_dialog.file_selected.connect(load_chart_from_path)
	add_child(_open_dialog)
	_save_dialog = FileDialog.new()
	_save_dialog.title = "Save Music Dash chart"
	_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.use_native_dialog = false
	_save_dialog.filters = PackedStringArray(["*.json ; Music Dash chart (*.json)"])
	_save_dialog.current_dir = ProjectSettings.globalize_path("res://charts")
	_save_dialog.file_selected.connect(_on_save_path_selected)
	add_child(_save_dialog)

func _add_spin_box(parent: Control, prefix: String, minimum: float, maximum: float, step: float, value: float) -> SpinBox:
	var row := VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var label := Label.new()
	label.text = prefix
	row.add_child(label)
	var input := SpinBox.new()
	input.min_value = minimum
	input.max_value = maximum
	input.step = step
	input.value = value
	row.add_child(input)
	return input

func _add_button(parent: Control, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _commit_candidate(candidate: Dictionary) -> bool:
	var validated: Dictionary = _chart_data.validate(candidate)
	if validated.get("status") != &"ok":
		_set_status(String(validated.get("reason", "Chart edit is not fair.")))
		return false
	_chart = validated.chart
	_refresh()
	_set_status("Chart edit applied.")
	return true

func _refresh() -> void:
	if _chart.is_empty() or not is_instance_valid(_name_edit):
		return
	_name_edit.text = String(_chart.get("name", ""))
	_bpm_input.value = float(_chart.get("bpm", 120.0))
	_duration_input.value = float(_chart.get("duration_seconds", 30.0))
	_beat_input.max_value = maxi(0, _chart.get("beat_times", []).size() - 1)
	_event_list.clear()
	for event in _chart.get("events", []):
		_event_list.add_item("Beat %d  ·  %s" % [int(event.beat_index), String(event.kind).to_upper()])

func _event_index_for_beat(events: Array, beat_index: int) -> int:
	for index in range(events.size()):
		if int(events[index].get("beat_index", -1)) == beat_index:
			return index
	return -1

func _on_new_pressed() -> void:
	create_empty_chart(_name_edit.text, _bpm_input.value, _duration_input.value)

func _open_chart_dialog() -> void:
	_open_dialog.current_dir = ProjectSettings.globalize_path("res://charts")
	_open_dialog.popup_centered_ratio(0.75)

func _save_chart_dialog_action() -> void:
	_save_dialog.current_dir = ProjectSettings.globalize_path("res://charts")
	_save_dialog.current_file = _safe_filename(String(_chart.get("name", "music_dash_chart"))) + ".json"
	_save_dialog.popup_centered_ratio(0.75)

func _on_save_path_selected(path: String) -> void:
	if path.get_extension().to_lower() != "json":
		path += ".json"
	save_chart_to_path(path)

func _on_set_event_pressed() -> void:
	var kind := StringName(_kind_selector.get_item_metadata(_kind_selector.selected))
	set_beat_event(int(_beat_input.value), kind)

func _on_remove_event_pressed() -> void:
	remove_beat_event(int(_beat_input.value))

func _on_event_selected(index: int) -> void:
	if index < 0 or index >= _chart.get("events", []).size():
		return
	var event: Dictionary = _chart.events[index]
	_beat_input.value = int(event.beat_index)
	for item_index in range(_kind_selector.item_count):
		if _kind_selector.get_item_metadata(item_index) == event.kind:
			_kind_selector.select(item_index)
			return

func _safe_filename(value: String) -> String:
	var result := value.strip_edges().to_lower().replace(" ", "_")
	for character in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		result = result.replace(character, "")
	return result if not result.is_empty() else "music_dash_chart"

func _set_status(message: String) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = message
