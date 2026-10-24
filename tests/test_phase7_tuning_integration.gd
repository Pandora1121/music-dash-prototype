extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const GameplayProfileScript = preload("res://scripts/gameplay_profile.gd")

func _initialize() -> void:
	var analysis := _make_loud_analysis(200)
	var main: Control = MainScene.instantiate()
	main.set("progression_profile_path", "user://phase7_tuning/main_profile.json")
	root.add_child(main)
	await process_frame
	var profile: RefCounted = GameplayProfileScript.new()
	var easy_profile: Dictionary = profile.profile_for(analysis, &"Easy")
	var insane_profile: Dictionary = profile.profile_for(analysis, &"Insane")
	var easy_chart: Dictionary = main.call("_chart_for_analysis", analysis, 7341, &"Easy")
	var insane_chart: Dictionary = main.call("_chart_for_analysis", analysis, 7341, &"Insane")
	assert(easy_chart.status == &"ok" and insane_chart.status == &"ok", "the selected difficulty should prepare a playable chart")
	assert(is_equal_approx(float(easy_chart.scroll_speed), float(easy_profile.scroll_speed)), "Main should pass the selected song/difficulty speed to the generator")
	assert(is_equal_approx(float(insane_chart.scroll_speed), float(insane_profile.scroll_speed)), "Main should use the selected difficulty's faster speed")
	assert(insane_chart.events.size() > easy_chart.events.size(), "higher difficulty and loud music should generate a denser fair chart")
	main.get_node("AudioConductor").call("stop_song")
	await create_timer(0.2).timeout
	main.free()
	print("PASS: phase 7 tuning integration")
	quit(0)

func _make_loud_analysis(beat_count: int) -> Dictionary:
	var beat_times: Array[float] = []
	var beat_features: Array[Dictionary] = []
	for index in range(beat_count):
		beat_times.append(float(index) * 0.5)
		beat_features.append({"onset": 1.0, "bass": 0.8, "mid": 0.7, "treble": 0.2, "intensity": 1.0})
	return {"status": &"ok", "bpm": 120.0, "confidence": 1.0, "duration_seconds": float(beat_count) * 0.5, "beat_times": beat_times, "beat_features": beat_features}
