# MUSIC DASH Phase 6A Custom Music Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a Windows player select a local supported WAV, generate a fair chart from its analysis, and play/restart that song while preserving the bundled track as the default.

**Architecture:** `CustomMusicLoader` validates a path, loads an `AudioStreamWAV`, and returns it with `MusicAnalyzer` output without changing game state. `AudioConductor` accepts an explicit stream while retaining the existing playback clock. `Main` owns track selection, the native file dialog, chart caching, and user-facing status; it commits a custom selection only after the song and chart are valid.

**Tech Stack:** Godot 4.7.2, GDScript, `AudioStreamWAV.load_from_file`, existing MusicAnalyzer/ProceduralChartGenerator, SceneTree tests.

**Spec:** `docs/superpowers/specs/2026-10-11-music-dash-phase6a-custom-music-design.md`

## Global Constraints

- The bundled prototype song remains the default and remains playable after every custom-file failure.
- Custom input is local WAV only, analyzed as uncompressed 16-bit PCM with a valid sample rate, non-silent audio, at least two seconds, and a confident tempo estimate.
- Use the same selected audio stream for analysis and gameplay playback.
- Gameplay timing continues to use `AudioConductor`'s audio playback clock.
- Use the existing selected difficulty, seeded chart generator, and fairness rules.
- Custom selection and its path are session-local; do not copy, upload, or persist user audio paths.
- OGG/MP3, manual editing, and Phase 6B are out of scope.

## Review Focus

- A WAV disappears or becomes unreadable between browsing and loading: report failure and keep the current track.
- A non-WAV path is passed directly to the loader despite the dialog filter: reject it without changing the current track.
- A readable WAV has unsupported PCM, an invalid sample rate, malformed data, silence, short duration, or low tempo confidence: surface the analyzer reason and retain the current track.
- A valid analysis produces no usable obstacle events for the selected difficulty: reject that custom selection rather than silently substituting the bundled authored chart.
- The player crashes, completes, pauses, resumes, or restarts after selecting a custom song: keep the selected stream and chart timing consistent across the run lifecycle.

---

### Task 1: Custom WAV Loader

**Files:**
- Create: `scripts/custom_music_loader.gd`
- Create: `tests/test_custom_music_loader.gd`

**Interfaces:**
- Consumes: `MusicAnalyzer.analyze(stream: AudioStreamWAV) -> Dictionary`.
- Produces: `CustomMusicLoader.load_file(path: String) -> Dictionary`. Success returns `status`, empty `reason`, `stream: AudioStreamWAV`, `analysis: Dictionary`, `path`, and `display_name`; failure returns `status: &"failed"`, a readable `reason`, and no accepted stream/analysis.

- [x] **Step 1: Write failing loader tests**
  Add `_initialize()` tests named `_test_loads_and_analyzes_supported_wav`, `_test_rejects_non_wav_path`, `_test_rejects_missing_path`, and `_test_propagates_analysis_failure`. Use the bundled WAV by absolute path for success; use an existing non-WAV resource and an absent temporary path for failures. For analyzer failures, write silent 16-bit and unsupported 8-bit WAV fixtures to temporary user paths with `AudioStreamWAV.save_to_wav`. Assert success exposes stream data, `analysis.status == &"ok"`, the file path, and basename; assert each failure has `status == &"failed"` and a non-empty reason.
- [x] **Step 2: Run loader tests and confirm the expected missing-service failure**
  Run: `& 'D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/test_custom_music_loader.gd`
  Expected: the test fails because `custom_music_loader.gd` or `load_file` is not implemented.
- [x] **Step 3: Implement `CustomMusicLoader.load_file(path: String) -> Dictionary`**
  Reject empty paths, non-`.wav` extensions case-insensitively, and nonexistent/unreadable files before loading. Load with `AudioStreamWAV.load_from_file(path)`, call `MusicAnalyzer.analyze`, propagate its failure reason, and return the complete success record without changing any caller state.
- [x] **Step 4: Run loader tests and confirm they pass**
  Run: `& 'D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/test_custom_music_loader.gd`
  Expected: `PASS: custom music loader` with no errors.
- [x] **Step 5: Commit loader and tests**
  Commit message: `feat: load and analyze custom wav tracks`

### Task 2: Selectable Audio Stream Lifecycle

**Files:**
- Modify: `scripts/audio_conductor.gd`
- Create: `tests/test_audio_conductor_stream.gd`

**Interfaces:**
- Produces: `AudioConductor.set_stream(stream: AudioStream) -> bool`, rejecting null without mutation and stopping/resetting timing before accepting a valid stream; `AudioConductor.current_stream() -> AudioStream` returns the selected stream.
- Existing `start_from`, `pause_song`, `resume_song`, `stop_song`, `song_position`, and `consume_beats_until` continue to operate on the selected stream and the same beat chart.

- [x] **Step 1: Write failing selected-stream lifecycle tests**
  Add `_initialize()` tests named `_test_selects_stream_and_rejects_null`, `_test_stop_and_restart_retain_selected_stream`, and `_test_pause_resume_preserve_selected_stream`. Load the bundled WAV through `AudioStreamWAV.load_from_file` as the selected stream. Assert null rejection retains the prior stream; `start_from`, `stop_song` then `start_from`, and pause/resume keep `current_stream() == selected_stream`; assert `song_position()` is reset to zero after a stop/restart and does not advance while paused.
- [x] **Step 2: Run focused tests and confirm the stream-selection API is absent**
  Run: `& 'D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/test_audio_conductor_stream.gd`
  Expected: a missing `set_stream` or `current_stream` assertion/API failure.
