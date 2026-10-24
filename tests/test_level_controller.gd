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
	_test_chart_speed_sets_spawn_lead(controller, due_events)
	controller.queue_free()
	print("PASS: level controller")
	quit()

func _test_chart_speed_sets_spawn_lead(controller: Node, due_events: Array[Dictionary]) -> void:
	controller.reset_level()
	controller.set_chart({"status": &"ok", "bpm": 120.0, "beat_times": [10.0], "events": [{"beat_index": 0, "kind": &"spike"}], "scroll_speed": 280.0})
	assert(controller.has_method("scroll_speed") and is_equal_approx(float(controller.call("scroll_speed")), 280.0), "controller should expose chart's obstacle speed")
	controller.begin_level()
	var before_spawn := due_events.size()
	controller.advance(5.99)
	assert(due_events.size() == before_spawn, "slower hazards should keep their longer travel lead time")
	controller.advance(6.0)
	assert(due_events.size() == before_spawn + 1, "slower hazard should spawn at target minus its own travel time")
