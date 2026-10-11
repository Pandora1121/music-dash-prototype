extends SceneTree

func _initialize() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main: Node = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	if not main.has_method("_chart_for_analysis"):
		push_error("Main should provide generated and fallback chart selection")
		quit(1)
		return
	var fallback: Dictionary = main.call("_chart_for_analysis", {"status": &"failed"}, 99)
	assert(fallback.status == &"ok" and fallback.source == &"authored", "failed analysis should select the authored fallback")
	assert(fallback.bpm == 120.0, "authored fallback should use 120 BPM")
	var level_script: Script = load("res://scripts/level_controller.gd")
	var defensive_level: Node = level_script.new()
	root.add_child(defensive_level)
	var defensive_events: Array[Dictionary] = []
	defensive_level.obstacle_due.connect(func(event: Dictionary): defensive_events.append(event))
	defensive_level.set_chart({"status": &"ok", "bpm": 120.0, "events": [], "beat_times": []})
	defensive_level.begin_level()
	defensive_level.advance(1.0)
	assert(defensive_events.size() == 1, "an empty chart should fall back to the authored pattern")
	defensive_level.reset_level()
	defensive_events.clear()
	defensive_level.set_chart({"status": &"ok", "bpm": 120.0, "events": [{"beat_index": 0, "kind": &"spike"}], "beat_times": [NAN]})
	defensive_level.begin_level()
	defensive_level.advance(1.0)
	assert(defensive_events.size() == 1 and defensive_events[0].beat_index == 8, "non-finite beat times should fall back to the authored pattern")
	defensive_level.queue_free()
	main.get("start_button").emit_signal("pressed")
	var chart: Dictionary = main.get("_prepared_chart")
	assert(chart.status == &"ok" and chart.source == &"procedural", "confident bundled audio should select the procedural chart")
	var conductor: Node = main.get_node("AudioConductor")
	assert(is_equal_approx(float(conductor.get("bpm")), float(chart.bpm)), "audio conductor should use the chart tempo")
	var cached_events: Array = chart.events.duplicate(true)
	var level: Node = main.get_node("LevelController")
	level.advance(4.0, 0.0, conductor.get("bpm"))
	assert(main.get_node("GameWorld").get_child_count() > 2, "audio timeline should schedule generated chart obstacles")
	main.get_node("GameWorld/Player").call("crash")
	await process_frame
	main.call("_restart_run")
	assert(main.get("_prepared_chart").events == cached_events, "restart should reuse the prepared chart")
	assert(main.get("screen_state") == &"playing", "restart should start a new run")
	conductor.call("stop_song")
	await create_timer(0.5).timeout
	main.free()
	await process_frame
	print("PASS: phase 4 integration")
	quit()
