@tool
extends EditorPlugin

const DockScript = preload("res://addons/music_dash_chart_editor/chart_editor_dock.gd")

var _dock: EditorDock

func _enter_tree() -> void:
	_dock = EditorDock.new()
	_dock.title = "MUSIC DASH Charts"
	_dock.default_slot = EditorDock.DOCK_SLOT_RIGHT_UL
	_dock.add_child(DockScript.new())
	add_dock(_dock)

func _exit_tree() -> void:
	if is_instance_valid(_dock):
		remove_dock(_dock)
		_dock.queue_free()
	_dock = null
