# MUSIC DASH Phase 6B Design: Shared Level Editor

## Goal

Let players make and play obstacle charts in the game, and let creators edit those same charts in the Godot editor. Both editing surfaces use one versioned JSON format so charts can move between them without conversion.

## Scope

- Add a shared chart data/validation service for parsing, validating, and serializing versioned JSON chart files.
- Add an in-game editor reachable from the main menu. It starts from the selected track's generated chart, displays the analyzed beat grid, and lets the player add, change, or remove spike/block events before play.
- Let the player save and load chart JSON through local file dialogs. Runtime saves default to `user://music_dash_charts/`; custom audio paths remain session-only and are never written into chart files.
- Add a Godot `EditorPlugin` dock for opening, editing, creating, and saving the same chart JSON inside the project. It must support editing the event list against the chart beat grid and writing chart files under a project `charts/` folder.
- Let the game load a saved chart for the currently selected track and play it through the existing `LevelController`, `AudioConductor`, fairness validation, and scoring flow.
- Preserve current generated charts and default gameplay when the editor is not used.

## User flows

### In-game

1. Select the built-in or a supported custom WAV in the menu.
2. Open **LEVEL EDITOR**; the editor receives that track's analysis and generated chart as its starting point.
3. Inspect beats on a scrollable timeline and click a beat to cycle empty → spike → block → empty. Clear and save actions are available.
4. Save a named JSON chart locally, or load a compatible chart for the selected track. Starting a run plays the edited chart. Returning to the editor preserves unsaved edits for the current session.

### Godot editor

1. Enable the Phase 6B plugin and open its dock.
2. Create a chart grid from BPM and duration, or open a chart JSON produced in-game.
3. Add, change, or remove events by beat index and obstacle kind; validate and save the JSON under the project `charts/` folder.
4. Load that chart from the game while the corresponding track is selected, then play it.

## Shared chart format

Use a versioned JSON object with `format_version`, `name`, `bpm`, `duration_seconds`, `beat_times`, and `events`. Each event contains `beat_index` and `kind` (`spike` or `block`). Optional source metadata may contain a display name only; no absolute file path or audio data is stored. The shared validator rejects unsupported versions, non-finite or unordered beat times, out-of-range event indices, unknown obstacle kinds, and malformed/duplicate events. Beat times are explicit so charts based on Phase 6A audio analysis keep their measured timing; a chart created from scratch in Godot uses evenly spaced beats derived from BPM.

The editor preserves the current fairness rule: events must provide the minimum reaction gap for the existing scroll speed and obstacle width. Invalid charts cannot be started, and the UI reports which validation rule failed.

## Architecture

- `ChartData` owns JSON parsing, serialization, schema validation, and gameplay chart conversion.
- An in-game editor scene/control edits a working copy of the selected chart and returns the validated result to `Main`.
- An `EditorPlugin` dock uses the same `ChartData` service and JSON schema; it never forks chart validation rules.
- Runtime file dialogs read/write local chart files. The Godot dock reads/writes project chart files. Both call the same validator before saving or play.
- Existing `LevelController.set_chart()` remains the gameplay boundary. The selected audio stream and `AudioConductor` clock remain the timing source; chart beat times and events define obstacle and scoring targets.

## Failure behavior

- Invalid, unsupported, incompatible, or unfair charts cannot replace the current working chart or start a run.
- File read/write errors are surfaced in the relevant editor and leave the previous chart intact.
- Loading a chart never changes the selected audio track. A chart carries no audio path; users select its matching song separately.
- Leaving an editor without saving keeps the current session's last valid chart and does not write a file.

## Acceptance criteria

1. Both the runtime editor and Godot dock create, edit, validate, and save the same JSON chart format.
2. A chart saved by either surface can be opened by the other without losing beat timing or event kinds.
3. Runtime users can edit a generated chart, save/reload it locally, and start a run that uses the saved obstacle events and the selected song.
4. Invalid JSON, malformed values, out-of-range beats, unsupported obstacle kinds, and reaction-gap violations are rejected with readable errors and without replacing the last valid chart.
5. Existing gameplay, custom music selection, pause/restart, scoring, and Phase 1–6A tests remain intact.
6. Tests cover schema validation and serialization, runtime editor edits and file flow, plugin script loading/registration where headless validation permits, and full regression checks.

## Out of scope

Waveform rendering, audio trimming, tempo-map authoring, multiple obstacle types beyond spike/block, undo history, cloud sharing, publishing or uploading charts, persistent audio paths, and a full song package manager.
