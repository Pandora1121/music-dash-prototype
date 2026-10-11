# MUSIC DASH Phase 5 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add rhythm-timed scoring, a live gameplay HUD and run summaries, and persistent local difficulty progression.

**Architecture:** Keep timing rules in a scene-independent `RunScorer` and profile validation/persistence in `ProgressionStore`. Integrate both into the existing runtime-built UI in `main.gd`; chart target timestamps are derived from event beat indices and the same beat-time rules used by `LevelController`.

**Tech Stack:** Godot 4.7, GDScript, SceneTree tests, versioned JSON in `user://`.

**Spec:** `docs/superpowers/specs/2026-10-11-music-dash-phase5-design.md`

## Global Constraints

- All judgments use the audio conductor's song-position clock and chart beat timestamps.
- Windows are symmetric around the target: Perfect up to 45 ms, Great up to 90 ms, and Good up to 150 ms.
- Award 1000 / 700 / 400 base points for Perfect / Great / Good.
- Increase the award by 10% per existing combo tier, capped at a 2x multiplier (combo tiers advance every 10 successful judgments).
- Accuracy is weighted from successful judgments (Perfect 1.0, Great 0.75, Good 0.5, Miss 0.0) divided by all resolved targets; unresolved targets are finalized as Miss at chart completion or crash.
- Use the existing order Easy, Normal, Hard, Expert, Insane. A new save starts with Easy unlocked.
- Store a versioned JSON document under `user://` with unlocked difficulty and per-difficulty best scores/completion flags.
- Do not refactor the entire runtime-built UI into scenes in this phase.

## Review Focus

- **Late input at a target boundary:** one target must resolve as Miss once, never later as a hit; test input at `target + 0.150001` after advancing the scorer.
- **Early input before the next target:** it must not consume that target; test a jump at `target - 0.150001`, then a later valid jump.
- **Malformed save profiles:** unexpected versions, wrong types, and out-of-range unlock values must load a valid Easy-only profile; create fixtures through the injectable file path.
- **Save write failure:** gameplay results must still be returned and the in-memory profile remain valid; test a path whose parent directory does not exist.
- **Empty chart:** results must report zero counts and zero accuracy without division by zero; test scorer finalization with no targets.

---

### Task 1: Run Scorer

**Files:**
- Create: `scripts/run_scorer.gd`
- Create: `tests/test_run_scorer.gd`

**Interfaces:**
- `RunScorer.configure(target_times: Array) -> bool` validates finite, non-negative, strictly increasing timestamps and resets run state.
- `RunScorer.advance_to(song_position: float) -> Array[Dictionary]` resolves every target whose late window has elapsed and returns emitted judgment records.
- `RunScorer.record_jump(song_position: float) -> Dictionary` advances missed targets through the input time, then judges only the next eligible unjudged target; returns an empty dictionary when no target qualifies.
- `RunScorer.finalize() -> Dictionary` resolves all remaining targets as Miss and returns a summary containing `score`, `accuracy`, `perfect`, `great`, `good`, `miss`, `combo`, and `best_combo`.
- Judgment records contain `judgment`, `target_index`, `timing_error`, `points`, `score`, `combo`, and `multiplier`.

- [x] **Step 1: Write failing timing and accounting tests**
  Add cases for exact Perfect/Great/Good limits on both sides, one unit outside each limit, early non-consumption followed by a valid hit, a late Miss that cannot be recovered, duplicate prevention, combo tier changes/cap, accuracy weighting, and finalization.
- [x] **Step 2: Run the focused test and confirm it fails because the scorer is missing**
  Run: `& 'D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/test_run_scorer.gd`
  Expected: missing `run_scorer.gd` or undefined scorer API.
- [x] **Step 3: Implement `RunScorer`**
  Resolve targets in timestamp order. Calculate multiplier from the combo count before the current hit: `min(2.0, 1.0 + floor(combo / 10) * 0.1)`, so combo 0–9 earns 1x and combo 10–19 earns 1.1x. Compute points as rounded base points times multiplier, then increment combo. Accuracy is the weighted sum divided by resolved target count, or zero when the count is zero.
- [x] **Step 4: Run scorer tests and confirm they pass**
  Run: `& 'D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/test_run_scorer.gd`
  Expected: `PASS: run scorer` and exit code 0.
- [x] **Step 5: Commit scorer and tests**
  Commit message: `feat: add rhythm timing scorer`

### Task 2: Local Progression Store

**Files:**
- Create: `scripts/progression_store.gd`
- Create: `tests/test_progression_store.gd`

