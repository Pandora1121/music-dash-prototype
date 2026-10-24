extends SceneTree

const ChartDataScript = preload("res://scripts/chart_data.gd")
const PLUGIN_CFG := "res://addons/music_dash_chart_editor/plugin.cfg"
const DOCK_SCRIPT := "res://addons/music_dash_chart_editor/chart_editor_dock.gd"
const PLUGIN_PATH := "res://addons/music_dash_chart_editor/plugin.cfg"
const TEST_DIR := "user://chart_editor_plugin_tests"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	var config := ConfigFile.new()
	if not _expect(config.load(PLUGIN_CFG) == OK, "Godot editor plugin config should exist"):
		quit(1)
		return
	if not _expect(config.get_value("plugin", "script", "") == "plugin.gd", "plugin config should point to its EditorPlugin script"):
		quit(1)
		return
	var enabled: PackedStringArray = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
	if not _expect(PLUGIN_PATH in enabled, "project should enable the chart editor plugin"):
		quit(1)
		return
	var dock_script: Variant = load(DOCK_SCRIPT)
	if not _expect(dock_script is Script, "chart editor dock script should load"):
		quit(1)
		return
	var dock: Control = dock_script.new()
	root.add_child(dock)
	await process_frame
	if not _expect(dock.call("create_empty_chart", "plugin chart", 120.0, 10.0), "dock should create an empty chart grid"):
		quit(1)
		return
	var chart: Dictionary = dock.call("current_chart")
	if not _expect(chart.beat_times.size() == 20 and chart.events.is_empty(), "new dock chart should have a beat grid and no events"):
		quit(1)
		return
	if not _expect(dock.call("set_beat_event", 8, &"spike") and dock.call("set_beat_event", 10, &"block"), "dock should add fair events by beat index"):
		quit(1)
		return
	if not _expect(dock.call("remove_beat_event", 8), "dock should remove an event"):
		quit(1)
		return
	if not _expect(dock.call("set_beat_event", 8, &"spike"), "dock should restore the event for the interchange fixture"):
		quit(1)
		return
	var data: RefCounted = ChartDataScript.new()
	var runtime_path := TEST_DIR + "/runtime_chart.json"
	var saved: Dictionary = data.save_file(runtime_path, dock.call("current_chart"))
	if not _expect(saved.get("status") == &"ok", "shared service should create a runtime chart fixture"):
		quit(1)
		return
	if not _expect(dock.call("load_chart_from_path", runtime_path), "dock should open JSON produced by the runtime surface"):
		quit(1)
		return
	dock.get_node("ChartName").text = "renamed plugin chart"
	var dock_path := TEST_DIR + "/dock_chart.json"
	if not _expect(dock.call("save_chart_to_path", dock_path), "dock should save the shared chart format"):
		quit(1)
		return
	var loaded: Dictionary = data.load_file(dock_path)
	if not _expect(loaded.get("status") == &"ok" and loaded.chart.name == "renamed plugin chart" and loaded.chart.beat_times == dock.call("current_chart").beat_times and loaded.chart.events == dock.call("current_chart").events, "dock save should retain metadata, beats and events for runtime loading"):
		quit(1)
		return
	if not _expect(not dock.call("set_beat_event", 9, &"spike"), "unfair event spacing should be rejected"):
		quit(1)
		return
	dock.free()
	print("PASS: chart editor plugin")
	quit(0)

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	return false
