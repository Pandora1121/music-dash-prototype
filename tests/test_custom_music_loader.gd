extends SceneTree

const CustomMusicLoaderScript = preload("res://scripts/custom_music_loader.gd")
const TEST_DIR := "user://phase6a_loader_tests"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	_test_loads_and_analyzes_supported_wav()
	_test_rejects_non_wav_path()
	_test_rejects_missing_path()
	_test_propagates_analysis_failure()
	_cleanup()
	print("PASS: custom music loader")
	quit()

func _test_loads_and_analyzes_supported_wav() -> void:
	var path := ProjectSettings.globalize_path("res://assets/audio/music_dash_prototype.wav")
	var result: Dictionary = CustomMusicLoaderScript.new().load_file(path)
	assert(result.get("status") == &"ok", "supported WAV should load")
	assert(String(result.get("reason", "")).is_empty(), "successful load should have no failure reason")
	assert(result.get("stream") is AudioStreamWAV and not result.stream.data.is_empty(), "successful load should return audio samples")
	assert(result.get("analysis", {}).get("status") == &"ok", "successful load should return successful analysis")
	assert(result.get("path") == path, "successful load should retain the selected path")
	assert(result.get("display_name") == "music_dash_prototype.wav", "successful load should expose the file name")

func _test_rejects_non_wav_path() -> void:
	var path := ProjectSettings.globalize_path("res://project.godot")
	var result: Dictionary = CustomMusicLoaderScript.new().load_file(path)
	assert(result.get("status") == &"failed", "non-WAV path should be rejected")
	assert(not String(result.get("reason", "")).is_empty(), "non-WAV rejection should explain the failure")

func _test_rejects_missing_path() -> void:
	var path := ProjectSettings.globalize_path(TEST_DIR + "/missing.wav")
	var result: Dictionary = CustomMusicLoaderScript.new().load_file(path)
	assert(result.get("status") == &"failed", "missing WAV should be rejected")
	assert(not String(result.get("reason", "")).is_empty(), "missing-file rejection should explain the failure")

func _test_propagates_analysis_failure() -> void:
	var silent_path := ProjectSettings.globalize_path(TEST_DIR + "/silent.wav")
	var unsupported_path := ProjectSettings.globalize_path(TEST_DIR + "/unsupported.wav")
	var silent := AudioStreamWAV.new()
	silent.format = AudioStreamWAV.FORMAT_16_BITS
	silent.mix_rate = 44100
	silent.stereo = false
	silent.data.resize(44100 * 3 * 2)
	assert(silent.save_to_wav(silent_path) == OK, "silent fixture should save")
	var silent_result: Dictionary = CustomMusicLoaderScript.new().load_file(silent_path)
	assert(silent_result.get("status") == &"failed", "silent WAV should be rejected by analysis")
	assert(not String(silent_result.get("reason", "")).is_empty(), "analysis failure should surface its reason")
	var unsupported := AudioStreamWAV.new()
	unsupported.format = AudioStreamWAV.FORMAT_8_BITS
	unsupported.mix_rate = 44100
	unsupported.stereo = false
	unsupported.data.resize(44100 * 3)
	assert(unsupported.save_to_wav(unsupported_path) == OK, "unsupported-depth fixture should save")
	var unsupported_result: Dictionary = CustomMusicLoaderScript.new().load_file(unsupported_path)
	assert(unsupported_result.get("status") == &"failed", "unsupported PCM depth should be rejected")
	assert(not String(unsupported_result.get("reason", "")).is_empty(), "unsupported PCM should surface an analysis reason")

func _cleanup() -> void:
	for file_name in ["silent.wav", "unsupported.wav"]:
		var path := ProjectSettings.globalize_path(TEST_DIR + "/" + file_name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
