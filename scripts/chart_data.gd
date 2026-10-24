extends RefCounted
class_name ChartData

const FORMAT_VERSION := 1
const DEFAULT_SCROLL_SPEED := 360.0
const MIN_REACTION_SECONDS := 0.8
const COLLISION_WIDTH_PIXELS := 48.0
const PLAYER_WARNING_DISTANCE_PIXELS := 1120.0
const CHART_KEYS: Array[String] = ["format_version", "name", "bpm", "duration_seconds", "beat_times", "events"]

func new_empty(name: String, bpm: float, duration_seconds: float) -> Dictionary:
	var chart := {
		"format_version": FORMAT_VERSION,
		"name": name.strip_edges(),
		"bpm": bpm,
		"duration_seconds": duration_seconds,
		"beat_times": [],
		"events": [],
	}
	if not is_finite(bpm) or bpm <= 0.0 or not is_finite(duration_seconds) or duration_seconds <= 0.0:
		return chart
	var beat_count := ceili(duration_seconds * bpm / 60.0)
	var beat_times: Array[float] = []
	for index in range(beat_count):
		var beat_time := float(index) * 60.0 / bpm
		if beat_time < duration_seconds:
			beat_times.append(beat_time)
	chart["beat_times"] = beat_times
	return chart

func validate(chart: Dictionary, scroll_speed: float = DEFAULT_SCROLL_SPEED) -> Dictionary:
	if not is_finite(scroll_speed) or scroll_speed <= 0.0:
		return _failure("Scroll speed must be a positive finite number.")
	for key in chart.keys():
		if not (key is String) or key not in CHART_KEYS:
			return _failure("Chart contains an unsupported field: %s." % String(key))
	for key in CHART_KEYS:
		if not chart.has(key):
			return _failure("Chart is missing required field: %s." % key)
	if not _is_integer(chart.format_version) or int(chart.format_version) != FORMAT_VERSION:
		return _failure("Chart format version is not supported.")
	if typeof(chart.name) != TYPE_STRING or String(chart.name).strip_edges().is_empty():
		return _failure("Chart name must not be empty.")
	if not _is_positive_number(chart.bpm) or not _is_positive_number(chart.duration_seconds):
		return _failure("Chart BPM and duration must be positive finite numbers.")
	if not (chart.beat_times is Array) or chart.beat_times.is_empty():
		return _failure("Chart must contain at least one beat time.")
	var beat_times: Array[float] = []
	var previous_time := -INF
	for raw_time in chart.beat_times:
		if not _is_number(raw_time):
			return _failure("Beat times must be finite numbers.")
		var beat_time := float(raw_time)
		if beat_time < 0.0 or beat_time >= float(chart.duration_seconds) or beat_time <= previous_time:
			return _failure("Beat times must be ordered, unique, and within the chart duration.")
		beat_times.append(beat_time)
		previous_time = beat_time
	if not (chart.events is Array):
		return _failure("Chart events must be an array.")
	var events: Array[Dictionary] = []
	var previous_index := -1
	var previous_target_time := -INF
	var minimum_target_gap := MIN_REACTION_SECONDS + COLLISION_WIDTH_PIXELS / scroll_speed
	var warning_time := PLAYER_WARNING_DISTANCE_PIXELS / scroll_speed
	for raw_event in chart.events:
		if not (raw_event is Dictionary):
			return _failure("Each chart event must be an object.")
		for event_key in raw_event.keys():
			if event_key not in ["beat_index", "kind"]:
				return _failure("Chart event contains an unsupported field.")
		if not raw_event.has("beat_index") or not _is_integer(raw_event.beat_index):
			return _failure("Each chart event needs an integer beat index.")
		if not raw_event.has("kind") or typeof(raw_event.kind) not in [TYPE_STRING, TYPE_STRING_NAME]:
			return _failure("Each chart event needs a supported obstacle kind.")
		var beat_index := int(raw_event.beat_index)
		var kind_text := String(raw_event.kind)
		if beat_index <= previous_index or beat_index < 0 or beat_index >= beat_times.size():
			return _failure("Event beat indices must be unique, ordered, and inside the beat grid.")
		if kind_text not in ["spike", "block"]:
			return _failure("Obstacle kind must be spike or block.")
		var target_time := beat_times[beat_index]
		if target_time < warning_time:
			return _failure("An obstacle must leave at least %.2f seconds of spawn warning." % warning_time)
		if previous_index >= 0 and target_time - previous_target_time < minimum_target_gap:
			return _failure("Obstacles need at least %.2f seconds between target times." % minimum_target_gap)
		events.append({"beat_index": beat_index, "kind": StringName(kind_text)})
		previous_index = beat_index
		previous_target_time = target_time
	var normalized := {
		"format_version": FORMAT_VERSION,
		"name": String(chart.name).strip_edges(),
		"bpm": float(chart.bpm),
		"duration_seconds": float(chart.duration_seconds),
		"beat_times": beat_times,
		"events": events,
	}
	return {"status": &"ok", "reason": "", "chart": normalized}

