# MUSIC DASH Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a playable Godot 4 rhythm action prototype for Windows with beat-timed obstacles, responsive jumping, score feedback, and restart.

**Architecture:** Use small Godot scenes for the main flow, player, level, and HUD. A central `AudioConductor` supplies audio-clock position and beat events; deterministic chart data drives obstacle placement, and pure timing/scoring logic stays testable without scene rendering.

**Tech Stack:** Godot 4.x, GDScript, built-in 2D nodes and audio. Optional prototype sound effects may use Kenney CC0 packs; gameplay visuals use simple built-in shapes.

**Spec:** `docs/superpowers/specs/2026-10-11-music-dash-design.md`

## Global Constraints

- Target Windows desktop; keep systems in separate scenes/scripts for later porting.
- Use Godot 4.x and GDScript without external runtime plugins.
- Keep the first level deterministic and authored as data.
- Use the audio playback position as gameplay's timing source; do not rely on frame delays as the clock.
- Optional assets must have a clear free license and recorded source; the game must run without them.
- The project must open and run in the Godot editor; Windows export requires matching export templates.

## Review Focus

- Pause/resume must not cause stale or duplicated beat events; test beat cursor restoration around pause and resume.
- A frame stall crossing multiple beat timestamps must process each due event once; test a multi-beat jump in song position.
- Restart must reset audio, chart cursor, obstacles, score, and combo; test repeated restarts.
- Unsupported or missing optional audio must leave the playable rhythm prototype usable; test its documented fallback.
- The last obstacle and song completion must transition cleanly to results without out-of-bounds chart access; test the final chart event.

---

### Task 1: Godot project scaffold and smoke test

**Files:**
- Create: `project.godot`
- Create: `scenes/main.tscn`
- Create: `scripts/main.gd`
- Create: `README.md`
- Create: `tests/test_project_smoke.gd`

**Interfaces:**
- Produces the runnable main scene and project settings used by all later tasks.

- [ ] **Step 1: Write the failing smoke test**

Create a headless `SceneTree` test that loads `res://scenes/main.tscn`, checks that it instantiates, and asserts the expected root scene exists.

- [ ] **Step 2: Run the test and confirm the expected failure**

Run: `godot --headless --path . --script res://tests/test_project_smoke.gd`
Expected: FAIL because the project scene does not exist yet.

- [ ] **Step 3: Add the minimal Godot project and main scene**

Set the main scene to `res://scenes/main.tscn`, configure a 1280x720 viewport, and add a minimal `Main` Control scene with a start button and a script that transitions into the gameplay placeholder.

- [ ] **Step 4: Run the smoke test**

Run: `godot --headless --path . --script res://tests/test_project_smoke.gd`
Expected: PASS and exit code 0.

### Task 2: Audio conductor and deterministic beat timeline

**Files:**
- Create: `scripts/audio_conductor.gd`
- Create: `scripts/beat_chart.gd`
- Create: `tests/test_beat_chart.gd`
- Modify: `tests/test_project_smoke.gd`

**Interfaces:**
- `BeatChart.beat_time(index: int, bpm: float, offset_seconds: float) -> float`
- `AudioConductor.song_position() -> float`
- `AudioConductor.consume_beats_until(position: float) -> Array[int]`
- `AudioConductor.start_from(position: float) -> void`
- `AudioConductor.pause_song() -> void`
- `AudioConductor.resume_song() -> void`

- [ ] **Step 1: Write failing tests**

In `test_beat_chart.gd`, assert a 120 BPM beat at index 4 is at 2 seconds with zero offset, a +0.1 second offset shifts it to 2.1 seconds, and consuming through 1.1 seconds at 120 BPM returns beat indices `[0, 1, 2]` exactly once.

- [ ] **Step 2: Run test and confirm expected failure**

Run: `godot --headless --path . --script res://tests/test_beat_chart.gd`
Expected: FAIL because `BeatChart` and `AudioConductor` are not implemented.

- [ ] **Step 3: Implement the beat clock**

Use `AudioStreamPlayer.get_playback_position()` plus `AudioServer.get_time_since_last_mix()` and subtract `AudioServer.get_output_latency()` for the audible playback clock. Maintain a beat cursor so `consume_beats_until()` drains every due beat once. Preserve the playback position on pause and reset the cursor on `start_from()`.

