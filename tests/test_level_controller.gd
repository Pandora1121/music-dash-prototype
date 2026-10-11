extends SceneTree

func _initialize() -> void:
	var controller_script: Script = load("res://scripts/level_controller.gd")
	assert(controller_script != null, "level controller should exist")
	var controller: Node = controller_script.new()
	root.add_child(controller)
	var due_events: Array[Dictionary] = []
	controller.obstacle_due.connect(func(event: Dictionary): due_events.append(event))
	controller.begin_level()
	controller.advance(1.0)
	assert(due_events.size() == 1, "first chart obstacle should be scheduled once")
	controller.advance(0.1)
	assert(due_events.size() == 1, "an obstacle event must not be emitted twice")
	controller.reset_level()
	controller.begin_level()
	controller.advance(1.0)
	assert(due_events.size() == 2, "restart should replay the same first chart event")
	controller.queue_free()
	print("PASS: level controller")
	quit()
