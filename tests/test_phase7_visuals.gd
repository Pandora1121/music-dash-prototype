extends SceneTree

const PlayerScene = preload("res://scenes/player.tscn")
const GameWorldScript = preload("res://scripts/game_world.gd")
const MainScene = preload("res://scenes/main.tscn")

func _initialize() -> void:
	if not await _test_player_animation_tracks_physics_states():
		return
	if not _test_map_palette_and_pulse_follow_music_profile():
		return
	if not await _test_crash_animation_keeps_running_on_result_screen():
		return
	print("PASS: phase 7 visuals")
	quit(0)

func _test_player_animation_tracks_physics_states() -> bool:
	if not InputMap.has_action("jump"):
		InputMap.add_action("jump")
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(240.0, 600.0)
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(240.0, 20.0)
	floor_shape.shape = floor_rect
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	var player: CharacterBody2D = PlayerScene.instantiate()
	player.position = Vector2(240.0, 562.0)
	root.add_child(player)
	await physics_frame
	if not _expect(player.has_method("current_animation"), "player should expose its animation state", player):
		return false
	if not _expect(StringName(player.call("current_animation")) == &"run", "grounded player should use run animation", player):
		return false
	var gravity_before := float(player.get("gravity"))
	var jump_before := float(player.get("jump_velocity"))
	if not _expect(player.call("try_jump", true), "grounded player should jump", player):
		return false
	if not _expect(StringName(player.call("current_animation")) == &"jump", "jump input should change the pose to jump", player):
		return false
	var saw_landing := false
	for _frame in range(90):
		await physics_frame
		if StringName(player.call("current_animation")) == &"land":
			saw_landing = true
	if not _expect(saw_landing, "landing should play a short landing animation", player):
		return false
	if not _expect(is_equal_approx(float(player.get("gravity")), gravity_before) and is_equal_approx(float(player.get("jump_velocity")), jump_before), "visual animation should not change jump physics", player):
		return false
	player.call("crash")
	if not _expect(StringName(player.call("current_animation")) == &"crash", "crash should trigger its own visual state", player):
		return false
	player.call("reset_player")
	if not _expect(StringName(player.call("current_animation")) == &"run", "restart should restore the runner pose", player):
		return false
	player.free()
	floor_body.free()
	return true

func _test_map_palette_and_pulse_follow_music_profile() -> bool:
	var world := Node2D.new()
	world.set_script(GameWorldScript)
	root.add_child(world)
	if not _expect(world.has_method("set_music_profile"), "map should accept song energy and difficulty", world):
		return false
	if not _expect(world.has_method("on_beat"), "map should keep an audio-beat callback", world):
		return false
	world.call("set_music_profile", _analysis(0.1), &"Easy")
	var calm_color: Color = world.get("section_tint")
	world.call("set_music_profile", _analysis(0.9), &"Expert")
	if not _expect(not world.get("section_tint").is_equal_approx(calm_color), "difficulty should alter the map palette", world):
		return false
	if not _expect(is_equal_approx(float(world.get("average_music_intensity")), 0.9), "map should retain analyzed track energy", world):
		return false
	world.call("on_beat", 16, 1.0)
	if not _expect(float(world.get("beat_pulse_strength")) >= 1.0 and int(world.get("section_index")) == 1, "strong section beat should pulse and advance the map", world):
		return false
	world.free()
	return true

func _test_crash_animation_keeps_running_on_result_screen() -> bool:
	var main: Control = MainScene.instantiate()
	main.set("progression_profile_path", "user://phase7_visuals_profile.json")
	root.add_child(main)
	await process_frame
	main.call("_start_run")
	var player: CharacterBody2D = main.get_node("GameWorld/Player")
	player.call("crash")
	await process_frame
	var animation_time_before := float(player.get("_animation_time"))
	await create_timer(0.2).timeout
	var animation_time_after := float(player.get("_animation_time"))
	var conductor: Node = main.get_node("AudioConductor")
	if main.get("screen_state") != &"crashed" or int(player.get("process_mode")) != Node.PROCESS_MODE_ALWAYS or animation_time_after <= animation_time_before:
		push_error("crash burst should keep animating while the result screen freezes gameplay")
		conductor.call("stop_song")
		main.free()
		quit(1)
		return false
	conductor.call("stop_song")
	await create_timer(0.2).timeout
	main.free()
	return true

func _analysis(intensity: float) -> Dictionary:
	var features: Array[Dictionary] = []
	for _index in range(32):
		features.append({"intensity": intensity})
	return {"status": &"ok", "beat_features": features}

func _expect(condition: bool, message: String, node: Node) -> bool:
	if condition:
		return true
	push_error(message)
	if is_instance_valid(node):
		node.free()
	quit(1)
	return false
