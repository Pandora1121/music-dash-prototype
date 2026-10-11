extends SceneTree

func _initialize() -> void:
	var chart_script: Script = load("res://scripts/beat_chart.gd")
	assert(chart_script != null, "beat chart should exist")
	var chart: RefCounted = chart_script.new()
	assert(is_equal_approx(chart.beat_time(4, 120.0, 0.0), 2.0), "beat four at 120 BPM should occur at two seconds")
	assert(is_equal_approx(chart.beat_time(4, 120.0, 0.1), 2.1), "positive offset should shift beats later")
	assert(is_equal_approx(chart.beat_time(4, 120.0, -0.1), 1.9), "negative offset should shift beats earlier")
	assert(chart.drain_beats_until(1.1, 120.0, 0.0) == [0, 1, 2], "draining after a frame stall should include every elapsed beat")
	assert(chart.drain_beats_until(1.1, 120.0, 0.0).is_empty(), "consumed beats should not repeat")
	assert(chart.drain_beats_until(2.6, 120.0, 0.0) == [3, 4, 5], "later drain should resume from the next beat")
	chart.reset()
	assert(chart.drain_beats_until(0.0, 120.0, 0.0) == [0], "reset should make the downbeat available again")
	print("PASS: beat chart")
	quit()