- [x] **Step 3: Implement stream selection and preserve it across stop/restart**
  Initialize the conductor with its existing bundled default. Implement `set_stream` to reject null, stop active playback, clear pause state, reset beat cursors and cached song position, then assign the stream. Make `stop_song` stop and reset timing without nulling the selected stream. Keep `start_from` from replacing a selected stream with the bundled default.
- [x] **Step 4: Run focused stream lifecycle tests**
  Run: `& 'D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/test_audio_conductor_stream.gd`
  Expected: `PASS: audio conductor stream` with no errors.
- [x] **Step 5: Commit conductor and tests**
  Commit message: `feat: select audio conductor stream`

### Task 3: Main Menu and Custom Track Integration

**Files:**
- Modify: `scripts/main.gd`
- Create: `tests/test_phase6a_integration.gd`

**Interfaces:**
- Consumes: `CustomMusicLoader.load_file`, `AudioConductor.set_stream/current_stream`, and existing chart/analyzer APIs.
- Produces: `Main._select_custom_track(path: String) -> bool`, which returns true only after load, analysis, and a non-empty chart for `selected_difficulty` all validate; `Main._try_commit_track(track: Dictionary, chart: Dictionary) -> bool`, which atomically accepts a valid track/chart pair; `_select_builtin_track() -> void` restores the built-in track; `_on_custom_file_selected(path: String)` and `_on_custom_file_canceled()` handle FileDialog signals.

- [x] **Step 1: Write failing menu and integration tests**
  Add `_initialize()` tests named `_test_builtin_track_is_default`, `_test_custom_wav_selection_builds_matching_chart`, `_test_failed_selection_keeps_current_track`, `_test_cancel_keeps_current_track`, `_test_difficulty_and_restart_keep_custom_track`, and `_test_commit_rejects_empty_chart_without_replacing_track`. Assert menu controls and details are present; selected analysis/stream match the loaded file; chart beat times and difficulty match the selected track; failure/cancel retain the previous record; `_try_commit_track` rejects a custom chart with `events: []`; and restart keeps the custom stream and the cached seed/chart.
- [x] **Step 2: Run integration tests and confirm custom selection behavior is absent**
  Run: `& 'D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/test_phase6a_integration.gd`
  Expected: one or more Phase 6A assertions fail while existing project scripts still parse.
- [x] **Step 3: Add track records and selection helpers to `Main`**
  Store the built-in and selected track records with `stream`, `analysis`, `path`, and `display_name`. Load and analyze the built-in track through the same interface. `_select_custom_track` must call `_try_commit_track` with a chart generated for `selected_difficulty`. `_try_commit_track` rejects missing fields, failed analysis, failed chart status, or empty events before mutating any selected-track/chart state; only after validation does it replace `_selected_track` and `_prepared_chart`. Failure sets a menu error while preserving the previous record.
- [x] **Step 4: Add the menu source controls and FileDialog**
  Add `USE BUILT-IN`, `LOAD CUSTOM WAV`, a track detail label, and an error/status label to the runtime-built menu. Configure a native `FileDialog` for filesystem access, single-file open, and WAV filtering. Connect file-selected and canceled signals; cancel must not mutate selection. Rebuild and free the dialog with the rest of the menu UI.
- [x] **Step 5: Wire the selected track into chart preparation and gameplay**
  Generate charts from `_selected_track.analysis` and current difficulty. For custom tracks, reject invalid/empty charts instead of taking the authored built-in fallback. Set the conductor stream before each `start_from(0.0)`, derive BPM and duration from the selected chart/analysis, and preserve the cached chart on restart. Changing difficulty invalidates only the prepared chart, not the selected stream or analysis.
- [x] **Step 6: Run the Phase 6A integration test and existing Phase 5 regression test**
  Run: `& 'D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/test_phase6a_integration.gd`
  Then run: `& 'D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/test_phase5_integration.gd`
  Expected: `PASS: phase 6A integration`, `PASS: phase 5 integration`, and no script errors.
- [x] **Step 7: Commit menu integration and tests**
  Commit message: `feat: integrate custom music selection`

### Task 4: Documentation and Full Regression Check

**Files:**
- Modify: `README.md`
- Verify: every `tests/test_*.gd`

**Interfaces:**
- Documents the supported local WAV format, selection flow, analysis limitations, controls, and failure behavior without claiming OGG/MP3 or Level Editor support.

- [x] **Step 1: Update README with Phase 6A behavior and limits**
  Add a concise section explaining how to select a local WAV, which PCM and analysis requirements apply, that paths are not copied or saved, that the bundled track remains available, and that Phase 6B Level Editor is not part of this increment.
- [x] **Step 2: Run every project test and a main-script parse check**
  Set `$env:APPDATA = Join-Path (Get-Location).Path '.godot-user'`; run each `tests/test_*.gd` with `& 'D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/<test-file>.gd`, then run `& 'D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --check-only --script res://scripts/main.gd`.
  Expected: every script prints its `PASS` marker, the parse check exits cleanly, and no `ERROR`/`SCRIPT ERROR` output appears.
- [x] **Step 3: Review whitespace and complete documentation**
  Run `git diff --check`; inspect the final diff against the Phase 6A spec. Confirm no custom audio file or user-specific path is added to the repository.
- [x] **Step 4: Commit README and final Phase 6A status**
  Commit message: `docs: document phase 6A custom music`

## Completion Checklist

- [x] Every Phase 6A acceptance criterion in the spec is covered by tests or manual menu verification.
- [x] Existing Phase 1–5 behavior and tests remain intact.
- [x] Custom file failures retain the current song and never interrupt gameplay.
- [x] `git diff --check` is clean and README accurately states format limitations.
