extends RefCounted
class_name GameplayProfile

const BASE_SCROLL_SPEED := 360.0
const MIN_SCROLL_SPEED := 280.0
const MAX_SCROLL_SPEED := 520.0
const DIFFICULTY_SPEED_FACTORS: Dictionary = {
	&"Easy": 0.88,
	&"Normal": 0.96,
	&"Hard": 1.04,
	&"Expert": 1.13,
	&"Insane": 1.22,
}
const DIFFICULTY_DENSITIES: Dictionary = {
	&"Easy": 0.18,
	&"Normal": 0.28,
	&"Hard": 0.40,
	&"Expert": 0.52,
	&"Insane": 0.64,
}

func profile_for(analysis: Dictionary, difficulty: StringName) -> Dictionary:
	if not DIFFICULTY_SPEED_FACTORS.has(difficulty):
		return _failure("Unsupported difficulty.")
	if analysis.get("status", &"failed") != &"ok":
		return _failure("Music analysis is not ready.")
	var bpm: Variant = analysis.get("bpm", null)
	if not _is_positive_finite(bpm):
		return _failure("Music BPM must be a positive finite number.")
	var raw_features: Variant = analysis.get("beat_features", null)
	if not (raw_features is Array) or raw_features.is_empty():
		return _failure("Music analysis does not contain beat intensity data.")
	var energy_total := 0.0
	for raw_feature in raw_features:
		if not (raw_feature is Dictionary) or not raw_feature.has("intensity") or not _is_finite_number(raw_feature.intensity):
			return _failure("Music beat intensity data is invalid.")
		var intensity := float(raw_feature.intensity)
		if intensity < 0.0 or intensity > 1.0:
			return _failure("Music beat intensity must be between zero and one.")
		energy_total += intensity
	var average_intensity := energy_total / float(raw_features.size())
	var bpm_factor := clampf(pow(float(bpm) / 120.0, 0.25), 0.85, 1.18)
	var speed := clampf(BASE_SCROLL_SPEED * bpm_factor * float(DIFFICULTY_SPEED_FACTORS[difficulty]), MIN_SCROLL_SPEED, MAX_SCROLL_SPEED)
	var energy_factor := 0.85 + 0.35 * average_intensity
	var density := clampf(float(DIFFICULTY_DENSITIES[difficulty]) * energy_factor, 0.15, 0.82)
	return {
		"status": &"ok",
		"reason": "",
		"bpm": float(bpm),
		"bpm_factor": bpm_factor,
		"average_intensity": average_intensity,
		"scroll_speed": speed,
		"density": density,
	}

func scroll_speed_for(bpm: float, difficulty: StringName) -> float:
	if not is_finite(bpm) or bpm <= 0.0 or not DIFFICULTY_SPEED_FACTORS.has(difficulty):
		return 0.0
	var bpm_factor := clampf(pow(bpm / 120.0, 0.25), 0.85, 1.18)
	return clampf(BASE_SCROLL_SPEED * bpm_factor * float(DIFFICULTY_SPEED_FACTORS[difficulty]), MIN_SCROLL_SPEED, MAX_SCROLL_SPEED)

func _is_finite_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))

func _is_positive_finite(value: Variant) -> bool:
	return _is_finite_number(value) and float(value) > 0.0

func _failure(reason: String) -> Dictionary:
	return {"status": &"failed", "reason": reason, "scroll_speed": 0.0, "density": 0.0, "average_intensity": 0.0, "bpm_factor": 0.0}
