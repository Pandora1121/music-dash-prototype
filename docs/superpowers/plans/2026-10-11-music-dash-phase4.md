# Music Dash Phase 4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Analyze the bundled song and generate a seeded, fair obstacle chart with a safe authored fallback.

**Architecture:** Add a synchronous `MusicAnalyzer` for imported PCM and a deterministic `ProceduralChartGenerator` that consumes analysis data. `Main` prepares and caches a chart before playback, while `LevelController` accepts that chart and retains the existing authored chart by default.

**Tech Stack:** Godot 4.7, GDScript, SceneTree smoke tests.

**Spec:** `docs/superpowers/specs/2026-10-11-music-dash-phase4-design.md`

## Global Constraints

- Analyze the bundled WAV only; custom music selection and import UI remain in Phase 6.
- Do not add external runtime dependencies or GDExtensions.
- Keep playback position from `AudioConductor` as the gameplay timing source.
- Use 0.8 seconds minimum reaction time after accounting for the 48-pixel collision width at 360 pixels/second.
- Use the existing authored 120 BPM chart if analysis is unsupported, silent, too short, or low confidence.

## Review Focus

- Imported WAV data can have unexpected format metadata or empty samples; test invalid streams and return failure without runtime errors.
- Short/noisy samples can yield unstable tempo peaks; test confidence gating and authored fallback.
- Frequency-band boundaries must remain valid at the prototype's sample rate; test finite normalized values.
- Dense charts can pass beat ordering yet violate physical warning time; test event gaps after collision travel is subtracted.
- Restart can accidentally regenerate a different chart; test prepared-chart reuse across restart.

---

### Task 1: PCM Music Analyzer

**Files:**
- Create: `scripts/music_analyzer.gd`
- Create: `tests/test_music_analyzer.gd`
- Modify: `assets/audio/music_dash_prototype.wav.import`

**Interfaces:**
- Produces `MusicAnalyzer.analyze(stream: AudioStreamWAV) -> Dictionary` with `status`, `reason`, `bpm`, `confidence`, `duration_seconds`, `beat_times`, per-beat features, and relative energy sections.

- [x] Write a SceneTree test that loads the bundled stream, asserts detected BPM is 118–122, beat times increase, and all feature values are finite and normalized.
- [x] Run the analyzer test and confirm it fails because `music_analyzer.gd` does not exist.
- [x] Implement null/format/sample-rate/short/silence validation, mono folding, RMS and representative bands, onset strength, 60–180 BPM autocorrelation, onset alignment, confidence gating, and 16-beat relative sections.
- [x] Set WAV import `compress/mode=0` so analyzer and playback use uncompressed PCM samples.
- [x] Add failing cases for null, silent, too-short, and unsupported input; run to confirm failure before implementation, then implement explicit failure dictionaries without partial invalid analysis.
- [x] Run the analyzer test; it passes with BPM 120.174 and measured analysis time 42 ms on the final verification run.

### Task 2: Deterministic Fair Chart Generator

**Files:**
- Create: `scripts/procedural_chart_generator.gd`
- Create: `tests/test_procedural_chart_generator.gd`

**Interfaces:**
- Consumes the analyzer Dictionary from Task 1.
- Produces `ProceduralChartGenerator.generate(analysis: Dictionary, difficulty: StringName, seed: int, scroll_speed: float) -> Dictionary` with ordered events and chart metadata.

- [x] Write tests for identical charts with identical seeds, seed variation on a long-enough feature sequence, supported obstacle kinds, and all five difficulty identifiers.
- [x] Write a fairness test asserting hit-time spacing minus `48.0 / scroll_speed` is at least 0.8 seconds and no event precedes the warning window.
- [x] Run the generator test and confirm the production script is missing.
- [x] Implement deterministic feature-guided beat selection, difficulty density, bass/treble obstacle guidance, event ordering, and fairness filtering; reject invalid analysis explicitly.
- [x] Run the generator test; all deterministic, seed variation, difficulty, kind, and fairness assertions pass.

### Task 3: Level Chart Injection and Main Preparation

**Files:**
- Modify: `scripts/level_controller.gd`
- Modify: `scripts/main.gd`
- Create: `tests/test_phase4_integration.gd`

**Interfaces:**
- Add `LevelController.set_chart(chart: Dictionary) -> void`; existing authored chart stays the default.
- `Main` loads/analyzes the bundled stream once, prepares generated chart or fallback, passes BPM and chart to level before `begin_level()`, and caches the prepared result for restarts.

- [x] Write integration assertions that confident analysis selects generated events, failure selects the authored chart, audio position still advances the chart, and restart reuses the same chart.
- [x] Run the integration test and confirm the new preparation/injection behavior is absent.
- [x] Implement validated chart assignment and one-time preparation before the first run; keep all existing input, audio timing, and menu behavior intact.
- [x] Run the integration test and existing Phase 1–3 SceneTree tests; assertions pass. Godot may emit audio resource references at process teardown in smoke runs.

### Task 4: Full Verification and Documentation

**Files:**
- Modify: `README.md`

- [x] Document that Phase 4 analyzes the bundled WAV at run preparation and uses authored fallback when confidence is low.
- [x] Run every test under `tests/` with the project's Godot 4.7 headless executable, plus a project script parse check.
- [x] Inspect output and exit codes for script errors, assertion failures, import errors, and runtime errors; all eight tests exit 0 with PASS and no warning/error output.
- [x] Review `git diff --check` and the final diff for only Phase 4 scope.
- [ ] Commit and push the verified Phase 4 changes if Git metadata permissions allow.
