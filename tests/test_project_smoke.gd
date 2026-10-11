extends SceneTree

func _initialize() -> void:
	var main_scene := load("res://scenes/main.tscn")
	assert(main_scene != null, "main scene should exist")
	var instance: Node = main_scene.instantiate()
	assert(instance is Control, "main scene root should be a Control")
	root.add_child(instance)
	await process_frame
	var button: Button = instance.get("start_button")
	assert(button != null, "main scene should expose a start button")
	button.emit_signal("pressed")
	assert(instance.get("screen_state") == &"playing", "start button should open the gameplay placeholder")
	assert(instance.get_node_or_null("GameWorld/Player") != null, "gameplay should contain the player")
	var level: Node = instance.get_node("LevelController")
	level.advance(1.0)
	assert(instance.get_node("GameWorld").get_child_count() >= 3, "chart should spawn the first obstacle")
	instance.get_node("GameWorld/Player").crash()
	assert(instance.get("screen_state") == &"playing", "crash flow should defer scene changes")
	await process_frame
	assert(instance.get("screen_state") == &"crashed", "collision should expose a restart state")
	instance.call("_restart_run")
	assert(instance.get("screen_state") == &"playing", "restart should return to gameplay")
	assert(is_zero_approx(instance.get_node("LevelController").elapsed), "restart should reset the chart clock")
	instance.free()
	print("PASS: project smoke")
	quit()
