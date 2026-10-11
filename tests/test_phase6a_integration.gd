extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const ProgressionStoreScript = preload("res://scripts/progression_store.gd")
const TEST_DIR := "user://phase6a_integration_tests"
const CUSTOM_WAV := "res://assets/audio/music_dash_prototype.wav"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	if not await _test_builtin_track_is_default():
		quit(1)
		return
	if not await _test_custom_wav_selection_builds_matching_chart():
		quit(1)
		return
	if not await _test_failed_selection_keeps_current_track():
		quit(1)
		return
	if not await _test_cancel_keeps_current_track():
		quit(1)
		return
	if not await _test_difficulty_and_restart_keep_custom_track():
		quit(1)
		return
	if not await _test_commit_rejects_empty_chart_without_replacing_track():
		quit(1)
		return
	print("PASS: phase 6A integration")
	quit(0)

func _test_builtin_track_is_default() -> bool:
	var main := await _create_main("main_default.json")
	var track_variant: Variant = main.get("_selected_track")
	if not _expect(track_variant is Dictionary, "built-in track should be selected when the menu opens", main):
		return false
	var track: Dictionary = track_variant
	if not _expect(track.get("display_name") == "music_dash_prototype.wav", "menu should show the built-in track name", main):
		return false
	if not _expect(track.get("analysis", {}).get("status") == &"ok", "built-in track should retain its analysis", main):
		return false
	if not _expect(main.get("builtin_track_button") is Button and main.get("custom_wav_button") is Button, "menu should expose built-in and custom song controls", main):
		return false
	var dialog: Variant = main.get("_custom_file_dialog")
	if not _expect(dialog is FileDialog and dialog.get("filters").size() > 0 and String(dialog.get("filters")[0]).to_lower().contains("*.wav"), "custom file dialog should filter WAV files", main):
		return false
	await _cleanup_main(main)
	return true

func _test_custom_wav_selection_builds_matching_chart() -> bool:
	var main := await _create_main("main_custom.json")
	if not _expect(main.has_method("_select_custom_track"), "Main should expose custom track selection", main):
		return false
	var selected_path := ProjectSettings.globalize_path(CUSTOM_WAV)
	if not _expect(main.call("_select_custom_track", selected_path), "supported WAV should be accepted", main):
		return false
	var track: Dictionary = main.get("_selected_track")
	var chart: Dictionary = main.get("_prepared_chart")
	if not _expect(track.get("path") == selected_path and track.get("display_name") == "music_dash_prototype.wav", "selected custom track should expose its path and file name", main):
		return false
	if not _expect(chart.get("status") == &"ok" and chart.get("difficulty") == &"Easy" and chart.get("events", []).size() > 0, "custom song should produce a playable chart for the selected difficulty", main):
		return false
	if not _expect(chart.get("beat_times") == track.get("analysis", {}).get("beat_times"), "custom chart should use the selected song's analyzed beats", main):
		return false
	if not _expect(String(main.get("song_details_label").text).contains("music_dash_prototype.wav"), "menu should display the selected custom song", main):
		return false
	await _cleanup_main(main)
	return true

func _test_failed_selection_keeps_current_track() -> bool:
	var main := await _create_main("main_failed_selection.json")
	var valid_path := ProjectSettings.globalize_path(CUSTOM_WAV)
	if not _expect(main.call("_select_custom_track", valid_path), "supported WAV should be selected before failure case", main):
		return false
	var previous: Dictionary = main.get("_selected_track")
	var previous_chart: Dictionary = main.get("_prepared_chart")
	var missing_path := ProjectSettings.globalize_path(TEST_DIR + "/missing.wav")
	if not _expect(not main.call("_select_custom_track", missing_path), "missing WAV should be rejected", main):
		return false
	var selected: Dictionary = main.get("_selected_track")
	if not _expect(selected.get("path") == previous.get("path") and main.get("_prepared_chart") == previous_chart, "failed selection should retain the selected track and chart", main):
		return false
	if not _expect(not String(main.get("song_error_label").text).is_empty(), "failed selection should show a useful error", main):
		return false
	await _cleanup_main(main)
	return true

func _test_cancel_keeps_current_track() -> bool:
	var main := await _create_main("main_cancel.json")
	var valid_path := ProjectSettings.globalize_path(CUSTOM_WAV)
	if not _expect(main.call("_select_custom_track", valid_path), "supported WAV should be selected before cancel case", main):
		return false
	var selected_before: Dictionary = main.get("_selected_track")
	main.call("_on_custom_file_canceled")
	var selected_after: Dictionary = main.get("_selected_track")
	if not _expect(selected_after.get("path") == selected_before.get("path"), "canceling the dialog should retain the selected song", main):
		return false
	await _cleanup_main(main)
	return true