**Interfaces:**
- `ProgressionStore.load_profile(path: String = "user://music_dash_profile.json") -> bool` loads/validates profile or resets to defaults and returns whether existing valid data was loaded.
- `ProgressionStore.unlocked_difficulty() -> StringName` returns the highest unlocked item in the ordered difficulty list.
- `ProgressionStore.is_unlocked(difficulty: StringName) -> bool` checks availability.
- `ProgressionStore.best_score(difficulty: StringName) -> int` returns zero when no score is recorded.
- `ProgressionStore.record_run(difficulty: StringName, score: int, completed: bool, path: String = "user://music_dash_profile.json") -> bool` updates in-memory best/completion/unlock state and saves; return value reports persistence success without rolling back valid in-memory updates.

- [x] **Step 1: Write failing persistence tests**
  Cover default Easy-only profile, valid save/load round trip, best score never decreasing, completion unlocking exactly the next difficulty, crash not unlocking, unknown difficulty rejection, corrupt JSON/version/type/range fallback, and a forced write error that leaves in-memory state queryable.
- [x] **Step 2: Run the focused test and confirm it fails because the store is missing**
  Run: `& 'D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/test_progression_store.gd`
  Expected: missing `progression_store.gd` or undefined store API.
- [x] **Step 3: Implement `ProgressionStore`**
  Use an injectable path for test isolation and a fixed versioned JSON shape in production. Validate every difficulty entry, score, completion flag, and unlock index before accepting loaded data. On write errors, keep updated in-memory data and return `false`.
- [x] **Step 4: Run persistence tests and confirm they pass**
  Run: `& 'D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/test_progression_store.gd`
  Expected: `PASS: progression store` and exit code 0.
- [x] **Step 5: Commit store and tests**
  Commit message: `feat: persist local difficulty progression`

### Task 3: Gameplay and Results Integration

**Files:**
- Modify: `scripts/main.gd`
- Create: `tests/test_phase5_integration.gd`
- Modify: `tests/test_project_smoke.gd`

**Interfaces:**
- Consume `RunScorer.configure`, `advance_to`, `record_jump`, and `finalize` from Task 1.
- Consume `ProgressionStore.load_profile`, `unlocked_difficulty`, `is_unlocked`, `best_score`, and `record_run` from Task 2.
- Add a helper in `main.gd` that maps each chart event `beat_index` to its target timestamp: use `chart.beat_times[index] + audio_offset` when available; otherwise use `index * 60.0 / chart.bpm + audio_offset`, matching `BeatChart.beat_time`.

- [x] **Step 1: Write failing integration tests**
  Assert new profile starts on Easy, menu difficulty control disables locked options, selected difficulty is passed into generated chart data, scorer targets match obstacle event times including authored fallback, HUD reflects a controlled judgment and song position, completion unlocks the next difficulty and displays accurate results, crash records a best score without unlocking, and restart resets run score/combo.
- [x] **Step 2: Run integration test and confirm expected Phase 5 behavior is absent**
  Run: `& 'D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/test_phase5_integration.gd`
  Expected: one or more Phase 5 assertions fail while the existing project still parses.
- [x] **Step 3: Integrate scorer lifecycle and menu difficulty selection**
  Load the progression profile during `_ready`; initialize the menu with a difficulty selector restricted to unlocked choices. Make chart preparation accept the selected difficulty and use it in both procedural and authored fallback metadata. Reject locked difficulty at the start boundary.
- [x] **Step 4: Integrate scoring and update the HUD**
  Configure scorer targets from chart events at run start. Pass `Player.jumped` timestamps into `record_jump`; call `advance_to` with current song position each playing frame. Update score, combo, best combo, judgment feedback, accuracy, BPM, and progress bar from scorer/conductor state.
- [x] **Step 5: Integrate completion, crash, pause, and restart summaries**
  Finalize unresolved targets exactly once on terminal outcomes. Record the best score for both completed and crashed runs; unlock the next difficulty only on completion. Display judgment counts, score, accuracy, and best combo on results/crash screens. Reset scorer at each run; preserve pause clock behavior.
- [x] **Step 6: Run focused integration and existing smoke tests**
  Run: `& 'D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/test_phase5_integration.gd`
  Then run: `& 'D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/test_project_smoke.gd`
  Expected: both print their PASS marker and exit 0.
- [x] **Step 7: Run the full project test suite and editor parse check**
  Run each `tests/test_*.gd` with `& 'D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/<test-file>.gd`, then run `& 'D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --check-only --script res://scripts/main.gd`.
  Expected: all test PASS markers, exit 0 for every command, and no parse errors.
- [x] **Step 8: Commit the integrated phase**
  Commit message: `feat: add phase 5 scoring and progression`

## Completion Checklist

- [x] All Phase 5 acceptance criteria in the spec are covered.
- [x] Existing Phase 1–4 tests and smoke flow pass.
- [x] `git diff --check` reports no whitespace errors.
- [x] Update the phase roadmap/status documentation with completed Phase 5 behavior and verification evidence.
