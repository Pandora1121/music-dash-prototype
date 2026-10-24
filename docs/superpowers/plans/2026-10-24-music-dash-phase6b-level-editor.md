# MUSIC DASH Phase 6B Shared Level Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an in-game chart editor and a Godot editor dock that edit, save, load, and play charts through one shared versioned JSON format.

**Architecture:** `ChartData` owns the JSON schema, fairness checks, file IO, and conversion to gameplay charts. A runtime editor scene and a Godot `EditorPlugin` provide separate interfaces over that shared model; `Main` and `LevelController` continue to own playback and execution.

**Tech Stack:** Godot 4.7.2, GDScript, `EditorPlugin`, built-in `JSON`, `FileAccess`, and SceneTree tests.

**Spec:** `docs/superpowers/specs/2026-10-24-music-dash-phase6b-level-editor-design.md`

## Global Constraints

- Keep the bundled track and current generated-chart flow as the default.
- Use a versioned JSON chart object with `format_version`, `name`, `bpm`, `duration_seconds`, `beat_times`, and `events` (`beat_index`, `kind`).
- Support only obstacle kinds `spike` and `block` in this increment.
- Store no absolute audio path or audio data in chart files.
- Runtime charts live under `user://music_dash_charts/` by default; project charts live under `res://charts/`.
- Use the existing game timing source and fairness rules; at 360 px/s reject target times before 1120/360 seconds and target gaps below 0.8 + 48/360 seconds.
- Invalid loads, edits, or saves never replace the current valid working chart.
- Do not add third-party dependencies.

## Review Focus

- Malformed JSON, wrong field types, and unsupported format versions must fail without replacing the chart; test parser and schema validation in Task 1.
- Duplicate, unordered, non-finite, or out-of-range beat/event values must fail clearly; test schema validation in Task 1.
- An obstacle that arrives before its warning time or too soon after another obstacle must be rejected; test fairness validation in Task 1.
- File read/write failure or dialog cancellation must preserve the current chart; test runtime file flow in Task 3.
- A Godot dock save must remain loadable by the game and runtime saves by the dock; test shared round-trip behavior in Tasks 1 and 4.

---

### Task 1: Shared Chart Data Format and Validation

**Files:**
- Create: `scripts/chart_data.gd`
- Create: `tests/test_chart_data.gd`

**Interfaces:**
- Produces `new_empty(name: String, bpm: float, duration_seconds: float) -> Dictionary`, `validate(chart: Dictionary, scroll_speed: float = 360.0) -> Dictionary`, `parse_json(text: String, scroll_speed: float = 360.0) -> Dictionary`, `serialize(chart: Dictionary, scroll_speed: float = 360.0) -> Dictionary`, `load_file(path: String, scroll_speed: float = 360.0) -> Dictionary`, `save_file(path: String, chart: Dictionary, scroll_speed: float = 360.0) -> Dictionary`, `from_gameplay(chart: Dictionary, name: String) -> Dictionary`, and `to_gameplay(chart: Dictionary, scroll_speed: float = 360.0) -> Dictionary`.
- `new_empty` and `from_gameplay` return schema chart dictionaries. Validation, parse, serialization, and file operations return `{status: &"ok"|&"failed", reason: String, ...}`; validation/parse/load return normalized `chart`, serialize returns `text`, file save returns `path`; `to_gameplay` returns `chart` or a failure result for an empty chart.
- Chart JSON contains only `format_version`, `name`, `bpm`, `duration_seconds`, `beat_times`, and `events`; validation ensures finite positive BPM/duration, non-empty ordered beat times within duration, unique strictly increasing event indices in range, supported kinds, sufficient warning time, and fair target gaps. A valid chart may have zero events while being edited; `to_gameplay` rejects empty charts so they cannot start a run.

- [x] **Step 1: Write failing ChartData tests**
  Cover empty-chart creation from BPM/duration, parse/serialize round trip preserving events and beat times, gameplay conversion, unknown version, invalid JSON and field types, non-finite/unordered/out-of-range beats, duplicate events, unsupported kind, insufficient first warning time, unfair reaction gap, missing file, empty chart save-but-not-playable behavior, and a valid save/load round trip in `user://`.
- [x] **Step 2: Run the focused test and confirm missing ChartData behavior**
  Run: `godot --headless --path . --script res://tests/test_chart_data.gd`
  Expected: the test fails because `scripts/chart_data.gd` or its required methods do not exist.
