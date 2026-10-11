extends Node

signal obstacle_due(event: Dictionary)
signal completed

const ObstacleChart = preload("res://scripts/obstacle_chart.gd")
const BeatChartScript = preload("res://scripts/beat_chart.gd")
const BPM := 120.0
const PLAYER_X := 240.0
const SPAWN_X := 1360.0
const SCROLL_SPEED := 360.0
const TRAVEL_TIME := (SPAWN_X - PLAYER_X) / SCROLL_SPEED

var elapsed := 0.0
var chart_cursor := 0
var active := false
var _events: Array[Dictionary] = []
var _beat_chart: RefCounted

func _init() -> void:
	_events = ObstacleChart.new().events()
	_beat_chart = BeatChartScript.new()

func begin_level() -> void:
	reset_level()
	active = true

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
		var hit_time: float = _beat_chart.beat_time(event.beat_index, bpm, audio_offset_seconds)
		if hit_time - TRAVEL_TIME > elapsed:
			break
		obstacle_due.emit(event)
		chart_cursor += 1
	var last_hit_time: float = _beat_chart.beat_time(_events.back().beat_index, bpm, audio_offset_seconds)
	if elapsed >= last_hit_time + 0.8:
		active = false
		completed.emit()
