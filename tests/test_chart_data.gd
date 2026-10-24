extends SceneTree

const ChartDataScript = preload("res://scripts/chart_data.gd")
const TEST_DIR := "user://chart_data_tests"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	_test_empty_chart_and_round_trip()
	_test_gameplay_conversion()
	_test_rejects_invalid_json_and_schema()
	_test_rejects_invalid_beats_and_events()
	_test_rejects_unfair_events()
	_test_file_round_trip_and_missing_file()
	_test_empty_chart_is_valid_but_not_playable()
	print("PASS: chart data")
	quit()

func _test_empty_chart_and_round_trip() -> void:
	var data: RefCounted = ChartDataScript.new()
	var chart: Dictionary = data.new_empty("test track", 120.0, 10.0)
	assert(chart.format_version == 1 and chart.name == "test track", "new chart should carry the schema version and name")
	assert(chart.beat_times.size() == 20 and is_equal_approx(chart.beat_times[1], 0.5), "empty chart should create an evenly spaced beat grid below its duration")
	chart.events = [
		{"beat_index": 8, "kind": &"spike"},
		{"beat_index": 10, "kind": &"block"},
	]
	var encoded: Dictionary = data.serialize(chart)
	assert(encoded.get("status") == &"ok", "valid chart should serialize")
	var decoded: Dictionary = data.parse_json(encoded.get("text", ""))
	assert(decoded.get("status") == &"ok", "serialized chart should parse")
	assert(decoded.chart.beat_times == chart.beat_times, "round trip should preserve analyzed beat times")
	assert(decoded.chart.events == chart.events, "round trip should preserve event indices and kinds")
	assert(not encoded.text.contains("D:/") and not encoded.text.contains("C:/"), "chart JSON should not contain an absolute audio path")

func _test_gameplay_conversion() -> void:
	var data: RefCounted = ChartDataScript.new()
	var gameplay := {
		"status": &"ok",
		"source": &"procedural",
		"seed": 1234,
		"difficulty": &"Normal",
		"bpm": 120.0,
		"duration_seconds": 10.0,
		"beat_times": _beat_times(20),
		"events": [{"beat_index": 8, "kind": &"block"}, {"beat_index": 10, "kind": &"spike"}],
	}
	var schema_chart: Dictionary = data.from_gameplay(gameplay, "Edited track")
	assert(not schema_chart.has("seed") and not schema_chart.has("difficulty") and not schema_chart.has("source"), "saved format should not persist run-only values")
	var converted: Dictionary = data.to_gameplay(schema_chart)
	assert(converted.get("status") == &"ok", "valid non-empty schema chart should convert for gameplay")
	assert(converted.get("bpm") == gameplay.bpm and converted.get("events") == gameplay.events, "gameplay conversion should retain timing and obstacle events")

func _test_rejects_invalid_json_and_schema() -> void:
	var data: RefCounted = ChartDataScript.new()
	assert(data.parse_json("{broken").get("status") == &"failed", "invalid JSON should fail")
	var unknown_version := _valid_chart()
	unknown_version.format_version = 99
	assert(data.validate(unknown_version).get("status") == &"failed", "unknown format version should fail")
	var bad_bpm := _valid_chart()
	bad_bpm.bpm = "120"
	assert(data.validate(bad_bpm).get("status") == &"failed", "wrong field types should fail")
	var fractional_version := _valid_chart()
	fractional_version.format_version = 1.5
	assert(data.validate(fractional_version).get("status") == &"failed", "fractional versions should fail")
	var audio_path := _valid_chart()
	audio_path.audio_path = "D:/private/song.wav"
	assert(data.validate(audio_path).get("status") == &"failed", "schema should reject persisted audio paths")

func _test_rejects_invalid_beats_and_events() -> void:
	var data: RefCounted = ChartDataScript.new()
	var unordered := _valid_chart()
	unordered.beat_times = [0.0, 0.5, 0.4]
	assert(data.validate(unordered).get("status") == &"failed", "unordered beats should fail")
	var non_finite := _valid_chart()
	non_finite.beat_times[2] = NAN
	assert(data.validate(non_finite).get("status") == &"failed", "non-finite beats should fail")
	var out_of_duration := _valid_chart()
	out_of_duration.beat_times[2] = 10.0
	assert(data.validate(out_of_duration).get("status") == &"failed", "beats must be before chart duration")
	var duplicate := _valid_chart()
	duplicate.events = [{"beat_index": 8, "kind": &"spike"}, {"beat_index": 8, "kind": &"block"}]
	assert(data.validate(duplicate).get("status") == &"failed", "duplicate event indices should fail")
	var unsupported_kind := _valid_chart()
	unsupported_kind.events = [{"beat_index": 8, "kind": &"laser"}]
	assert(data.validate(unsupported_kind).get("status") == &"failed", "unsupported obstacle kinds should fail")
	var out_of_range := _valid_chart()
	out_of_range.events = [{"beat_index": 20, "kind": &"spike"}]
	assert(data.validate(out_of_range).get("status") == &"failed", "event indices outside the beat grid should fail")
	var fractional_index := _valid_chart()
	fractional_index.events = [{"beat_index": 8.5, "kind": &"spike"}]
	assert(data.validate(fractional_index).get("status") == &"failed", "fractional beat indices should fail")

func _test_rejects_unfair_events() -> void:
	var data: RefCounted = ChartDataScript.new()
	var early := _valid_chart()
	early.events = [{"beat_index": 5, "kind": &"spike"}]
	assert(data.validate(early).get("status") == &"failed", "first obstacle must leave enough spawn warning time")
	var too_close := _valid_chart()
	too_close.events = [{"beat_index": 8, "kind": &"spike"}, {"beat_index": 9, "kind": &"block"}]
	assert(data.validate(too_close).get("status") == &"failed", "consecutive obstacles must preserve minimum reaction time")

func _test_file_round_trip_and_missing_file() -> void:
	var data: RefCounted = ChartDataScript.new()
	var chart := _valid_chart()
	var path := TEST_DIR + "/saved_chart.json"
	var saved: Dictionary = data.save_file(path, chart)
	assert(saved.get("status") == &"ok", "valid chart should save to a local JSON file")
	var loaded: Dictionary = data.load_file(path)
	assert(loaded.get("status") == &"ok" and loaded.chart.events == chart.events, "saved chart should load with its events")
	var missing: Dictionary = data.load_file(TEST_DIR + "/missing.json")
	assert(missing.get("status") == &"failed" and not String(missing.get("reason", "")).is_empty(), "missing file should report a useful error")

func _test_empty_chart_is_valid_but_not_playable() -> void:
	var data: RefCounted = ChartDataScript.new()
	var empty := _valid_chart()
	empty.events = []
	assert(data.validate(empty).get("status") == &"ok", "empty chart should be valid while editing")
	assert(data.serialize(empty).get("status") == &"ok", "empty chart should be saveable")
	assert(data.to_gameplay(empty).get("status") == &"failed", "empty chart should not start gameplay")

func _valid_chart() -> Dictionary:
	return {
		"format_version": 1,
		"name": "test track",
		"bpm": 120.0,
		"duration_seconds": 10.0,
		"beat_times": _beat_times(20),
		"events": [{"beat_index": 8, "kind": &"spike"}, {"beat_index": 10, "kind": &"block"}],
	}

func _beat_times(count: int) -> Array[float]:
	var result: Array[float] = []
	for index in range(count):
		result.append(float(index) * 0.5)
	return result
