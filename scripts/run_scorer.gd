extends RefCounted
class_name RunScorer

const PERFECT_WINDOW := 0.045
const GREAT_WINDOW := 0.090
const GOOD_WINDOW := 0.150
const WINDOW_EPSILON := 0.000001

var _targets: Array[float] = []
var _cursor := 0
var _score := 0
var _perfect := 0
var _great := 0
var _good := 0
var _miss := 0
var _combo := 0
var _best_combo := 0
var _accuracy_weight := 0.0

func configure(target_times: Array) -> bool:
	_reset()
	var previous := -INF
	for raw_time in target_times:
		if typeof(raw_time) not in [TYPE_INT, TYPE_FLOAT]:
			return false
		var target := float(raw_time)
		if not is_finite(target) or target < 0.0 or target <= previous:
			return false
		_targets.append(target)
		previous = target
	return true

func advance_to(song_position: float) -> Array[Dictionary]:
	var judgments: Array[Dictionary] = []
	if not is_finite(song_position):
		return judgments
	while _cursor < _targets.size() and song_position > _targets[_cursor] + GOOD_WINDOW + WINDOW_EPSILON:
		judgments.append(_record_miss(_cursor, song_position - _targets[_cursor]))
		_cursor += 1
	return judgments

func record_jump(song_position: float) -> Dictionary:
	if not is_finite(song_position) or song_position < 0.0:
		return {}
	advance_to(song_position)
	if _cursor >= _targets.size():
		return {}
	var timing_error := song_position - _targets[_cursor]
	if timing_error < -GOOD_WINDOW - WINDOW_EPSILON or timing_error > GOOD_WINDOW + WINDOW_EPSILON:
		return {}
	var absolute_error := absf(timing_error)
	var judgment: StringName
	var base_points: int
	var weight: float
	if absolute_error <= PERFECT_WINDOW + WINDOW_EPSILON:
		judgment = &"Perfect"
		base_points = 1000
		weight = 1.0
		_perfect += 1
	elif absolute_error <= GREAT_WINDOW + WINDOW_EPSILON:
		judgment = &"Great"
		base_points = 700
		weight = 0.75
		_great += 1
	else:
		judgment = &"Good"
		base_points = 400
		weight = 0.5
		_good += 1
	var multiplier := minf(2.0, 1.0 + floor(float(_combo) / 10.0) * 0.1)
	var points := roundi(float(base_points) * multiplier)
	_score += points
	_combo += 1
	_best_combo = maxi(_best_combo, _combo)
	_accuracy_weight += weight
	var record := _judgment_record(judgment, _cursor, timing_error, points, multiplier)
	_cursor += 1
	return record

func finalize() -> Dictionary:
	while _cursor < _targets.size():
		_record_miss(_cursor, GOOD_WINDOW)
		_cursor += 1
	return _summary()

func _record_miss(target_index: int, timing_error: float) -> Dictionary:
	_miss += 1
	_combo = 0
	var record := _judgment_record(&"Miss", target_index, timing_error, 0, 1.0)
	return record

func _judgment_record(judgment: StringName, target_index: int, timing_error: float, points: int, multiplier: float) -> Dictionary:
	return {
		"judgment": judgment,
		"target_index": target_index,
		"timing_error": timing_error,
		"points": points,
		"score": _score,
		"combo": _combo,
		"multiplier": multiplier,
	}

func _summary() -> Dictionary:
	var resolved := _perfect + _great + _good + _miss
	var accuracy := _accuracy_weight / float(resolved) if resolved > 0 else 0.0
	return {
		"score": _score,
		"accuracy": accuracy,
		"perfect": _perfect,
		"great": _great,
		"good": _good,
		"miss": _miss,
		"combo": _combo,
		"best_combo": _best_combo,
	}

func _reset() -> void:
	_targets.clear()
	_cursor = 0
	_score = 0
	_perfect = 0
	_great = 0
	_good = 0
	_miss = 0
	_combo = 0
	_best_combo = 0
	_accuracy_weight = 0.0
