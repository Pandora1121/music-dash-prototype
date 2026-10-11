extends RefCounted

const WINDOW_SIZE := 128
const HOP_SIZE := 128
const MIN_DURATION_SECONDS := 2.0
const MIN_SAMPLE_RATE := 8000
const MAX_SAMPLE_RATE := 192000
const BAND_FREQUENCIES := {
	"bass": [120.0],
	"mid": [600.0],
	"treble": [2200.0],
}

func analyze(stream: AudioStreamWAV) -> Dictionary:
	if stream == null:
		return _failure("Audio stream is missing.")
	if stream.format != AudioStreamWAV.FORMAT_16_BITS:
		return _failure("Only uncompressed 16-bit PCM WAV audio is supported.")
	if stream.mix_rate < MIN_SAMPLE_RATE or stream.mix_rate > MAX_SAMPLE_RATE:
		return _failure("Sample rate is outside the supported range.")
	var bytes_per_frame := 4 if stream.stereo else 2
	var pcm_data: PackedByteArray = stream.data
	if pcm_data.is_empty() or pcm_data.size() % bytes_per_frame != 0:
		return _failure("PCM sample data is empty or malformed.")
	var source_frame_count := pcm_data.size() / bytes_per_frame
	var duration := float(source_frame_count) / float(stream.mix_rate)
	if duration < MIN_DURATION_SECONDS:
		return _failure("Audio is too short to estimate a stable tempo.")

	var sample_stride := 4 if stream.mix_rate >= 20000 else (2 if stream.mix_rate >= 10000 else 1)
	var analysis_sample_rate := floori(float(stream.mix_rate) / float(sample_stride))
	var frame_count := floori(float(source_frame_count) / float(sample_stride))
	var mono := PackedFloat32Array()
	mono.resize(frame_count)
	var squared_prefix := PackedFloat32Array()
	squared_prefix.resize(frame_count + 1)
	for frame in range(frame_count):
		var byte_offset := frame * sample_stride * bytes_per_frame
		var sample_int := int(pcm_data[byte_offset]) | (int(pcm_data[byte_offset + 1]) << 8)
		if sample_int >= 32768:
			sample_int -= 65536
		var sample := float(sample_int) / 32768.0
		if stream.stereo:
			var right_int := int(pcm_data[byte_offset + 2]) | (int(pcm_data[byte_offset + 3]) << 8)
			if right_int >= 32768:
				right_int -= 65536
			sample = (sample + float(right_int) / 32768.0) * 0.5
		mono[frame] = sample
		squared_prefix[frame + 1] = squared_prefix[frame] + sample * sample

	var frame_features: Array[Dictionary] = []
	var raw_maxima := {"bass": 0.0, "mid": 0.0, "treble": 0.0, "intensity": 0.0}
	var last_bands := {"bass": 0.0, "mid": 0.0, "treble": 0.0}
	var feature_window_index := 0
	for start in range(0, frame_count - WINDOW_SIZE + 1, HOP_SIZE):
		var sum_squares := squared_prefix[start + WINDOW_SIZE] - squared_prefix[start]
		var rms := sqrt(sum_squares / float(WINDOW_SIZE))
		var bands: Dictionary = last_bands
		if feature_window_index % 4 == 0:
			bands = {}
			for band_name in BAND_FREQUENCIES:
				var band_energy := 0.0
				for frequency in BAND_FREQUENCIES[band_name]:
					if frequency < float(analysis_sample_rate) * 0.5:
						band_energy += _goertzel_energy(mono, start, analysis_sample_rate, frequency)
				bands[band_name] = sqrt(band_energy / float(BAND_FREQUENCIES[band_name].size()))
				raw_maxima[band_name] = maxf(raw_maxima[band_name], bands[band_name])
			last_bands = bands
		raw_maxima.intensity = maxf(raw_maxima.intensity, rms)
		frame_features.append({"time": float(start + WINDOW_SIZE / 2) / float(analysis_sample_rate), "rms": rms, "bands": bands, "onset": 0.0})
		feature_window_index += 1
	if frame_features.size() < 20 or raw_maxima.intensity < 0.0005:
		return _failure("Audio is silent or too short for analysis.")

	var onset_sum := 0.0
	var onset_max := 0.0
	for index in range(frame_features.size()):
		var previous_rms := float(frame_features[maxi(0, index - 1)].rms)
		var current_rms := float(frame_features[index].rms)
		var onset := maxf(0.0, current_rms - previous_rms)
		frame_features[index].onset = onset
		onset_sum += onset
		onset_max = maxf(onset_max, onset)
	if onset_max < 0.00005 or onset_sum < 0.001:
		return _failure("Audio has no stable onset pattern.")

	var bpm_result := _estimate_bpm(frame_features, float(HOP_SIZE) / float(analysis_sample_rate))
	if float(bpm_result.confidence) < 0.06:
		return _failure("No sufficiently confident tempo candidate was found.")
	var beat_interval := 60.0 / float(bpm_result.bpm)
	var phase := _find_phase(frame_features, beat_interval)
	var beat_times: Array[float] = []
	var beat_features: Array[Dictionary] = []
	var beat_time := phase
	while beat_time < duration:
		var nearest_index := clampi(roundi((beat_time - float(frame_features[0].time)) / (float(HOP_SIZE) / float(analysis_sample_rate))), 0, frame_features.size() - 1)
		var source: Dictionary = frame_features[nearest_index]
		var bands: Dictionary = source.bands
		beat_times.append(beat_time)
		beat_features.append({
			"onset": clampf(float(source.onset) / onset_max, 0.0, 1.0),
			"bass": _normalize(float(bands.bass), float(raw_maxima.bass)),
			"mid": _normalize(float(bands.mid), float(raw_maxima.mid)),
			"treble": _normalize(float(bands.treble), float(raw_maxima.treble)),
			"intensity": _normalize(float(source.rms), float(raw_maxima.intensity)),
		})
		beat_time += beat_interval
	return {
		"status": &"ok",
		"reason": "",
		"bpm": float(bpm_result.bpm),
		"confidence": float(bpm_result.confidence),
		"duration_seconds": duration,
		"beat_times": beat_times,
		"beat_features": beat_features,
		"sections": _build_sections(beat_features),
	}

