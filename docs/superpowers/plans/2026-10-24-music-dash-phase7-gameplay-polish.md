# MUSIC DASH Phase 7 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make rhythm timing, music/difficulty scaling, visuals, and combo feedback clearer while keeping the existing Godot prototype fair and playable.

**Architecture:** Add one pure `GameplayProfile` service for song/difficulty tuning, let the existing generator and level controller consume the same effective speed, and extend the current vector-drawn player, hazards, world, and HUD. Preserve the audio clock and schema v1, expanding its supported event kinds in a backwards-compatible way.

**Tech Stack:** Godot 4.7.2, GDScript, existing headless SceneTree test scripts; no new dependencies or imported assets.

**Spec:** `docs/superpowers/specs/2026-10-24-music-dash-phase7-gameplay-polish-design.md`

## Global Constraints

- Keep Godot 4.7.2 and the existing audio playback clock as gameplay time source.
- Keep deterministic chart generation for the same analysis, seed, and difficulty.
- Preserve schema version 1 and backward compatibility for `spike`/`block` chart files.
- Keep chart fairness relative to effective speed: spawn warning `1120 / speed`; minimum target gap `0.8 + 48 / speed` seconds.
- Keep art self-contained in GDScript drawing and maintain the current 1280x720 single-lane prototype.

## Review Focus

- BPM/energy outside normal ranges: tuning remains finite and clamped; test in Task 1.
- Highest speed plus dense event sequence: every generated target remains fair; test in Task 2.
- Old chart JSON and malformed/unknown obstacle types: old kinds continue to load and unknown kinds fail; test in Task 2.
- Pause/restart/custom song with live timing cue: score target and cue reset correctly; test in Task 4.
- Animation and map response must not alter physics or timing; test in Task 3.

---

### Task 1: Song and Difficulty Gameplay Profile

**Files:**
- Create: `scripts/gameplay_profile.gd`
- Test: `tests/test_gameplay_profile.gd`
- Modify: `tests/test_procedural_chart_generator.gd` only if shared profile contract needs generator tests.

**Interfaces:**
- Produces `GameplayProfile.profile_for(analysis: Dictionary, difficulty: StringName) -> Dictionary` with status/reason, `scroll_speed`, `density`, `average_intensity`, and `bpm_factor`.
- Produces `GameplayProfile.scroll_speed_for(bpm: float, difficulty: StringName) -> float`.
- Consumes analysis beat features from `MusicAnalyzer` and difficulty names from `ProgressionStore.DIFFICULTIES`.

- [x] **Step 1: Write tests** for exact 120 BPM speed factors per difficulty, BPM clamp at low/high tempos, energy-based density ordering, and invalid BPM/difficulty/feature rejection.
- [x] **Step 2: Run `godot --headless --path . --script res://tests/test_gameplay_profile.gd`** and verify it fails because the profile service is absent.
- [x] **Step 3: Implement `GameplayProfile`** with spec constants, finite-input validation, bounded values, and deterministic average-intensity computation.
- [x] **Step 4: Re-run the focused test and all current tests**; expect the new test plus the existing 18 scripts to pass.
- [x] **Step 5: Commit** as `feat: add song difficulty gameplay profile`.

### Task 2: Music-Aware Hazards and Variable-Speed Fairness

**Files:**
- Modify: `scripts/procedural_chart_generator.gd`, `scripts/level_controller.gd`, `scripts/obstacle.gd`, `scripts/chart_data.gd`, `scripts/chart_editor.gd`, `addons/music_dash_chart_editor/chart_editor_dock.gd`, and `scripts/main.gd`.
- Modify scenes: `scenes/obstacle.tscn` only if collision geometry cannot be selected safely at runtime.
- Test: `tests/test_procedural_chart_generator.gd`, `tests/test_level_controller.gd`, `tests/test_chart_data.gd`, `tests/test_chart_editor.gd`, `tests/test_chart_editor_plugin.gd`, and a new `tests/test_phase7_tuning_integration.gd`.

