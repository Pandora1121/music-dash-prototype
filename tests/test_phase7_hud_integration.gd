extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const RunScorerScript = preload("res://scripts/run_scorer.gd")

func _initialize() -> void:
	var main: Control = MainScene.instantiate()
	main.set("progression_profile_path", "user://phase7_hud_profile.json")
	root.add_child(main)
	await process_frame
	main.call("_build_hud")
	if not _expect(main.get("_next_hit_label") is Label, "game HUD should show a live next-hit cue", main):
		return
	if not _expect(main.get("_combo_meter") is ProgressBar, "game HUD should show combo milestone progress", main):
		return
	var scorer: RefCounted = RunScorerScript.new()
	assert(scorer.configure([1.0, 2.0]), "HUD fixture should have two targets")
	main.set("_scorer", scorer)
	main.call("_update_hud_stats")
	main.call("_update_timing_hud", 0.4)
	if not _expect(main.get("_next_hit_label").text == "JUMP IN 0.60s", "HUD should count down to the next score beat", main):
		return
	main.call("_update_timing_hud", 0.9)
	if not _expect(main.get("_next_hit_label").text == "JUMP NOW", "HUD should call out the Good timing window", main):
		return
	main.call("_on_player_jumped", 1.0)
	if not _expect(float(main.get("_combo_meter").value) == 1.0 and String(main.get("combo_label").text).contains("01"), "successful timing should advance combo feedback", main):
		return
	if not _expect(main.get("_next_hit_label").text == "JUMP IN 1.00s", "successful hit should advance the cue to the following beat", main):
		return
	main.call("_on_player_jumped", 2.151)
	if not _expect(main.get("judgment_label").text == "MISS" and main.get("_next_hit_label").text == "MISS • COMBO RESET", "miss should clearly show that the combo broke", main):
		return
	main.set("_miss_feedback_remaining", 0.0)
	main.call("_update_timing_hud", 2.3)
	if not _expect(main.get("_next_hit_label").text == "CHART CLEAR", "cue should stop after all score targets resolve", main):
		return
	main.get_node("AudioConductor").call("stop_song")
	await create_timer(0.2).timeout
	main.free()
	print("PASS: phase 7 HUD integration")
	quit(0)

func _expect(condition: bool, message: String, main: Control) -> bool:
	if condition:
		return true
	push_error(message)
	var conductor := main.get_node_or_null("AudioConductor")
	if is_instance_valid(conductor):
		conductor.call("stop_song")
	main.free()
	quit(1)
	return false