func _failure(reason: String) -> Dictionary:
	return {"status": &"failed", "reason": reason, "bpm": 0.0, "confidence": 0.0, "duration_seconds": 0.0, "beat_times": [], "beat_features": [], "sections": []}

func _normalize(value: float, maximum: float) -> float:
	return clampf(value / maximum, 0.0, 1.0) if maximum > 0.000001 else 0.0

func _goertzel_energy(samples: PackedFloat32Array, start: int, sample_rate: int, frequency: float) -> float:
	var coefficient := 2.0 * cos(TAU * frequency / float(sample_rate))
	var previous := 0.0
	var previous_previous := 0.0
	for index in range(start, start + WINDOW_SIZE):
		var current := float(samples[index]) + coefficient * previous - previous_previous
		previous_previous = previous
		previous = current
	return maxf(0.0, previous * previous + previous_previous * previous_previous - coefficient * previous * previous_previous)

func _estimate_bpm(features: Array[Dictionary], frame_seconds: float) -> Dictionary:
	var onset_count := features.size()
	var min_lag := maxi(1, roundi(60.0 / 180.0 / frame_seconds))
	var max_lag := mini(onset_count / 2, roundi(60.0 / 60.0 / frame_seconds))
	var best_lag := 0
	var best_score := 0.0
	var second_score := 0.0
	var scores: Array[float] = []
	for lag in range(min_lag, max_lag + 1):
		var correlation := 0.0
		var energy := 0.0
		for index in range(lag, onset_count):
			var current := float(features[index].onset)
			var previous := float(features[index - lag].onset)
			correlation += current * previous
			energy += current * current
		var score := correlation / maxf(energy, 0.000001)
		scores.append(score)
		if score > best_score:
			second_score = best_score
			best_score = score
			best_lag = lag
		elif score > second_score and lag != best_lag:
			second_score = score
	if best_lag == 0:
		return {"bpm": 0.0, "confidence": 0.0}
	var refined_lag := float(best_lag)
	var peak_index := best_lag - min_lag
	if peak_index > 0 and peak_index < scores.size() - 1:
		var left_score := scores[peak_index - 1]
		var center_score := scores[peak_index]
		var right_score := scores[peak_index + 1]
		var curvature := left_score - 2.0 * center_score + right_score
		if absf(curvature) > 0.000001:
			refined_lag += clampf(0.5 * (left_score - right_score) / curvature, -0.5, 0.5)
	# Drum patterns can repeat every other beat, producing an octave-low peak.
	# In the ambiguous slow-tempo range, prefer the common double-time reading.
	var half_lag := roundi(refined_lag * 0.5)
	if 60.0 / (refined_lag * frame_seconds) < 80.0 and half_lag >= min_lag:
		var half_correlation := 0.0
		var half_energy := 0.0
		for index in range(half_lag, onset_count):
			var current := float(features[index].onset)
			var previous := float(features[index - half_lag].onset)
			half_correlation += current * previous
			half_energy += current * current
		var half_score := half_correlation / maxf(half_energy, 0.000001)
		if half_score >= best_score * 0.20 or best_score >= 0.5:
			refined_lag *= 0.5
	var bpm := 60.0 / (refined_lag * frame_seconds)
	var confidence := clampf(best_score * (1.0 - minf(0.8, second_score * 0.25)), 0.0, 1.0)
	return {"bpm": bpm, "confidence": confidence}

func _find_phase(features: Array[Dictionary], beat_interval: float) -> float:
	var best_onset := 0.0
	var phase := 0.0
	for feature in features:
		var time := float(feature.time)
		if time > beat_interval:
			break
		if float(feature.onset) > best_onset:
			best_onset = float(feature.onset)
			phase = time
	return maxf(0.0, phase)

func _build_sections(beat_features: Array[Dictionary]) -> Array[Dictionary]:
	var sections: Array[Dictionary] = []
	for start in range(0, beat_features.size(), 16):
		var end := mini(start + 16, beat_features.size())
		var intensity_sum := 0.0
		for index in range(start, end):
			intensity_sum += float(beat_features[index].intensity)
		var average := intensity_sum / float(end - start)
		var label: StringName = &"calm" if average < 0.34 else (&"build" if average < 0.68 else &"peak")
		sections.append({"start_beat": start, "end_beat": end - 1, "intensity": average, "label": label})
	return sections