func parse_json(text: String, scroll_speed: float = DEFAULT_SCROLL_SPEED) -> Dictionary:
	var parser := JSON.new()
	var parse_error: Error = parser.parse(text)
	if parse_error != OK:
		return _failure("Chart JSON is invalid at line %d: %s" % [parser.get_error_line(), parser.get_error_message()])
	var parsed: Variant = parser.data
	if not (parsed is Dictionary):
		return _failure("Chart file does not contain a valid JSON object.")
	return validate(parsed, scroll_speed)

func serialize(chart: Dictionary, scroll_speed: float = DEFAULT_SCROLL_SPEED) -> Dictionary:
	var validated := validate(chart, scroll_speed)
	if validated.get("status") != &"ok":
		return validated
	var json_chart: Dictionary = validated.chart.duplicate(true)
	var json_events: Array[Dictionary] = []
	for event in json_chart.events:
		json_events.append({"beat_index": int(event.beat_index), "kind": String(event.kind)})
	json_chart["events"] = json_events
	return {"status": &"ok", "reason": "", "text": JSON.stringify(json_chart, "\t")}

func load_file(path: String, scroll_speed: float = DEFAULT_SCROLL_SPEED) -> Dictionary:
	if path.strip_edges().is_empty():
		return _failure("Chart path is empty.")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("Could not open chart file: %s." % FileAccess.get_open_error())
	var contents := file.get_as_text()
	file.close()
	return parse_json(contents, scroll_speed)

func save_file(path: String, chart: Dictionary, scroll_speed: float = DEFAULT_SCROLL_SPEED) -> Dictionary:
	if path.strip_edges().is_empty():
		return _failure("Chart path is empty.")
	var encoded := serialize(chart, scroll_speed)
	if encoded.get("status") != &"ok":
		return encoded
	var absolute_path := ProjectSettings.globalize_path(path)
	var parent_path := absolute_path.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(parent_path)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return _failure("Could not create chart folder: %s." % error_string(directory_error))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _failure("Could not save chart file: %s." % FileAccess.get_open_error())
	file.store_string(encoded.text)
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return _failure("Could not finish writing chart file: %s." % error_string(write_error))
	return {"status": &"ok", "reason": "", "path": path}

func from_gameplay(gameplay_chart: Dictionary, name: String) -> Dictionary:
	return {
		"format_version": FORMAT_VERSION,
		"name": name.strip_edges(),
		"bpm": gameplay_chart.get("bpm", 0.0),
		"duration_seconds": gameplay_chart.get("duration_seconds", 0.0),
		"beat_times": gameplay_chart.get("beat_times", []).duplicate(true),
		"events": gameplay_chart.get("events", []).duplicate(true),
	}

func to_gameplay(chart: Dictionary, scroll_speed: float = DEFAULT_SCROLL_SPEED) -> Dictionary:
	var validated := validate(chart, scroll_speed)
	if validated.get("status") != &"ok":
		return validated
	if validated.chart.events.is_empty():
		return _failure("Add at least one obstacle before playing this chart.")
	return {
		"status": &"ok",
		"reason": "",
		"source": &"custom",
		"seed": 0,
		"difficulty": &"custom",
		"bpm": validated.chart.bpm,
		"duration_seconds": validated.chart.duration_seconds,
		"beat_times": validated.chart.beat_times.duplicate(),
		"events": validated.chart.events.duplicate(true),
	}

func _is_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))

func _is_positive_number(value: Variant) -> bool:
	return _is_number(value) and float(value) > 0.0

func _is_integer(value: Variant) -> bool:
	return _is_number(value) and floorf(float(value)) == float(value)

func _failure(reason: String) -> Dictionary:
	return {"status": &"failed", "reason": reason, "chart": {}}
