extends RefCounted

const MIN_REACTION_SECONDS := 0.8
const COLLISION_WIDTH_PIXELS := 48.0
const PLAYER_WARNING_DISTANCE_PIXELS := 1120.0

func generate(analysis: Dictionary, difficulty: StringName, seed: int, scroll_speed: float) -> Dictionary:
	if not _is_valid_analysis(analysis) or not is_finite(scroll_speed) or scroll_speed <= 0.0:
		return _failure("Analysis or scroll speed is invalid.")
	var density := _density_for(difficulty)
	if density <= 0.0:
		return _failure("Unsupported difficulty.")
	var beat_times: Array = analysis.beat_times
	var beat_features: Array = analysis.beat_features
	if beat_times.size() != beat_features.size() or beat_times.is_empty():
		return _failure("Analysis beat data is incomplete.")

	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var events: Array[Dictionary] = []
	var warning_time := PLAYER_WARNING_DISTANCE_PIXELS / scroll_speed
	var minimum_target_gap := MIN_REACTION_SECONDS + COLLISION_WIDTH_PIXELS / scroll_speed
	var last_target_time := -INF
	for beat_index in range(beat_times.size()):
		var hit_time := float(beat_times[beat_index])
		if not is_finite(hit_time) or hit_time < warning_time:
			continue
		if hit_time - last_target_time < minimum_target_gap:
			continue
		var features: Dictionary = beat_features[beat_index]
		var onset := clampf(float(features.get("onset", 0.0)), 0.0, 1.0)
		var intensity := clampf(float(features.get("intensity", 0.0)), 0.0, 1.0)
		var musical_strength := maxf(0.15, onset * 0.65 + intensity * 0.35)
		if rng.randf() > density * (0.35 + musical_strength * 0.65):
			continue
		var bass := clampf(float(features.get("bass", 0.0)), 0.0, 1.0)
		var treble := clampf(float(features.get("treble", 0.0)), 0.0, 1.0)
		var kind: StringName = &"block" if bass > treble + 0.12 else &"spike"
		if absf(bass - treble) <= 0.12:
			kind = &"block" if rng.randf() < 0.5 else &"spike"
		events.append({"beat_index": beat_index, "kind": kind})
		last_target_time = hit_time

	return {
		"status": &"ok",
		"reason": "",
		"seed": seed,
		"difficulty": difficulty,
		"bpm": float(analysis.bpm),
		"duration_seconds": float(analysis.duration_seconds),
		"beat_times": beat_times.duplicate(),
		"events": events,
	}

func _is_valid_analysis(analysis: Dictionary) -> bool:
	if analysis.get("status", &"failed") != &"ok":
		return false
	var bpm_value: Variant = analysis.get("bpm", 0.0)
	var confidence_value: Variant = analysis.get("confidence", 0.0)
	var duration_value: Variant = analysis.get("duration_seconds", 0.0)
	var times_value: Variant = analysis.get("beat_times", null)
	var features_value: Variant = analysis.get("beat_features", null)
	if not _is_finite_number(bpm_value) or not _is_finite_number(confidence_value) or not _is_finite_number(duration_value):
		return false
	if float(bpm_value) <= 0.0 or float(confidence_value) < 0.06 or float(confidence_value) > 1.0 or float(duration_value) <= 0.0 or not (times_value is Array) or not (features_value is Array):
		return false
	var beat_times: Array = times_value
	var beat_features: Array = features_value
	if beat_times.is_empty() or beat_times.size() != beat_features.size():
		return false
	var previous_time := -INF
	for index in range(beat_times.size()):
		var beat_time: Variant = beat_times[index]
		var features: Variant = beat_features[index]
		if not _is_finite_number(beat_time) or float(beat_time) <= previous_time or not (features is Dictionary):
			return false
		previous_time = float(beat_time)
		for key in ["onset", "bass", "mid", "treble", "intensity"]:
			if not features.has(key) or not _is_finite_number(features[key]) or float(features[key]) < 0.0 or float(features[key]) > 1.0:
				return false
	return true

func _is_finite_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))

func _density_for(difficulty: StringName) -> float:
	match difficulty:
		&"Easy": return 0.2
		&"Normal": return 0.34
		&"Hard": return 0.48
		&"Expert": return 0.62
		&"Insane": return 0.76
		_: return 0.0

func _failure(reason: String) -> Dictionary:
	return {"status": &"failed", "reason": reason, "seed": 0, "difficulty": &"", "bpm": 0.0, "duration_seconds": 0.0, "beat_times": [], "events": []}
