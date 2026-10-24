extends SceneTree

func _initialize() -> void:
	var main_scene := load("res://scenes/main.tscn")
	assert(main_scene != null, "main scene should exist")
	var instance: Node = main_scene.instantiate()
	assert(instance is Control, "main scene root should be a Control")
	root.add_child(instance)
	await process_frame
	assert(is_instance_valid(instance.get("_audio_conductor")), "building the menu should preserve the audio conductor")
	var button: Button = instance.get("start_button")
	assert(button != null, "main scene should expose a start button")
	assert(instance.get("selected_difficulty") == &"Easy", "fresh progression should start at Easy")
	button.emit_signal("pressed")
	assert(instance.get("screen_state") == &"playing", "start button should open the gameplay placeholder")
	var conductor: Node = instance.get_node("AudioConductor")
	assert(conductor.call("is_song_playing"), "starting a run should start the prototype music")
	assert(conductor.get_node("MusicPlayer").get("stream") != null, "prototype music should be bundled in the project")
	assert(instance.get_node_or_null("GameWorld/Player") != null, "gameplay should contain the player")
	assert(instance.get("score_label") != null and instance.get("progress_bar") != null, "gameplay should show score and song progress")
	conductor.call("consume_beats_until", 0.0)
	var world: Node = instance.get_node("GameWorld")
	var player: Node = instance.get_node("GameWorld/Player")
	assert(is_equal_approx(world.get("beat_pulse_strength"), 1.0), "downbeat should pulse the game world")
	assert(is_equal_approx(player.get("beat_glow_strength"), 1.0), "downbeat should pulse the player glow")
	var opening_tint: Color = world.get("section_tint")
	conductor.call("consume_beats_until", 8.0)
	assert(int(world.get("section_index")) == 1 and not world.get("section_tint").is_equal_approx(opening_tint), "every 16th beat should change the section palette")
	var level: Node = instance.get_node("LevelController")
	var chart: Dictionary = instance.get("_prepared_chart")
	var first_event: Dictionary = chart.events[0]
	var first_hit_time := float(chart.beat_times[first_event.beat_index])
	level.advance(first_hit_time - 1120.0 / 360.0 + 0.01, conductor.get("audio_offset_seconds"), conductor.get("bpm"))
	assert(instance.get_node("GameWorld").get_child_count() >= 3, "chart should spawn the first obstacle")
	instance.get_node("GameWorld/Player").crash()
	assert(instance.get("screen_state") == &"playing", "crash flow should defer scene changes")
	await process_frame
	assert(instance.get("screen_state") == &"crashed", "collision should expose a restart state")
	assert(not conductor.call("is_song_playing"), "crashing should stop the music")
	instance.call("_restart_run")
	assert(instance.get("screen_state") == &"playing", "restart should return to gameplay")
	assert(conductor.call("is_song_playing"), "restart should start the music again")
	assert(is_zero_approx(instance.get_node("LevelController").elapsed), "restart should reset the chart clock")
	instance.call("_pause_run")
	var paused_position: float = conductor.call("song_position")
	await process_frame
	await process_frame
	assert(is_equal_approx(conductor.call("song_position"), paused_position), "pause should freeze the audio clock")
	instance.call("_resume_run")
	assert(conductor.call("is_song_playing"), "resume should continue audio playback")
	conductor.call("stop_song")
	await create_timer(0.5).timeout
	await process_frame
	instance.free()
	await process_frame
	print("PASS: project smoke")
	quit()