- [ ] **Step 4: Run beat tests and smoke test**

Run: `godot --headless --path . --script res://tests/test_beat_chart.gd` and `godot --headless --path . --script res://tests/test_project_smoke.gd`
Expected: both PASS.

### Task 3: Player movement and collision feedback

**Files:**
- Create: `scenes/player.tscn`
- Create: `scripts/player.gd`
- Create: `tests/test_player_rules.gd`
- Modify: `scenes/main.tscn`

**Interfaces:**
- Player input action `jump` maps Space and Up.
- Player signal `crashed` notifies the level controller on obstacle collision.
- Player signal `jumped(song_position: float)` reports jump timing for scoring.

- [ ] **Step 1: Write failing movement rule tests**

Add a test for jump eligibility (grounded jump succeeds, airborne jump is rejected) and crash state (a crash disables further movement until reset).

- [ ] **Step 2: Run test and confirm expected failure**

Run: `godot --headless --path . --script res://tests/test_player_rules.gd`
Expected: FAIL because player rules do not exist.

- [ ] **Step 3: Implement player scene and controls**

Implement a CharacterBody2D with a simple neon capsule/rectangle, gravity, one grounded jump, trail-like afterimage using built-in drawing, and a reset method. Emit `jumped` using the conductor's current song position.

- [ ] **Step 4: Run movement tests and project smoke test**

Run: `godot --headless --path . --script res://tests/test_player_rules.gd` and `godot --headless --path . --script res://tests/test_project_smoke.gd`
Expected: both PASS.

### Task 4: Fair authored chart and beat-driven obstacle lane

**Files:**
- Create: `scripts/obstacle_chart.gd`
- Create: `scenes/obstacle.tscn`
- Create: `scripts/obstacle.gd`
- Create: `scripts/level_controller.gd`
- Create: `tests/test_obstacle_chart.gd`
- Modify: `scenes/main.tscn`

**Interfaces:**
- `ObstacleChart.events() -> Array[Dictionary]`, each with `beat_index: int` and `kind: StringName`.
- `LevelController.reset_level() -> void`
- `LevelController.finish_level() -> void`

- [ ] **Step 1: Write failing chart tests**

Assert chart event beat indices are strictly increasing, all event types are supported, and minimum reaction time at the configured scroll speed is at least 0.8 seconds.

- [ ] **Step 2: Run test and confirm expected failure**

Run: `godot --headless --path . --script res://tests/test_obstacle_chart.gd`
Expected: FAIL because chart logic does not exist.

- [ ] **Step 3: Implement deterministic obstacle scheduling**

Author a short fixed chart at 120 BPM, schedule each obstacle from consumed beat events, and move it along a single readable lane toward the player. Choose beat spacing to satisfy the tested minimum reaction time. On restart, clear existing obstacles and reset the chart cursor.

- [ ] **Step 4: Run chart tests and smoke test**

Run: `godot --headless --path . --script res://tests/test_obstacle_chart.gd` and `godot --headless --path . --script res://tests/test_project_smoke.gd`
Expected: both PASS.

### Task 5: Timing judgments, score, combo, and HUD

**Files:**
- Create: `scripts/score_manager.gd`
- Create: `scenes/hud.tscn`
- Create: `scripts/hud.gd`
- Create: `tests/test_scoring.gd`
- Modify: `scripts/level_controller.gd`

**Interfaces:**
- `ScoreManager.judge(delta_seconds: float) -> StringName`
- `ScoreManager.record(judgment: StringName) -> void`
- `ScoreManager.summary() -> Dictionary`
- Judgment windows: Perfect <= 0.045 s, Great <= 0.09 s, Good <= 0.15 s, otherwise Miss.

- [ ] **Step 1: Write failing scoring tests**

Assert each boundary category, miss resets combo, successful judgments increment combo, and accuracy is derived deterministically from accumulated judgment weights.

- [ ] **Step 2: Run test and confirm expected failure**

Run: `godot --headless --path . --script res://tests/test_scoring.gd`
Expected: FAIL because scoring logic does not exist.

