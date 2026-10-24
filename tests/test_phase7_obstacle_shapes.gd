extends SceneTree

const ObstacleScene = preload("res://scenes/obstacle.tscn")

func _initialize() -> void:
	await _test_hazard_shapes_use_matching_collision_geometry()
	await _test_saw_has_beat_ready_rotation()
	print("PASS: phase 7 obstacle shapes")
	quit(0)

func _test_hazard_shapes_use_matching_collision_geometry() -> void:
	var expected_types: Dictionary = {
		&"spike": ConvexPolygonShape2D,
		&"block": RectangleShape2D,
		&"saw": CircleShape2D,
		&"crystal": ConvexPolygonShape2D,
	}
	for kind in expected_types:
		var obstacle: Area2D = ObstacleScene.instantiate()
		obstacle.set("kind", kind)
		root.add_child(obstacle)
		await process_frame
		var collider: CollisionShape2D = obstacle.get_node("CollisionShape2D")
		assert(is_instance_of(collider.shape, expected_types[kind]), "%s should have a matching readable hitbox" % kind)
		obstacle.free()

func _test_saw_has_beat_ready_rotation() -> void:
	var obstacle: Area2D = ObstacleScene.instantiate()
	obstacle.set("kind", &"saw")
	root.add_child(obstacle)
	await process_frame
	var before := obstacle.rotation
	assert(obstacle.has_method("_process"), "hazard animation should be implemented")
	if obstacle.has_method("_process"):
		obstacle.call("_process", 0.25)
		assert(obstacle.rotation != before, "saw should rotate without changing its beat schedule")
	obstacle.free()
