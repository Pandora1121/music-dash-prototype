extends SceneTree

const RunScorerScript = preload("res://scripts/run_scorer.gd")

func _initialize() -> void:
	_test_judgment_windows_are_symmetric()
	_test_outside_window_does_not_consume_target()
	_test_missed_target_cannot_be_recovered()
	_test_each_target_scores_once()
	_test_combo_multiplier_and_cap()
	_test_accuracy_and_empty_chart()
	_test_summary_does_not_finalize_targets()
	_test_invalid_target_times_are_rejected()
	_test_next_target_tracks_scoring_cursor()
	print("PASS: run scorer")
	quit()

func _test_judgment_windows_are_symmetric() -> void:
	for timing_case in [
		{"error": 0.045, "judgment": &"Perfect"},
		{"error": -0.045, "judgment": &"Perfect"},
		{"error": 0.04501, "judgment": &"Great"},
		{"error": -0.04501, "judgment": &"Great"},
		{"error": 0.090, "judgment": &"Great"},
		{"error": -0.090, "judgment": &"Great"},
		{"error": 0.09001, "judgment": &"Good"},
		{"error": -0.09001, "judgment": &"Good"},
		{"error": 0.150, "judgment": &"Good"},
		{"error": -0.150, "judgment": &"Good"},
	]:
		var scorer: RefCounted = RunScorerScript.new()
		assert(scorer.configure([2.0]), "valid target should configure")
		var judgment: Dictionary = scorer.record_jump(2.0 + timing_case.error)
		assert(judgment.get("judgment", &"") == timing_case.judgment, "timing window should be symmetric and include its boundary")

func _test_outside_window_does_not_consume_target() -> void:
	var scorer: RefCounted = RunScorerScript.new()
	assert(scorer.configure([2.0, 4.0]), "valid targets should configure")
	assert(scorer.record_jump(1.849999).is_empty(), "an early jump outside Good should not judge the future target")
	var judgment: Dictionary = scorer.record_jump(1.85)
	assert(judgment.get("judgment", &"") == &"Good", "target should remain available for a valid early Good")
	assert(scorer.record_jump(4.150001).is_empty(), "a late jump outside Good should not score")
	assert(scorer.advance_to(4.150001).is_empty(), "recording the late jump should resolve the target once as Miss")
	assert(scorer.finalize().miss == 1, "late window should count one Miss")

func _test_missed_target_cannot_be_recovered() -> void:
	var scorer: RefCounted = RunScorerScript.new()
	assert(scorer.configure([1.0]), "valid target should configure")
	var resolved: Array[Dictionary] = scorer.advance_to(1.150001)
	assert(resolved.size() == 1 and resolved[0].judgment == &"Miss", "expired target should become Miss")
	assert(scorer.record_jump(1.15).is_empty(), "a resolved Miss must not become a later hit")
	assert(scorer.advance_to(2.0).is_empty(), "a target must not emit Miss twice")

func _test_each_target_scores_once() -> void:
	var scorer: RefCounted = RunScorerScript.new()
	assert(scorer.configure([1.0]), "valid target should configure")
	assert(scorer.record_jump(1.0).judgment == &"Perfect", "first jump should score target")
	assert(scorer.record_jump(1.0).is_empty(), "second jump cannot reuse target")
	assert(scorer.finalize().perfect == 1, "target should count once")

func _test_combo_multiplier_and_cap() -> void:
	var target_times: Array[float] = []
	for index in range(101):
		target_times.append(float(index + 1))
	var scorer: RefCounted = RunScorerScript.new()
	assert(scorer.configure(target_times), "ordered targets should configure")
	var eleventh: Dictionary
	var hundred_first: Dictionary
	for index in range(target_times.size()):
		var judgment: Dictionary = scorer.record_jump(float(index + 1))
		if index == 10:
			eleventh = judgment
		elif index == 100:
			hundred_first = judgment
	assert(eleventh.multiplier == 1.1 and eleventh.points == 1100, "combo of ten should grant the next hit a 1.1 multiplier")
	assert(hundred_first.multiplier == 2.0 and hundred_first.points == 2000, "multiplier should cap at 2x")
	assert(scorer.finalize().best_combo == 101, "best combo should include every successful hit")

func _test_accuracy_and_empty_chart() -> void:
	var scorer: RefCounted = RunScorerScript.new()
	assert(scorer.configure([1.0, 2.0, 3.0, 4.0]), "valid targets should configure")
	scorer.record_jump(1.0)
	scorer.record_jump(2.09)
	scorer.record_jump(3.15)
	scorer.advance_to(4.150001)
	var summary: Dictionary = scorer.finalize()
	assert(summary.perfect == 1 and summary.great == 1 and summary.good == 1 and summary.miss == 1, "summary should count each judgment class")
	assert(is_equal_approx(summary.accuracy, 0.5625), "accuracy should weight each resolved target")
	var empty_scorer: RefCounted = RunScorerScript.new()
	assert(empty_scorer.configure([]), "empty target chart should be valid")
	var empty_summary: Dictionary = empty_scorer.finalize()
	assert(empty_summary.accuracy == 0.0 and empty_summary.miss == 0, "empty chart should have zero accuracy and no misses")

func _test_invalid_target_times_are_rejected() -> void:
	var scorer: RefCounted = RunScorerScript.new()
	assert(not scorer.configure([1.0, 1.0]), "duplicate target times should be rejected")
	assert(not scorer.configure([NAN]), "non-finite target times should be rejected")
	assert(not scorer.configure([-0.1]), "negative target times should be rejected")
	assert(not scorer.configure([1.0, INF]), "mixed valid and non-finite targets should be rejected")
	assert(scorer.finalize().miss == 0, "invalid chart should not retain a partial target list")

func _test_next_target_tracks_scoring_cursor() -> void:
	var scorer: RefCounted = RunScorerScript.new()
	assert(scorer.configure([1.0, 2.0]), "valid targets should configure")
	assert(scorer.has_method("next_target_time"), "scorer should expose its next unresolved hit time")
	if not scorer.has_method("next_target_time"):
		return
	assert(is_equal_approx(float(scorer.call("next_target_time")), 1.0), "first unresolved hit should be returned")
	scorer.record_jump(1.0)
	assert(is_equal_approx(float(scorer.call("next_target_time")), 2.0), "successful judgment should advance the next hit cue")
	scorer.advance_to(2.150001)
	assert(float(scorer.call("next_target_time")) == -1.0, "missed final hit should exhaust the cue")

func _test_summary_does_not_finalize_targets() -> void:
	var scorer: RefCounted = RunScorerScript.new()
	scorer.configure([1.0, 2.0])
	scorer.record_jump(1.0)
	var current: Dictionary = scorer.get_summary()
	assert(current.score == 1000 and current.miss == 0, "live summary should not finalize remaining chart targets")
	assert(scorer.finalize().miss == 1, "terminal summary should finalize remaining targets")