- [ ] **Step 3: Implement pure scoring rules and HUD**

Implement the stated windows, fixed judgment weights (Perfect 1.0, Great 0.8, Good 0.5, Miss 0.0), score accumulation, combo, and accuracy. Display score, combo, latest judgment, song progress, and pause state without covering the player lane.

- [ ] **Step 4: Run scoring tests and smoke test**

Run: `godot --headless --path . --script res://tests/test_scoring.gd` and `godot --headless --path . --script res://tests/test_project_smoke.gd`
Expected: both PASS.

### Task 6: Pause, restart, result flow, and optional CC0 effects

**Files:**
- Modify: `scripts/main.gd`
- Modify: `scripts/level_controller.gd`
- Modify: `scripts/hud.gd`
- Create: `assets/ATTRIBUTION.md`
- Optional asset source: `https://kenney.nl/assets/ui-audio`
- Optional asset source: `https://kenney.nl/assets/impact-sounds`
- Optional asset source: `https://kenney.nl/assets/digital-audio`
- Modify: `README.md`
- Create: `tests/test_game_flow.gd`

**Interfaces:**
- `Main.begin_run() -> void`, `Main.pause_run() -> void`, `Main.resume_run() -> void`, `Main.restart_run() -> void`, and `Main.show_results() -> void`.
- `ScoreManager.reset() -> void`.

- [ ] **Step 1: Write failing game-flow tests**

Assert pause freezes conductor position and gameplay processing, resume continues from the same position, restart resets chart cursor/obstacles/score/combo, and completion shows a result summary. Include a no-asset startup case.

- [ ] **Step 2: Run test and confirm expected failure**

Run: `godot --headless --path . --script res://tests/test_game_flow.gd`
Expected: FAIL because flow transitions do not exist.

- [ ] **Step 3: Implement flow and optional effects**

Add pause/result/restart states and a brief collision effect. If CC0 packs are downloaded, use only a few lightweight UI or impact sounds and record exact asset names, source URLs, and CC0 license in `assets/ATTRIBUTION.md`; otherwise retain built-in audio feedback and ensure no missing-file errors.

- [ ] **Step 4: Run flow and full headless test set**

Run all `tests/test_*.gd` scripts with Godot headless.
Expected: all PASS, including the no-asset startup case.

### Task 7: Visual polish, calibration, and build instructions

**Files:**
- Modify: `scenes/main.tscn`
- Modify: `scripts/hud.gd`
- Modify: `scripts/audio_conductor.gd`
- Modify: `README.md`
- Create: `tests/test_audio_offset.gd`

**Interfaces:**
- Settings expose `audio_offset_seconds` and `show_debug_overlay`.
- The debug overlay displays BPM, playback position, next beat, and most recent judgment.

- [ ] **Step 1: Write failing offset and debug-overlay tests**

Assert a configured offset changes beat timestamps by the exact signed amount and toggling the debug setting changes overlay visibility without changing gameplay state.

- [ ] **Step 2: Run tests and confirm expected failure**

Run: `godot --headless --path . --script res://tests/test_audio_offset.gd`
Expected: FAIL because settings and overlay behavior are not implemented.

- [ ] **Step 3: Implement calibration and focused visual response**

Add a manual offset setting, debug overlay, subtle beat pulse, and color response. Keep obstacle contrast high and screen shake limited to crash feedback.

- [ ] **Step 4: Run all automated checks and launch the editor build**

Run all headless test scripts, then run `godot --path .` for a manual playthrough at normal speed and pause/restart once.
Expected: all automated checks pass and the game can be played through to results.

- [ ] **Step 5: Document Windows export prerequisites**

Document the Godot 4.x version used, controls, project launch command, and requirement to install matching export templates before exporting a Windows executable.

## Asset sources checked

These Kenney asset pages identify the packs as Creative Commons CC0; use only assets actually needed and keep the project runnable without them: [UI Audio](https://kenney.nl/assets/ui-audio), [Impact Sounds](https://kenney.nl/assets/impact-sounds), and [Digital Audio](https://kenney.nl/assets/digital-audio). The game music remains generated or original to avoid borrowing a full song from an unrelated pack.
