extends SceneTree

const ChartGenerator = preload("res://scripts/procedural_chart_generator.gd")

func _initialize() -> void:
	var generator: RefCounted = ChartGenerator.new()
	var analysis := _make_analysis(100)
	var first: Dictionary = generator.generate(analysis, &"Normal", 7341, 360.0)
	var repeat: Dictionary = generator.generate(analysis, &"Normal", 7341, 360.0)
	var alternate: Dictionary = generator.generate(analysis, &"Normal", 7342, 360.0)
	assert(first.status == &"ok", "valid features should produce a chart")
	assert(first.events == repeat.events, "same inputs and seed should produce identical events")
	assert(first.events != alternate.events, "different seeds should vary a sufficiently long chart")
	assert(first.events.size() > 0, "generated chart should contain obstacles")
	assert(is_equal_approx(float(first.get("scroll_speed", -1.0)), 360.0), "chart should expose the speed used by its fairness checks")
	_test_music_selects_new_hazard_shapes(generator)
	_test_requested_speed_controls_chart_fairness(generator, analysis)
	_check_chart(generator, analysis, &"Easy")
	_check_chart(generator, analysis, &"Normal")
	_check_chart(generator, analysis, &"Hard")
	_check_chart(generator, analysis, &"Expert")
	_check_chart(generator, analysis, &"Insane")
	assert(generator.generate({}, &"Normal", 1, 360.0).status == &"failed", "invalid analysis should fail explicitly")
	assert(generator.generate(analysis, &"Normal", 1, 0.0).status == &"failed", "invalid scroll speed should fail explicitly")
	var low_confidence := analysis.duplicate(true)
	low_confidence.confidence = 0.01
	assert(generator.generate(low_confidence, &"Normal", 1, 360.0).status == &"failed", "low-confidence analysis should not generate a chart")
	var malformed := analysis.duplicate(true)
	malformed.beat_times = "not an array"
	assert(generator.generate(malformed, &"Normal", 1, 360.0).status == &"failed", "malformed beat data should fail explicitly")
	print("PASS: procedural chart generator")
	quit()

func _check_chart(generator: RefCounted, analysis: Dictionary, difficulty: StringName) -> void:
	var chart: Dictionary = generator.generate(analysis, difficulty, 8128, 360.0)
	assert(chart.status == &"ok", "supported difficulty should generate a chart")
	var events: Array = chart.events
	assert(events.size() > 0, "each difficulty should provide playable events")
	var previous_index := -1
	var previous_time := -INF
	for event in events:
		var beat_index := int(event.beat_index)
		var hit_time := float(chart.beat_times[beat_index])
		assert(beat_index > previous_index, "event beat indices should be strictly ordered")
		assert(event.kind in [&"spike", &"block", &"saw", &"crystal"], "only supported obstacle kinds should be generated")
		assert(hit_time >= 1120.0 / float(chart.get("scroll_speed", 360.0)), "events should leave enough spawn warning time")
		if previous_index >= 0:
			assert(hit_time - previous_time - 48.0 / float(chart.get("scroll_speed", 360.0)) >= 0.8, "events should preserve reaction time after obstacle travel width")
		previous_index = beat_index
		previous_time = hit_time

func _test_music_selects_new_hazard_shapes(generator: RefCounted) -> void:
	var analysis := _make_analysis(200)
	for index in range(analysis.beat_features.size()):
		analysis.beat_features[index] = {"onset": 1.0, "bass": 1.0, "mid": 0.5, "treble": 0.0, "intensity": 1.0}
	var bass_chart: Dictionary = generator.generate(analysis, &"Insane", 1234, 360.0)
	assert(not bass_chart.events.is_empty(), "strong bass music should generate events")
	for event in bass_chart.events:
		assert(event.kind == &"saw", "strong bass should select the saw hazard")
	for index in range(analysis.beat_features.size()):
		analysis.beat_features[index] = {"onset": 1.0, "bass": 0.0, "mid": 0.5, "treble": 1.0, "intensity": 1.0}
	var treble_chart: Dictionary = generator.generate(analysis, &"Insane", 1234, 360.0)
	assert(not treble_chart.events.is_empty(), "strong treble music should generate events")
	for event in treble_chart.events:
		assert(event.kind == &"crystal", "strong treble should select the crystal hazard")

func _test_requested_speed_controls_chart_fairness(generator: RefCounted, analysis: Dictionary) -> void:
	var faster: Dictionary = generator.generate(analysis, &"Insane", 8128, 500.0)
	assert(faster.status == &"ok" and float(faster.get("scroll_speed", -1.0)) == 500.0, "chart should retain the selected difficulty speed")
	var previous_time := -INF
	for event in faster.events:
		var target_time := float(faster.beat_times[event.beat_index])
		assert(target_time >= 1120.0 / 500.0, "fast chart events should preserve the spawn warning")
		if previous_time > -INF:
			assert(target_time - previous_time >= 0.8 + 48.0 / 500.0, "fast chart events should preserve reaction spacing for their speed")
		previous_time = target_time

func _make_analysis(beat_count: int) -> Dictionary:
	var beat_times: Array[float] = []
	var beat_features: Array[Dictionary] = []
	for index in range(beat_count):
		beat_times.append(float(index) * 0.5)
		beat_features.append({
			"onset": float((index * 17) % 11) / 10.0,
			"bass": float((index * 7) % 13) / 12.0,
			"mid": float((index * 5) % 9) / 8.0,
			"treble": float((index * 3) % 7) / 6.0,
			"intensity": float((index * 11) % 15) / 14.0,
		})
	return {"status": &"ok", "bpm": 120.0, "confidence": 0.9, "duration_seconds": float(beat_count) * 0.5, "beat_times": beat_times, "beat_features": beat_features}