- [x] **Step 3: Implement the versioned schema and validator**
  Implement the interfaces above. Use Godot's `JSON.parse_string` and `FileAccess`; reject malformed input and failed file operations with readable reasons. Build regular beat grids for `new_empty`, preserving beat times below duration.
- [x] **Step 4: Run ChartData tests**
  Run: `godot --headless --path . --script res://tests/test_chart_data.gd`
  Expected: `PASS: chart data` and no errors.
- [x] **Step 5: Commit shared chart data**
  Commit message: `feat: add shared chart data format`

### Task 2: Runtime Chart Editing Surface

**Files:**
- Create: `scripts/chart_editor.gd`
- Create: `scenes/chart_editor.tscn`
- Create: `tests/test_chart_editor.gd`

**Interfaces:**
- Consumes Task 1's `ChartData.validate` and `ChartData.to_gameplay` contracts.
- Produces a scene with `configure(chart: Dictionary, track_name: String) -> void`, `cycle_beat(beat_index: int) -> bool`, `current_chart() -> Dictionary`, `load_requested`, `save_requested(chart: Dictionary)`, `play_requested(chart: Dictionary)`, and `back_requested(chart: Dictionary)` signals. Configure/current/save/back use schema charts; play emits the gameplay chart returned by `ChartData.to_gameplay`. Save works for valid empty charts, play is disabled/rejected until an obstacle exists, and back returns edits so they survive in-session.
- Timeline beat actions cycle empty → spike → block → empty and edit a working copy only. Chart kind values normalize to `StringName` in GDScript and serialize as JSON strings.

- [x] **Step 1: Write failing runtime editor tests**
  Instantiate the scene and assert configured title/beat count, `cycle_beat` adds/changes/removes the correct event, clear removes all events, save emits a validated empty or non-empty schema chart, play emits only a playable non-empty gameplay chart, and back returns edited data without mutating the input chart.
- [x] **Step 2: Run the focused test and confirm the editor scene is missing**
  Run: `godot --headless --path . --script res://tests/test_chart_editor.gd`
  Expected: it fails to preload `scenes/chart_editor.tscn` or required editor methods.
- [x] **Step 3: Implement the runtime timeline editor**
  Build a scrollable beat grid from `beat_times`, show current obstacle kinds, and provide load, clear, save, play, and back controls. Keep edits in a duplicate chart and validate before emitting save/play signals.
- [x] **Step 4: Run runtime editor tests**
  Run: `godot --headless --path . --script res://tests/test_chart_editor.gd`
  Expected: `PASS: chart editor` and no errors.
- [x] **Step 5: Commit runtime editor surface**
  Commit message: `feat: add runtime level chart editor`

### Task 3: Runtime Menu, Load/Save, and Gameplay Integration

**Files:**
- Modify: `scripts/main.gd`
- Create: `tests/test_phase6b_integration.gd`

**Interfaces:**
- Consumes `ChartData` and `ChartEditorScene` from Tasks 1–2.
- Adds **LEVEL EDITOR** to the menu; runtime file dialogs open/save JSON; `_prepared_chart` remains in gameplay-chart form and is converted to/from schema form at editor/file boundaries.

- [x] **Step 1: Write failing Phase 6B integration tests**
  Assert menu editor entry, editor receives the selected track's chart, edits affect the next run, save/load round-trip uses `user://music_dash_charts/`, loading malformed or unfair JSON keeps the prior chart, cancel keeps the chart, and restart preserves edited events and selected stream.
- [x] **Step 2: Run integration tests and confirm the menu entry/flow is absent**
  Run: `godot --headless --path . --script res://tests/test_phase6b_integration.gd`
  Expected: one or more Phase 6B assertions fail while Phase 6A remains intact.
- [x] **Step 3: Integrate editor state and chart dialogs into Main**
  Open the runtime editor with the currently selected track and generated chart. Handle editor back/play/save signals, add JSON load/save dialogs rooted at `user://music_dash_charts/`, and update the prepared chart only after shared validation succeeds.
- [x] **Step 4: Verify Phase 6B and Phase 6A integration**
  Run both: `godot --headless --path . --script res://tests/test_phase6b_integration.gd` and `godot --headless --path . --script res://tests/test_phase6a_integration.gd`.
  Expected: `PASS: phase 6B integration`, `PASS: phase 6A integration`, and no script errors.