**Interfaces:**
- `GameplayProfile` from Task 1 supplies speed/density.
- `ProceduralChartGenerator.generate(analysis, difficulty, seed, scroll_speed)` continues to receive actual effective speed and returns it with the chart.
- `LevelController.set_chart(chart)` consumes optional `scroll_speed`; default remains 360 for old/authored charts. `LevelController.scroll_speed()` returns the active value.
- Add `saw` and `crystal` to schema-v1's supported `kind` values; both editor surfaces can set/remove them.

- [x] **Step 1: Write failing tests** for energy/difficulty density, seeded new kinds, chart interchange for all kinds, dynamic spawn lead time, and old-chart fallback speed.
- [x] **Step 2: Run affected scripts** and confirm failures occur at absent kinds/profile integration and fixed travel time.
- [x] **Step 3: Implement generator/profile integration, variable level timing, and visual/collision geometry for four hazard kinds** while keeping target beat times unchanged.
- [x] **Step 4: Run affected tests and all current tests**; expect deterministic fair charts and backwards-compatible chart data.
- [x] **Step 5: Commit** as `feat: scale charts and hazards with music`.

### Task 3: Animated Runner and Reactive Map

**Files:**
- Modify: `scripts/player.gd`, `scripts/game_world.gd`, and `scripts/main.gd`.
- Test: create `tests/test_phase7_visuals.gd`.

**Interfaces:**
- `Player.current_animation() -> StringName` provides `run`, `jump`, `land`, or `crash` for deterministic contract checks.
- `GameWorld.set_music_profile(analysis: Dictionary, difficulty: StringName) -> void` configures section palette/energy response; `on_beat(beat_index, intensity)` updates the existing audio-driven pulse.
- Visual updates must not mutate player gravity, jump velocity, scorer target times, or level chart events.

- [x] **Step 1: Write failing tests** for player state transitions and music-profile-driven world palette/intensity.
- [x] **Step 2: Run the focused script and confirm missing visual APIs/state.**
- [x] **Step 3: Implement inexpensive vector animations and parallax/background section response** with fixed decorative draw counts.
- [x] **Step 4: Run visual contract tests and all current tests**; expect unchanged physics/scoring.
- [x] **Step 5: Commit** as `feat: animate runner and music reactive map`.

### Task 4: Timing and Combo HUD Feedback

**Files:**
- Modify: `scripts/run_scorer.gd` and `scripts/main.gd`.
- Test: modify `tests/test_run_scorer.gd`; create `tests/test_phase7_hud_integration.gd`.

**Interfaces:**
- `RunScorer.next_target_time() -> float` returns the next unresolved target or `-1.0` if exhausted.
- Main HUD updates a next-hit countdown/status, combo milestone meter, and Miss/combo reset cue from audio time and scorer state.

- [x] **Step 1: Write failing tests** for next target cursor behavior and HUD status transitions through countdown, hit/combo, Miss, and restart.
- [x] **Step 2: Run focused scripts and verify the APIs/status are absent.**
- [x] **Step 3: Implement next-target query and low-noise HUD state updates.**
- [x] **Step 4: Run scorer/HUD tests and all current tests**; expect timing targets and scores unchanged.
- [x] **Step 5: Commit** as `feat: show next beat and combo feedback`.

### Task 5: Documentation and Phase Regression

**Files:**
- Modify: `README.md`.
- Verify: all `tests/test_*.gd`, main parse check, headless editor startup, plugin loading.

- [x] **Step 1: Document dynamic tuning, hazard kinds, visuals, timing cue, and performance choices.**
- [x] **Step 2: Run all tests, `--check-only`, and headless editor/plugin startup; inspect output for errors.**
- [x] **Step 3: Review all changes against the spec, check deterministic generation, fair spacing, collision geometry, chart compatibility, and `git diff --check`.**
- [x] **Step 4: Commit** as `docs: document phase 7 polish and verification`.

## Completion Checklist

- [x] Gameplay speed and density respond to BPM, music energy, and difficulty.
- [x] Spawn lead/reaction spacing use active chart speed, and old charts remain playable.
- [x] Four readable, jumpable hazard shapes work in both editors.
- [x] Runner animation and map response are driven by gameplay/audio state.
- [x] HUD communicates next scoring beat, combo milestone, and Miss/reset state.
- [x] Previous Phase 1–6B behavior remains covered by green tests.
- [x] README and test instructions reflect Phase 7.
