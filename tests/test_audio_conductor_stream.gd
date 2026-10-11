extends SceneTree

const AudioConductorScript = preload("res://scripts/audio_conductor.gd")

func _initialize() -> void:
	if not await _test_selects_stream_and_rejects_null():
		quit(1)
		return
	if not await _test_stop_and_restart_retain_selected_stream():
		quit(1)
		return
	if not await _test_pause_resume_preserve_selected_stream():
		quit(1)
		return
	print("PASS: audio conductor stream")
	quit(0)

func _test_selects_stream_and_rejects_null() -> bool:
	var conductor := await _create_conductor()
	if not _has_stream_api(conductor):
		return _fail("AudioConductor should expose set_stream and current_stream", conductor)
	var selected := _load_custom_stream()
	if not _expect(selected != null, "custom WAV fixture should load", conductor):
		return false
	if not _expect(conductor.set_stream(selected), "valid stream should be selected", conductor):
		return false
	if not _expect(conductor.current_stream() == selected, "current stream should be the selected WAV", conductor):
		return false
	if not _expect(not conductor.set_stream(null), "null stream should be rejected", conductor):
		return false
	var retained := _expect(conductor.current_stream() == selected, "rejected null should not replace the selected WAV", conductor)
	conductor.stop_song()
	await create_timer(0.5).timeout
	conductor.free()
	await process_frame
	return retained

func _test_stop_and_restart_retain_selected_stream() -> bool:
	var conductor := await _create_conductor()
	if not _has_stream_api(conductor):
		return _fail("AudioConductor should expose set_stream and current_stream", conductor)
	var selected := _load_custom_stream()
	if not _expect(conductor.set_stream(selected), "valid stream should be selected", conductor):
		return false
	conductor.start_from(1.0)
	conductor.stop_song()
	if not _expect(conductor.current_stream() == selected, "stopping should retain the selected stream", conductor):
		return false
	if not _expect(is_zero_approx(conductor.song_position()), "stopping should reset the song clock", conductor):
		return false
	conductor.start_from(0.0)
	var retained := _expect(conductor.current_stream() == selected, "restarting should keep the selected stream", conductor)
	conductor.stop_song()
	await create_timer(0.5).timeout
	conductor.free()
	await process_frame
	return retained

func _test_pause_resume_preserve_selected_stream() -> bool:
	var conductor := await _create_conductor()
	if not _has_stream_api(conductor):
		return _fail("AudioConductor should expose set_stream and current_stream", conductor)
	var selected := _load_custom_stream()
	if not _expect(conductor.set_stream(selected), "valid stream should be selected", conductor):
		return false
	conductor.start_from(1.0)
	conductor.pause_song()
	var paused_position: float = conductor.song_position()
	if not _expect(conductor.current_stream() == selected, "pausing should retain the selected stream", conductor):
		return false
	if not _expect(is_equal_approx(conductor.song_position(), paused_position), "song clock should remain fixed while paused", conductor):
		return false
	conductor.resume_song()
	var retained := _expect(conductor.current_stream() == selected, "resuming should retain the selected stream", conductor)
	conductor.stop_song()
	await create_timer(0.5).timeout
	conductor.free()
	await process_frame
	return retained

func _create_conductor() -> Node:
	var conductor: Node = AudioConductorScript.new()
	root.add_child(conductor)
	await process_frame
	return conductor

func _load_custom_stream() -> AudioStreamWAV:
	var path := ProjectSettings.globalize_path("res://assets/audio/music_dash_prototype.wav")
	return AudioStreamWAV.load_from_file(path)

func _has_stream_api(conductor: Node) -> bool:
	return conductor.has_method("set_stream") and conductor.has_method("current_stream")

func _expect(condition: bool, message: String, conductor: Node) -> bool:
	if condition:
		return true
	return _fail(message, conductor)

func _fail(message: String, conductor: Node) -> bool:
	push_error(message)
	if is_instance_valid(conductor):
		conductor.free()
	return false