- [x] **Step 5: Commit runtime integration**
  Commit message: `feat: integrate runtime level editor`

### Task 4: Godot Editor Dock Plugin

**Files:**
- Create: `addons/music_dash_chart_editor/plugin.cfg`
- Create: `addons/music_dash_chart_editor/plugin.gd`
- Create: `addons/music_dash_chart_editor/chart_editor_dock.gd`
- Modify: `project.godot`
- Create: `tests/test_chart_editor_plugin.gd`

**Interfaces:**
- Consumes the same `ChartData` service and JSON schema; no plugin-specific validation.
- Plugin registers an editor dock with chart name/BPM/duration controls, open/save actions, and beat-index/kind event editing. It can create a regular beat grid with no events or open either runtime/editor chart files.
- Saves Godot-authored charts under `res://charts/` and enables the plugin through project configuration.
- `ChartEditorDock.configure_chart(chart: Dictionary) -> bool`, `create_empty_chart(name: String, bpm: float, duration_seconds: float) -> bool`, `current_chart() -> Dictionary`, `set_beat_event(beat_index: int, kind: StringName) -> bool`, `remove_beat_event(beat_index: int) -> bool`, `load_chart_from_path(path: String) -> bool`, and `save_chart_to_path(path: String) -> bool` operate on schema chart dictionaries. The `EditorPlugin` owns only dock registration and project file dialogs.

- [x] **Step 1: Write failing plugin contract tests**
  Assert plugin config points to a loadable `EditorPlugin` script, dock script loads, dock methods create/edit/remove events, validator rejects unfair charts, and a runtime-generated JSON fixture opens/saves without changing beat times.
- [x] **Step 2: Run plugin contract tests and confirm plugin files are missing**
  Run: `godot --headless --path . --script res://tests/test_chart_editor_plugin.gd`
  Expected: missing plugin files/config or dock methods.
- [x] **Step 3: Implement the dock and plugin registration**
  Implement a compact event-list editor and grid metadata controls using built-in Godot controls. Connect open/save to `ChartData`; register an `EditorDock` with `EditorPlugin.add_dock` and remove it with `remove_dock` on disable. Enable the plugin in `project.godot`.
- [x] **Step 4: Verify plugin loading and cross-surface round trips**
  Run the focused plugin test and `godot --headless --editor --path . --quit`; inspect output for plugin/script errors. Expected: `PASS: chart editor plugin`, dock loads, and no plugin/script errors. Godot 4.7.2 exits 0 and loads the dock, but logs a Windows `Safe save failed` from editor metadata persistence in this sandbox; this is recorded separately from script/runtime errors.
- [x] **Step 5: Commit Godot dock plugin**
  Commit message: `feat: add godot chart editor dock`

### Task 5: Documentation and Full Regression

**Files:**
- Modify: `README.md`
- Verify: every `tests/test_*.gd` plus editor project load.

**Interfaces:**
- Documents both editor surfaces, common JSON format, save locations, how to enable/use the Godot dock, and the no-audio-path persistence rule.

- [x] **Step 1: Update README with Phase 6B workflows and limitations**
  Document runtime editor controls, JSON save/load location, Godot plugin setup, chart compatibility, and non-goals such as waveform editing and cloud sharing.
- [x] **Step 2: Run all tests and parse checks**
  Run every `tests/test_*.gd`, `godot --headless --path . --check-only --script res://scripts/main.gd`, and the headless editor startup.
  Expected: every test prints its `PASS` marker, each process exits zero, and no `ERROR` or `SCRIPT ERROR` appears.
- [x] **Step 3: Review the final diff against the spec**
  Run `git diff --check`; confirm both surfaces use `ChartData`, saved files contain no absolute audio paths, and no custom audio is included.
- [x] **Step 4: Commit docs and completed plan status**
  Commit message: `docs: document phase 6B level editor`

## Completion Checklist

- [x] Both editors share the same chart file format and validator.
- [x] Runtime charts can be edited, saved, loaded, and played with the selected song.
- [x] Godot dock charts can be created/edited and exchanged with the runtime editor.
- [x] Invalid edits and file operations keep the last valid chart.
- [x] Existing Phase 1–6A tests and gameplay remain intact.
- [x] README documents both editor workflows and limits.
