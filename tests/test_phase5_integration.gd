extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const ProgressionStoreScript = preload("res://scripts/progression_store.gd")
const RunScorerScript = preload("res://scripts/run_scorer.gd")
const TEST_DIR := "user://phase5_profile_tests"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	await _test_new_profile_hud_and_completion()
	await _test_selected_difficulty_chart()
	await _test_crash_and_restart()
	print("PASS: phase 5 integration")
	quit()

func _test_new_profile_hud_and_completion() -> void:
	var profile_path := TEST_DIR + "/main_default.json"
	_remove_file(profile_path)
	var main: Control = await _create_main(profile_path)
	assert(main.get("selected_difficulty") == &"Easy", "new profile should select Easy")
	var selector: OptionButton = main.get("difficulty_selector")
	assert(selector != null and selector.is_item_disabled(1), "locked Normal should be disabled in menu")
	assert(String(main.get("_difficulty_info_label").text).contains("BEST"), "menu should display saved high score")
	main.call("_on_difficulty_selected", 1)
	assert(main.get("selected_difficulty") == &"Easy", "locked difficulty selection should be rejected")
	main.get("start_button").emit_signal("pressed")
	var chart: Dictionary = main.get("_prepared_chart")
	assert(chart.difficulty == &"Easy", "selected difficulty should reach generated chart")
	var target_times: Array = main.call("_target_times_for_chart", chart)
	assert(target_times.size() == chart.events.size(), "each obstacle should map to one score target")
	for index in range(chart.events.size()):
		var event: Dictionary = chart.events[index]
		assert(is_equal_approx(float(target_times[index]), float(chart.beat_times[event.beat_index])), "generated score target should use chart beat time")
	var fallback: Dictionary = main.call("_chart_for_analysis", {"status": &"failed"}, 55, &"Easy")
	var fallback_targets: Array = main.call("_target_times_for_chart", fallback)
	var first_event: Dictionary = fallback.events[0]
	assert(is_equal_approx(float(fallback_targets[0]), float(first_event.beat_index) * 60.0 / fallback.bpm), "authored fallback target should use chart BPM")
	var controlled_scorer: RefCounted = RunScorerScript.new()
	controlled_scorer.configure([1.0, 2.0])
	main.set("_scorer", controlled_scorer)
	main.call("_on_player_jumped", 1.0)
	assert(String(main.get("score_label").text).contains("1000"), "accurate jump should update score HUD")
	assert(String(main.get("combo_label").text).contains("1"), "accurate jump should update combo HUD")
	main.call("_on_player_jumped", 2.150001)
	assert(main.get("judgment_label").text == "MISS", "late input should surface Miss feedback immediately")
	main.call("_process", 0.0)
	assert(main.get("progress_bar") != null, "HUD should expose song progress")
	main.call("_finish_level")
	assert(main.get("screen_state") == &"results", "chart completion should show results")
	assert(main.get("_progression_store").unlocked_difficulty() == &"Normal", "completion should unlock the next difficulty")
	var results_text := String(main.get("_overlay_body_label").text)
	assert(results_text.contains("SCORE") and results_text.contains("PERFECT") and results_text.contains("MISS") and results_text.contains("BEST COMBO"), "results should show complete run statistics")
	main.get_node("AudioConductor").call("stop_song")
	await create_timer(0.5).timeout
	main.free()
	await process_frame

func _test_selected_difficulty_chart() -> void:
	var profile_path := TEST_DIR + "/main_hard.json"
	_remove_file(profile_path)
	var store: RefCounted = ProgressionStoreScript.new()
	store.load_profile(profile_path)
	assert(store.record_run(&"Easy", 10, true, profile_path), "Easy completion should persist")
	assert(store.record_run(&"Normal", 10, true, profile_path), "Normal completion should persist")
	var main: Control = await _create_main(profile_path)
	var selector: OptionButton = main.get("difficulty_selector")
	assert(not selector.is_item_disabled(2), "Hard should be available after Normal completion")
	selector.select(2)
	selector.item_selected.emit(2)
	assert(main.get("selected_difficulty") == &"Hard", "menu should accept unlocked difficulty")
	main.call("_prepare_chart")
	assert(main.get("_prepared_chart").difficulty == &"Hard", "chart generation should use selected difficulty")
	main.call("_start_run")
	main.call("_finish_level")
	assert(main.get("_progression_store").unlocked_difficulty() == &"Expert", "completing Hard should unlock Expert")
	main.get_node("AudioConductor").call("stop_song")
	await create_timer(0.5).timeout
	main.free()
	await process_frame

func _test_crash_and_restart() -> void:
	var profile_path := "user://missing_parent_phase5/main_crash.json"
	_remove_file(profile_path)
	var main: Control = await _create_main(profile_path)
	main.call("_start_run")
	var target_times: Array = main.call("_target_times_for_chart", main.get("_prepared_chart"))
	main.call("_on_player_jumped", float(target_times[0]))
	main.call("_on_player_crashed")
	assert(main.get("screen_state") == &"crashed", "collision should show crash summary")
	assert(main.get("_progression_store").best_score(&"Easy") > 0, "crash should record the run's best score")
	assert(main.get("_progression_store").unlocked_difficulty() == &"Easy", "crash must not unlock the next difficulty")
	assert(String(main.get("_overlay_body_label").text).contains("BEST"), "crash summary should show the saved high score")
	main.call("_restart_run")
	var summary: Dictionary = main.get("_scorer").get_summary()
	assert(summary.score == 0 and summary.combo == 0, "restart should reset score and combo")
	main.get_node("AudioConductor").call("stop_song")
	await create_timer(0.5).timeout
	main.free()
	await process_frame

func _create_main(profile_path: String) -> Control:
	var main: Control = MainScene.instantiate()
	main.set("progression_profile_path", profile_path)
	root.add_child(main)
	await process_frame
	return main

func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
