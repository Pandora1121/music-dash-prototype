extends SceneTree

const ProfileScript = preload("res://scripts/gameplay_profile.gd")

func _initialize() -> void:
	_test_speed_scales_by_difficulty()
	_test_speed_is_derived_from_bpm_and_clamped()
	_test_density_tracks_difficulty_and_music_energy()
	_test_invalid_inputs_fail_without_partial_profile()
	print("PASS: gameplay profile")
	quit(0)

func _test_speed_scales_by_difficulty() -> void:
	var profile: RefCounted = ProfileScript.new()
	var expected := [316.8, 345.6, 374.4, 406.8, 439.2]
	var difficulties: Array[StringName] = [&"Easy", &"Normal", &"Hard", &"Expert", &"Insane"]
	for index in range(difficulties.size()):
		assert(is_equal_approx(profile.scroll_speed_for(120.0, difficulties[index]), expected[index]), "120 BPM speed should follow the documented difficulty factor")
		if index > 0:
			assert(profile.scroll_speed_for(120.0, difficulties[index]) > profile.scroll_speed_for(120.0, difficulties[index - 1]), "higher difficulty should move hazards faster")

func _test_speed_is_derived_from_bpm_and_clamped() -> void:
	var profile: RefCounted = ProfileScript.new()
	var slow: float = profile.scroll_speed_for(60.0, &"Normal")
	var fast: float = profile.scroll_speed_for(240.0, &"Normal")
	assert(slow < profile.scroll_speed_for(120.0, &"Normal") and fast > profile.scroll_speed_for(120.0, &"Normal"), "tempo should raise or lower obstacle speed")
	assert(profile.scroll_speed_for(0.1, &"Easy") == 280.0, "extremely slow tempos should respect minimum gameplay speed")
	assert(profile.scroll_speed_for(5000.0, &"Insane") <= 520.0, "extremely fast tempos should stay below maximum gameplay speed")
	assert(profile.scroll_speed_for(0.0, &"Easy") == 0.0 and profile.scroll_speed_for(INF, &"Easy") == 0.0, "invalid BPM should not produce a speed")

func _test_density_tracks_difficulty_and_music_energy() -> void:
	var profile: RefCounted = ProfileScript.new()
	var quiet: Dictionary = profile.profile_for(_analysis(120.0, [0.0, 0.0]), &"Normal")
	var loud: Dictionary = profile.profile_for(_analysis(120.0, [1.0, 1.0]), &"Normal")
	var harder: Dictionary = profile.profile_for(_analysis(120.0, [0.5, 0.5]), &"Expert")
	assert(quiet.status == &"ok" and loud.status == &"ok" and harder.status == &"ok", "valid song/difficulty profiles should be produced")
	assert(loud.density > quiet.density, "higher average song energy should increase obstacle chance")
	assert(harder.density > profile.profile_for(_analysis(120.0, [0.5, 0.5]), &"Easy").density, "higher difficulty should increase obstacle chance")
	assert(quiet.density >= 0.15 and loud.density <= 0.82, "density should stay within readable limits")
	assert(is_equal_approx(quiet.average_intensity, 0.0) and is_equal_approx(loud.average_intensity, 1.0), "profile should expose the measured average intensity")

func _test_invalid_inputs_fail_without_partial_profile() -> void:
	var profile: RefCounted = ProfileScript.new()
	assert(profile.profile_for(_analysis(120.0, [0.5]), &"Unknown").status == &"failed", "unknown difficulty should fail")
	assert(profile.profile_for(_analysis(0.0, [0.5]), &"Easy").status == &"failed", "zero BPM should fail")
	assert(profile.profile_for(_analysis(120.0, [1.1]), &"Easy").status == &"failed", "out-of-range energy should fail")
	assert(profile.profile_for({"status": &"failed"}, &"Easy").status == &"failed", "failed analysis should not produce a partial profile")

func _analysis(bpm: float, intensities: Array) -> Dictionary:
	var features: Array[Dictionary] = []
	var beat_times: Array[float] = []
	for index in range(intensities.size()):
		features.append({"onset": float(intensities[index]), "bass": 0.4, "mid": 0.4, "treble": 0.4, "intensity": float(intensities[index])})
		beat_times.append(float(index) * 60.0 / bpm if bpm > 0.0 else float(index))
	return {"status": &"ok", "bpm": bpm, "duration_seconds": 8.0, "beat_times": beat_times, "beat_features": features}
