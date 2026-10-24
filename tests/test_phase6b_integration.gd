extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const ProgressionStoreScript = preload("res://scripts/progression_store.gd")
const TEST_DIR := "user://phase6b_integration_tests"
const CUSTOM_WAV := "res://assets/audio/music_dash_prototype.wav"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	if not await _test_menu_opens_editor_with_selected_chart():
		quit(1)
		return
	if not await _test_save_load_and_invalid_file_retains_chart():
		quit(1)
		return
	if not await _test_cancel_preserves_chart():
		quit(1)
		return
	if not await _test_edited_chart_and_stream_survive_restart():
		quit(1)
		return
	print("PASS: phase 6B integration")
	quit(0)

func _test_menu_opens_editor_with_selected_chart() -> bool:
	var main := await _create_main("main_editor.json")
	if not _expect(main.get("level_editor_button") is Button, "main menu should expose the level editor", main):
		return false
	main.call("_open_chart_editor")
	if not _expect(main.get("screen_state") == &"editor", "editor entry should switch the screen state", main):
		return false
	var editor: Control = main.get("_chart_editor")
	if not _expect(is_instance_valid(editor), "runtime editor should be mounted", main):
		return false
	var schema_chart: Dictionary = editor.call("current_chart")
	if not _expect(schema_chart.get("beat_times") == main.get("_selected_track").analysis.get("beat_times"), "editor should start with the selected track's beat grid", main):
		return false
	await _cleanup_main(main)
	return true

func _test_save_load_and_invalid_file_retains_chart() -> bool:
	var main := await _create_main("main_file_flow.json")
	main.call("_open_chart_editor")
	var editor: Control = main.get("_chart_editor")
	var chart: Dictionary = editor.call("current_chart")
	var first_event: Dictionary = chart.events[0]
	var original_kind: StringName = first_event.kind
	assert(editor.call("cycle_beat", int(first_event.beat_index)), "existing event should be editable")
	var edited: Dictionary = editor.call("current_chart")
	assert(edited.events[0].kind != original_kind, "editing should update the chart kind")
	var save_path := TEST_DIR + "/saved_chart.json"
	if not _expect(main.call("_save_chart_to_path", save_path, edited), "valid chart should save to JSON", main):
		return false
	if not _expect(main.call("_load_chart_from_path", save_path), "saved chart should load", main):
		return false
	var loaded: Dictionary = main.get("_edited_chart")
	if not _expect(loaded.events == edited.events and _beat_times_match(loaded.beat_times, edited.beat_times), "load should preserve edited events and beat timing", main):
		return false
	var previous: Dictionary = loaded.duplicate(true)
	var invalid_path := TEST_DIR + "/invalid.json"
	_write_text(invalid_path, "{broken")
	if not _expect(not main.call("_load_chart_from_path", invalid_path), "malformed JSON should be rejected", main):
		return false
	if not _expect(main.get("_edited_chart") == previous, "failed load should keep the current chart", main):
		return false
	var write_failure_path := TEST_DIR + "/write_failure.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(write_failure_path))
	if not _expect(not main.call("_save_chart_to_path", write_failure_path, previous), "write failure should be reported", main):
		return false
	if not _expect(main.get("_edited_chart") == previous, "failed save should keep the current chart", main):
		return false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(write_failure_path))
	await _cleanup_main(main)
	return true

func _test_cancel_preserves_chart() -> bool:
	var main := await _create_main("main_cancel.json")
	main.call("_open_chart_editor")
	var before: Dictionary = main.get("_edited_chart").duplicate(true)
	main.call("_on_chart_load_canceled")
	if not _expect(main.get("_edited_chart") == before, "canceling chart load should preserve the working chart", main):
		return false
	await _cleanup_main(main)
	return true

func _test_edited_chart_and_stream_survive_restart() -> bool:
	var main := await _create_main("main_restart.json")
	var selected_path := ProjectSettings.globalize_path(CUSTOM_WAV)
	if not _expect(main.call("_select_custom_track", selected_path), "supported WAV should be selected", main):
		return false
	main.call("_open_chart_editor")
	var editor: Control = main.get("_chart_editor")
	var initial: Dictionary = editor.call("current_chart")
	var first_event: Dictionary = initial.events[0]
	assert(editor.call("cycle_beat", int(first_event.beat_index)), "existing custom chart event should be editable")
	var edited_events: Array = editor.call("current_chart").events.duplicate(true)
	var selected_stream: AudioStreamWAV = main.get("_selected_track").stream
	assert(editor.call("play_chart"), "non-empty fair chart should start gameplay")
	var conductor: Node = main.get_node("AudioConductor")
	if not _expect(conductor.current_stream() == selected_stream, "gameplay should use the selected custom stream", main):
		return false
	main.call("_pause_run")
	main.call("_resume_run")
	main.call("_on_player_crashed")
	main.call("_restart_run")
	if not _expect(conductor.current_stream() == selected_stream, "restart should retain the custom stream", main):
		return false
	if not _expect(main.get("_prepared_chart").events == edited_events, "restart should reuse edited obstacle events", main):
		return false
	await _cleanup_main(main)
	return true

func _create_main(profile_name: String) -> Control:
	var profile_path := TEST_DIR + "/" + profile_name
	_remove_file(profile_path)
	var main: Control = MainScene.instantiate()
	main.set("progression_profile_path", profile_path)
	main.set("chart_directory", TEST_DIR + "/charts")
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

func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "test fixture should open")
	file.store_string(text)
	file.close()

func _beat_times_match(first: Array, second: Array) -> bool:
	if first.size() != second.size():
		return false
	for index in range(first.size()):
		if absf(float(first[index]) - float(second[index])) > 0.0000000001:
			return false
	return true

func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
