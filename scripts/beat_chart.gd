extends RefCounted
class_name BeatChart

var _next_beat_index := 0

func beat_time(index: int, bpm: float, offset_seconds: float = 0.0) -> float:
	if bpm <= 0.0:
		return INF
	return float(index) * 60.0 / bpm + offset_seconds

func drain_beats_until(position: float, bpm: float, offset_seconds: float = 0.0) -> Array[int]:
	var beats: Array[int] = []
	if bpm <= 0.0:
		return beats
	while beat_time(_next_beat_index, bpm, offset_seconds) <= position:
		beats.append(_next_beat_index)
		_next_beat_index += 1
	return beats

func seek(position: float, bpm: float, offset_seconds: float = 0.0) -> void:
	_next_beat_index = 0
	if bpm <= 0.0:
		return
	while beat_time(_next_beat_index, bpm, offset_seconds) < position - 0.000001:
		_next_beat_index += 1

func reset() -> void:
	_next_beat_index = 0
