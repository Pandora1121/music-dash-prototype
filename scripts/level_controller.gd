extends Node

signal obstacle_due(event: Dictionary)
signal completed

const ObstacleChart = preload("res://scripts/obstacle_chart.gd")
const BPM := 120.0
const PLAYER_X := 240.0
const SPAWN_X := 1360.0
const SCROLL_SPEED := 360.0
const TRAVEL_TIME := (SPAWN_X - PLAYER_X) / SCROLL_SPEED

var elapsed := 0.0
var chart_cursor := 0
var active := false
var _events: Array[Dictionary] = []

func _init() -> void:
	_events = ObstacleChart.new().events()

func begin_level() -> void:
	reset_level()
	active = true

func reset_level() -> void:
	active = false
	elapsed = 0.0
	chart_cursor = 0

func advance(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	while chart_cursor < _events.size():
		var event: Dictionary = _events[chart_cursor]
		var hit_time := float(event.beat_index) * 60.0 / BPM
		if hit_time - TRAVEL_TIME > elapsed:
			break
		obstacle_due.emit(event)
		chart_cursor += 1
	var last_hit_time := float(_events.back().beat_index) * 60.0 / BPM
	if elapsed >= last_hit_time + 0.8:
		active = false
		completed.emit()
