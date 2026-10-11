extends RefCounted
class_name ProgressionStore

const PROFILE_VERSION := 1
const MAX_STORED_SCORE := 2147483647
const DIFFICULTIES: Array[StringName] = [&"Easy", &"Normal", &"Hard", &"Expert", &"Insane"]

var _unlocked_index := 0
var _best_scores: Dictionary = {}
var _completed: Dictionary = {}

func _init() -> void:
	_reset_to_defaults()

func load_profile(path: String = "user://music_dash_profile.json") -> bool:
	_reset_to_defaults()
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var json := JSON.new()
	var parse_error: Error = json.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return false
	var parsed: Variant = json.data
	if not (parsed is Dictionary) or not _is_valid_profile(parsed):
		return false
	_unlocked_index = int(parsed.unlocked_index)
	for difficulty in DIFFICULTIES:
		var entry: Dictionary = parsed.difficulties[String(difficulty)]
		_best_scores[difficulty] = int(entry.best_score)
		_completed[difficulty] = bool(entry.completed)
	return true

func unlocked_difficulty() -> StringName:
	return DIFFICULTIES[_unlocked_index]

func is_unlocked(difficulty: StringName) -> bool:
	var index := DIFFICULTIES.find(difficulty)
	return index >= 0 and index <= _unlocked_index

func best_score(difficulty: StringName) -> int:
	return int(_best_scores.get(difficulty, 0))

func record_run(difficulty: StringName, score: int, completed: bool, path: String = "user://music_dash_profile.json") -> bool:
	if not is_unlocked(difficulty) or score < 0:
		return false
	var difficulty_index := DIFFICULTIES.find(difficulty)
	_best_scores[difficulty] = maxi(int(_best_scores.get(difficulty, 0)), score)
	if completed:
		_completed[difficulty] = true
		_unlocked_index = maxi(_unlocked_index, mini(difficulty_index + 1, DIFFICULTIES.size() - 1))
	return _save_profile(path)

func _save_profile(path: String) -> bool:
	var difficulty_data: Dictionary = {}
	for difficulty in DIFFICULTIES:
		difficulty_data[String(difficulty)] = {
			"best_score": int(_best_scores.get(difficulty, 0)),
			"completed": bool(_completed.get(difficulty, false)),
		}
	var profile := {
		"version": PROFILE_VERSION,
		"unlocked_index": _unlocked_index,
		"difficulties": difficulty_data,
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(profile, "\t"))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	return write_error == OK

func _is_valid_profile(profile: Dictionary) -> bool:
	if not _is_integer_number(profile.get("version")) or int(profile.version) != PROFILE_VERSION:
		return false
	if not _is_integer_number(profile.get("unlocked_index")):
		return false
	var unlock_index := int(profile.unlocked_index)
	if unlock_index < 0 or unlock_index >= DIFFICULTIES.size():
		return false
	if not (profile.get("difficulties") is Dictionary):
		return false
	var difficulties: Dictionary = profile.difficulties
	for difficulty in DIFFICULTIES:
		var key := String(difficulty)
		if not (difficulties.get(key) is Dictionary):
			return false
		var entry: Dictionary = difficulties[key]
		if not _is_integer_number(entry.get("best_score")) or int(entry.best_score) < 0 or float(entry.best_score) > MAX_STORED_SCORE:
			return false
		if typeof(entry.get("completed")) != TYPE_BOOL:
			return false
	return true

func _is_integer_number(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
		return false
	return floor(float(value)) == float(value)

func _reset_to_defaults() -> void:
	_unlocked_index = 0
	_best_scores.clear()
	_completed.clear()
	for difficulty in DIFFICULTIES:
		_best_scores[difficulty] = 0
		_completed[difficulty] = false