func _test_difficulty_and_restart_keep_custom_track() -> bool:
	var profile_path := TEST_DIR + "/main_restart.json"
	_remove_file(profile_path)
	var store: RefCounted = ProgressionStoreScript.new()
	store.load_profile(profile_path)
	if not _expect(store.record_run(&"Easy", 100, true, profile_path), "test profile should unlock Normal", null):
		return false
	var main := await _create_main("main_restart.json", true)
	if not _expect(main.get("selected_difficulty") == &"Normal", "unlocked Normal should be selected for this test", main):
		return false
	var selected_path := ProjectSettings.globalize_path(CUSTOM_WAV)
	if not _expect(main.call("_select_custom_track", selected_path), "supported WAV should be selected", main):
		return false
	main.call("_on_difficulty_selected", 0)
	main.call("_prepare_chart")
	if not _expect(main.get("_prepared_chart").get("difficulty") == &"Easy", "changing difficulty should rebuild the custom chart", main):
		return false
	main.call("_on_difficulty_selected", 1)
	main.call("_prepare_chart")
	var chart_before: Dictionary = main.get("_prepared_chart").duplicate(true)
	main.call("_start_run")
	var conductor: Node = main.get_node("AudioConductor")
	var selected_stream: AudioStreamWAV = main.get("_selected_track").stream
	if not _expect(conductor.current_stream() == selected_stream, "gameplay should play the selected custom stream", main):
		return false
	main.call("_pause_run")
	main.call("_resume_run")
	main.call("_on_player_crashed")
	main.call("_restart_run")
	if not _expect(conductor.current_stream() == selected_stream, "restart should retain the custom audio stream", main):
		return false
	if not _expect(main.get("_prepared_chart").get("events") == chart_before.get("events") and main.get("_prepared_chart").get("seed") == chart_before.get("seed"), "restart should reuse the same custom chart and seed", main):
		return false
	await _cleanup_main(main)
	return true

func _test_commit_rejects_empty_chart_without_replacing_track() -> bool:
	var main := await _create_main("main_empty_chart.json")
	var selected_path := ProjectSettings.globalize_path(CUSTOM_WAV)
	if not _expect(main.call("_select_custom_track", selected_path), "supported WAV should be selected before empty chart case", main):
		return false
	var previous: Dictionary = main.get("_selected_track")
	var candidate := previous.duplicate(false)
	candidate.path = selected_path + ".other"
	candidate.display_name = "other.wav"
	var empty_chart: Dictionary = main.get("_prepared_chart").duplicate(true)
	empty_chart.events = []
	if not _expect(main.has_method("_try_commit_track"), "Main should expose the atomic track/chart commit boundary", main):
		return false
	if not _expect(not main.call("_try_commit_track", candidate, empty_chart), "custom track with no obstacle events should be rejected", main):
		return false
	var selected_after: Dictionary = main.get("_selected_track")
	if not _expect(selected_after.get("path") == previous.get("path"), "empty chart rejection should keep the prior track", main):
		return false
	await _cleanup_main(main)
	return true

func _create_main(profile_name: String, unlock_normal: bool = false) -> Control:
	var profile_path := TEST_DIR + "/" + profile_name
	_remove_file(profile_path)
	if unlock_normal:
		var store: RefCounted = ProgressionStoreScript.new()
		store.load_profile(profile_path)
		store.record_run(&"Easy", 100, true, profile_path)
	var main: Control = MainScene.instantiate()
	main.set("progression_profile_path", profile_path)
	root.add_child(main)
	await process_frame
	return main

func _cleanup_main(main: Control) -> void:
	if is_instance_valid(main):
		var conductor: Node = main.get_node_or_null("AudioConductor")
		if is_instance_valid(conductor):
			conductor.call("stop_song")
		await create_timer(0.5).timeout
		if is_instance_valid(main):
			main.free()
		await process_frame

func _expect(condition: bool, message: String, main: Control) -> bool:
	if condition:
		return true
	push_error(message)
	if is_instance_valid(main):
		var conductor: Node = main.get_node_or_null("AudioConductor")
		if is_instance_valid(conductor):
			conductor.call("stop_song")
		main.free()
	return false

func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
