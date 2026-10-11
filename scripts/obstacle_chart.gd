extends RefCounted

const BEATS_PER_MINUTE := 120.0
const EVENTS: Array[Dictionary] = [
	{"beat_index": 8, "kind": &"spike"},
	{"beat_index": 12, "kind": &"spike"},
	{"beat_index": 16, "kind": &"block"},
	{"beat_index": 20, "kind": &"spike"},
	{"beat_index": 24, "kind": &"block"},
	{"beat_index": 28, "kind": &"spike"},
	{"beat_index": 32, "kind": &"spike"},
	{"beat_index": 36, "kind": &"block"},
]

func events() -> Array[Dictionary]:
	return EVENTS.duplicate(true)

func minimum_reaction_time(bpm: float, scroll_speed: float) -> float:
	if bpm <= 0.0 or scroll_speed <= 0.0 or EVENTS.size() < 2:
		return 0.0
	var smallest_gap := INF
	for index in range(1, EVENTS.size()):
		var beats_between: int = EVENTS[index].beat_index - EVENTS[index - 1].beat_index
		var time_between := float(beats_between) * 60.0 / bpm
		smallest_gap = minf(smallest_gap, time_between)
	return smallest_gap - 48.0 / scroll_speed
