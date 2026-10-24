extends SceneTree

const ChartDataScript = preload("res://scripts/chart_data.gd")
const EditorScene = preload("res://scenes/chart_editor.tscn")

func _initialize() -> void:
	var input_chart: Dictionary = _make_chart()
	var input_events: Array = input_chart.events.duplicate(true)
	var editor: Control = EditorScene.instantiate()
	root.add_child(editor)
	await process_frame
	assert(editor.has_method("configure"), "runtime editor should expose configure")
	assert(editor.has_method("cycle_beat"), "runtime editor should expose beat cycling")
	editor.call("configure", input_chart, "test track.wav")
	assert(editor.call("current_chart") == input_chart, "editor should load the schema chart")
	assert(editor.get_node("EditorContent/Header/TrackName").text == "test track.wav", "editor should display the selected track name")
	assert(editor.get_node("EditorContent/Timeline/BeatGrid").get_child_count() == input_chart.beat_times.size(), "editor should display one control per beat")
	assert(editor.get_node("EditorContent/Actions/LoadButton") is Button, "editor should expose a load button")
	assert(editor.call("cycle_beat", 8), "existing obstacle should be editable")
	assert(editor.call("current_chart").events[0].kind == &"block", "spike should cycle to block")
	assert(editor.call("cycle_beat", 8), "block should cycle to empty")
	var after_removal: Dictionary = editor.call("current_chart")
	assert(after_removal.events.size() == 1 and after_removal.events[0].beat_index == 10, "empty state should remove only the selected event")
	assert(editor.call("cycle_beat", 8), "empty should cycle back to spike")
	assert(editor.call("clear_chart"), "clear action should succeed")
	assert(editor.call("current_chart").events.is_empty(), "clear should remove every obstacle")
	var saved: Array[Dictionary] = []
	var played: Array[Dictionary] = []
	var returned: Array[Dictionary] = []
	var load_requests := [0]
	editor.load_requested.connect(func() -> void: load_requests[0] += 1)
	editor.save_requested.connect(func(chart: Dictionary) -> void: saved.append(chart))
	editor.play_requested.connect(func(chart: Dictionary) -> void: played.append(chart))
	editor.back_requested.connect(func(chart: Dictionary) -> void: returned.append(chart))
	editor.call("load_chart")
	assert(load_requests[0] == 1, "load button action should request the file dialog")
	editor.call("save_chart")
	assert(saved.size() == 1 and saved[0].events.is_empty(), "save should emit a valid empty schema chart")
	editor.call("play_chart")
	assert(played.is_empty(), "empty chart must not emit a playable gameplay chart")
	editor.call("cycle_beat", 8)
	editor.call("play_chart")
	assert(played.size() == 1 and played[0].events.size() == 1, "play should emit the converted gameplay chart")
	editor.call("back")
	assert(returned.size() == 1 and returned[0].events.size() == 1, "back should return the in-session edits")
	assert(input_chart.events == input_events, "editing should not mutate the caller's chart")
	editor.free()
	print("PASS: chart editor")
	quit()

func _make_chart() -> Dictionary:
	var data: RefCounted = ChartDataScript.new()
	var chart: Dictionary = data.new_empty("editor chart", 120.0, 10.0)
	chart.events = [{"beat_index": 8, "kind": &"spike"}, {"beat_index": 10, "kind": &"block"}]
	return chart
