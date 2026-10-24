extends Node

signal obstacle_due(event: Dictionary)
signal completed

const ObstacleChart = preload("res://scripts/obstacle_chart.gd")
const BeatChartScript = preload("res://scripts/beat_chart.gd")
const BPM := 120.0
const PLAYER_X := 240.0
const SPAWN_X := 1360.0
const SCROLL_SPEED := 360.0
const TRAVEL_DISTANCE := SPAWN_X - PLAYER_X

var elapsed := 0.0
var chart_cursor := 0
var active := false
var _events: Array[Dictionary] = []
var _chart_beat_times: Array = []
var _chart_bpm := BPM
var _scroll_speed := SCROLL_SPEED
var _travel_time := TRAVEL_DISTANCE / SCROLL_SPEED
var _beat_chart: RefCounted

func _init() -> void:
	_events = ObstacleChart.new().events()
	_beat_chart = BeatChartScript.new()

func begin_level() -> void:
	reset_level()
	active = true

func set_chart(chart: Dictionary) -> void:
	if chart.get("status", &"failed") != &"ok" or not (chart.get("events", []) is Array):
		_use_authored_chart()
		return
	var chart_events: Array = chart.events
	if chart_events.is_empty():
		_use_authored_chart()
		return
	var beat_times_variant: Variant = chart.get("beat_times", [])
	if not (beat_times_variant is Array):
		_use_authored_chart()
		return
	var beat_times: Array = beat_times_variant
	var previous_time := -INF
	for raw_time in beat_times:
		if typeof(raw_time) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(raw_time)) or float(raw_time) <= previous_time:
			_use_authored_chart()
			return
		previous_time = float(raw_time)
	var validated_events: Array[Dictionary] = []
	var previous_index := -1
	for raw_event in chart_events:
		if not (raw_event is Dictionary):
			_use_authored_chart()
			return
		var beat_index := int(raw_event.get("beat_index", -1))
		var kind: StringName = raw_event.get("kind", &"")
		if beat_index <= previous_index or kind not in [&"spike", &"block", &"saw", &"crystal"] or (not beat_times.is_empty() and beat_index >= beat_times.size()):
			_use_authored_chart()
			return
		validated_events.append({"beat_index": beat_index, "kind": kind})
		previous_index = beat_index
	var bpm_value := float(chart.get("bpm", BPM))
	if not is_finite(bpm_value) or bpm_value <= 0.0:
		_use_authored_chart()
		return
	var speed_value: Variant = chart.get("scroll_speed", SCROLL_SPEED)
	if typeof(speed_value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(speed_value)) or float(speed_value) <= 0.0:
		_use_authored_chart()
		return
	_events = validated_events
	_chart_bpm = bpm_value
	_chart_beat_times = beat_times.duplicate()
	_scroll_speed = float(speed_value)
	_travel_time = TRAVEL_DISTANCE / _scroll_speed

func scroll_speed() -> float:
	return _scroll_speed

func _use_authored_chart() -> void:
	_events = ObstacleChart.new().events()
	_chart_beat_times.clear()
	_chart_bpm = BPM
	_scroll_speed = SCROLL_SPEED
	_travel_time = TRAVEL_DISTANCE / SCROLL_SPEED

func reset_level() -> void:
	active = false
	elapsed = 0.0
	chart_cursor = 0

func advance(song_position: float, audio_offset_seconds: float = 0.0, bpm: float = BPM) -> void:
	if not active:
		return
	elapsed = maxf(0.0, song_position)
	while chart_cursor < _events.size():
		var event: Dictionary = _events[chart_cursor]
		var hit_time := _event_time(event, audio_offset_seconds, bpm)
		if hit_time - _travel_time > elapsed:
			break
		obstacle_due.emit(event)
		chart_cursor += 1
	var last_hit_time := _event_time(_events.back(), audio_offset_seconds, bpm)
	if elapsed >= last_hit_time + 0.8:
		active = false
		completed.emit()

func _event_time(event: Dictionary, audio_offset_seconds: float, fallback_bpm: float) -> float:
	var beat_index := int(event.beat_index)
	if beat_index >= 0 and beat_index < _chart_beat_times.size():
		return float(_chart_beat_times[beat_index]) + audio_offset_seconds
	return _beat_chart.beat_time(beat_index, _chart_bpm if _chart_bpm > 0.0 else fallback_bpm, audio_offset_seconds)
