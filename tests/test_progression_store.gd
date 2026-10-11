extends SceneTree

const ProgressionStoreScript = preload("res://scripts/progression_store.gd")
const TEST_DIR := "user://phase5_profile_tests"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	_test_default_profile_and_unlocks()
	_test_best_score_and_completion_round_trip()
	_test_crash_does_not_unlock()
	_test_unknown_difficulty_is_rejected()
	_test_corrupt_profiles_reset_to_default()
	_test_write_failure_preserves_memory()
	print("PASS: progression store")
	quit()

func _test_default_profile_and_unlocks() -> void:
	var path := TEST_DIR + "/missing.json"
	_remove_file(path)
	var store: RefCounted = ProgressionStoreScript.new()
	assert(not store.load_profile(path), "missing profile should report fresh defaults")
	assert(store.unlocked_difficulty() == &"Easy", "new profile should unlock Easy only")
	assert(store.is_unlocked(&"Easy"), "Easy should be available")
	assert(not store.is_unlocked(&"Normal"), "Normal should begin locked")
	assert(store.best_score(&"Easy") == 0, "missing best score should be zero")

func _test_best_score_and_completion_round_trip() -> void:
	var path := TEST_DIR + "/round_trip.json"
	_remove_file(path)
	var store: RefCounted = ProgressionStoreScript.new()
	store.load_profile(path)
	assert(store.record_run(&"Easy", 1200, true, path), "valid completion should save")
	assert(store.unlocked_difficulty() == &"Normal", "completing Easy should unlock Normal")
	assert(store.record_run(&"Easy", 800, false, path), "lower replay score should save profile")
	assert(store.best_score(&"Easy") == 1200, "best score should never decrease")
	var reloaded: RefCounted = ProgressionStoreScript.new()
	assert(reloaded.load_profile(path), "valid profile should load")
	assert(reloaded.best_score(&"Easy") == 1200, "best score should persist")
	assert(reloaded.unlocked_difficulty() == &"Normal", "unlock should persist")
	assert(reloaded.is_unlocked(&"Normal"), "next difficulty should remain unlocked")

func _test_crash_does_not_unlock() -> void:
	var path := TEST_DIR + "/crash.json"
	_remove_file(path)
	var store: RefCounted = ProgressionStoreScript.new()
	store.load_profile(path)
	assert(store.record_run(&"Easy", 700, false, path), "crashed run best score should save")
	assert(store.best_score(&"Easy") == 700, "crashed run score should be recorded")
	assert(store.unlocked_difficulty() == &"Easy", "crashing must not unlock Normal")

func _test_unknown_difficulty_is_rejected() -> void:
	var store: RefCounted = ProgressionStoreScript.new()
	store.load_profile(TEST_DIR + "/unknown.json")
	assert(not store.is_unlocked(&"Impossible"), "unknown difficulty should never be unlocked")
	assert(not store.record_run(&"Impossible", 500, true, TEST_DIR + "/unknown.json"), "unknown difficulty run should be rejected")

func _test_corrupt_profiles_reset_to_default() -> void:
	for fixture in [
		{"name": "bad_json", "text": "{bad json"},
		{"name": "bad_version", "text": JSON.stringify({"version": 99, "unlocked_index": 4, "difficulties": {}})},
		{"name": "bad_types", "text": JSON.stringify({"version": 1, "unlocked_index": "4", "difficulties": []})},
		{"name": "bad_range", "text": JSON.stringify({"version": 1, "unlocked_index": 4, "difficulties": {"Easy": {"best_score": -2, "completed": "yes"}}})},
	]:
		var path: String = TEST_DIR + "/%s.json" % fixture.name
		_write_text(path, fixture.text)
		var store: RefCounted = ProgressionStoreScript.new()
		assert(not store.load_profile(path), "malformed profile should not load as valid")
		assert(store.unlocked_difficulty() == &"Easy", "malformed profile should reset unlocked difficulty")
		assert(store.best_score(&"Easy") == 0, "malformed score should reset to zero")

func _test_write_failure_preserves_memory() -> void:
	var store: RefCounted = ProgressionStoreScript.new()
	store.load_profile(TEST_DIR + "/missing-for-write.json")
	var saved: bool = store.record_run(&"Easy", 850, false, "user://missing_parent_phase5/profile.json")
	assert(not saved, "write into a missing parent directory should fail")
	assert(store.best_score(&"Easy") == 850, "write failure should preserve in-memory result")
	assert(store.unlocked_difficulty() == &"Easy", "write failure should leave profile usable")

func _write_text(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "test fixture should open")
	file.store_string(value)
	file.close()

func _remove_file(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute_path)
