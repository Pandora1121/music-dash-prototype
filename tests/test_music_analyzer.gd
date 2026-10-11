extends SceneTree

const MusicAnalyzer = preload("res://scripts/music_analyzer.gd")

func _initialize() -> void:
	var analyzer: RefCounted = MusicAnalyzer.new()
	var stream: AudioStreamWAV = load("res://assets/audio/music_dash_prototype.wav") as AudioStreamWAV
	var analysis_started := Time.get_ticks_msec()
	var analysis: Dictionary = analyzer.analyze(stream)
	var analysis_elapsed_ms := Time.get_ticks_msec() - analysis_started
	print("ANALYZER: bpm=%.3f confidence=%.3f elapsed_ms=%d status=%s" % [analysis.bpm, analysis.confidence, analysis_elapsed_ms, analysis.status])
	assert(analysis_elapsed_ms < 10000, "bundled track analysis should finish within 10 seconds")
	assert(analysis.status == &"ok", "bundled prototype WAV should analyze successfully")
	assert(absf(analysis.bpm - 120.0) <= 2.0, "prototype song tempo should be near 120 BPM")
	assert(analysis.beat_times.size() > 8, "analysis should expose multiple beat timestamps")
	for index in range(1, analysis.beat_times.size()):
		assert(analysis.beat_times[index] > analysis.beat_times[index - 1], "beat timestamps should increase")
	for feature in analysis.beat_features:
		for key in ["onset", "bass", "mid", "treble", "intensity"]:
			assert(is_finite(float(feature[key])) and feature[key] >= 0.0 and feature[key] <= 1.0, "beat features should be finite and normalized")
	assert(analyzer.analyze(null).status == &"failed", "null audio should fail cleanly")
	assert(analyzer.analyze(_make_stream(PackedByteArray(), AudioStreamWAV.FORMAT_16_BITS)).status == &"failed", "empty audio should fail cleanly")
	assert(analyzer.analyze(_make_silence(3.0)).status == &"failed", "silent audio should fail cleanly")
	assert(analyzer.analyze(_make_silence(0.5)).status == &"failed", "too-short audio should fail cleanly")
	assert(analyzer.analyze(_make_stream(PackedByteArray([0, 0, 0, 0]), AudioStreamWAV.FORMAT_8_BITS)).status == &"failed", "unsupported PCM depth should fail cleanly")
	print("PASS: music analyzer")
	quit()

func _make_stream(samples: PackedByteArray, sample_format: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = sample_format
	stream.mix_rate = 44100
	stream.stereo = false
	stream.data = samples
	return stream

func _make_silence(duration: float) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(int(44100.0 * duration) * 2)
	return _make_stream(bytes, AudioStreamWAV.FORMAT_16_BITS)
