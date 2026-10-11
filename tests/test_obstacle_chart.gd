extends SceneTree

func _initialize() -> void:
	var chart_script: Script = load("res://scripts/obstacle_chart.gd")
	assert(chart_script != null, "obstacle chart should exist")
	var chart: RefCounted = chart_script.new()
	var events: Array[Dictionary] = chart.events()
	assert(events.size() >= 5, "prototype chart should contain several obstacles")
	for index in range(1, events.size()):
		assert(events[index].beat_index > events[index - 1].beat_index, "chart beats should increase")
	assert(chart.minimum_reaction_time(120.0, 360.0) >= 0.8, "chart should leave a fair reaction window")
	print("PASS: obstacle chart")
	quit()
