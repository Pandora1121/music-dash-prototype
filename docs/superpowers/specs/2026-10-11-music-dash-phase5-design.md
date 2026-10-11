# MUSIC DASH Phase 5 Design: UI, Scoring, and Progression

## Goal

Make the existing rhythm-action prototype communicate run state clearly, score jumps against chart beats, and preserve simple local progression between runs.

## Scope

- Add gameplay scoring for obstacle target beats with Perfect, Great, Good, and Miss judgments.
- Show current score, combo, best combo, judgment feedback, accuracy, BPM, and song progress in the gameplay HUD.
- Show a results summary after a completed chart and a concise run summary after a crash.
- Persist best score and chart completion per difficulty locally; completing a difficulty unlocks the next difficulty in the existing order.
- Keep the current bundled song and generated chart flow. Retain restart and main-menu navigation.
- Keep custom music, song selection, chart editing, achievements, cloud saves, and a full settings menu out of scope.

## Existing behavior and constraints

The main scene builds its UI at runtime in `scripts/main.gd`. `Player.jumped(song_position)` reports the audio-clock time for a grounded jump. Generated obstacle events contain an ordered `beat_index`, and the prepared chart contains beat timestamps. `LevelController` emits chart obstacles and a completion signal. The prototype currently starts at Normal difficulty and has no scoring or persistent progression.

All judgments use the audio conductor's song-position clock and chart beat timestamps. No wall-clock timer should become the source of scoring time. Existing authored-chart fallback must remain playable; when it has no explicit beat timestamp array, event times are resolved from the chart BPM and audio offset using the same beat calculation used by `LevelController`.

## Design

### Scoring rules

Add a small scoring component that accepts the ordered chart target times and evaluates each grounded jump against the nearest unjudged target. The signed timing error is jump time minus target time. Windows are symmetric around the target: Perfect up to 45 ms, Great up to 90 ms, and Good up to 150 ms. Inputs outside Good receive no points and do not increase combo. When a target is more than 150 ms late with no qualifying jump, record one Miss, reset combo, and advance the target cursor. A jump that is too early to match the next target receives no judgment; it cannot consume a future target. Only one jump can score each target.

Award 1000 / 700 / 400 base points for Perfect / Great / Good. Increase the award by 10% per existing combo tier, capped at a 2x multiplier (combo tiers advance every 10 successful judgments). Track total score, counts by judgment, combo, best combo, and accuracy. Accuracy is weighted from successful judgments (Perfect 1.0, Great 0.75, Good 0.5, Miss 0.0) divided by all resolved targets; unresolved targets are finalized as Miss at chart completion or crash. Keep the rules in a scene-independent script so edge windows and accounting can be tested directly.

### HUD and run flow

The existing HUD gains a score and combo row, a latest-judgment indicator, and a progress bar. Its progress/time display continues to use `_audio_conductor.song_position()` and the active chart duration. The pause overlay remains available and freezes the run as it does now. Results display score, accuracy, judgment counts, and best combo. Crash display shows the same run summary compactly and retains restart/main-menu actions. The visible difficulty and current unlock should be clear in the menu; starting a locked difficulty is impossible through the UI and is also rejected by the progression boundary.

### Difficulty and local progression

Use the existing order Easy, Normal, Hard, Expert, Insane. A new save starts with Easy unlocked. The user can select among unlocked difficulties on the menu; the generated chart uses the selected difficulty. On chart completion, save the best score for that difficulty and unlock the next one. A crash may update the best score but never unlocks the next difficulty. Store a versioned JSON document under `user://` with unlocked difficulty and per-difficulty best scores/completion flags. Invalid, missing, or older save data falls back to a fresh Easy-unlocked profile; malformed fields are validated and clamped before use. Save failure must not interrupt a run or prevent showing results.

### Component boundaries

- `scripts/run_scorer.gd`: pure target-time judgment and run-stat accounting; accepts target timestamps and jump timestamps, emits/returns judgment data, and finalizes unresolved targets.
- `scripts/progression_store.gd`: validates, loads, updates, unlocks, and saves the versioned local profile; exposes unlocked difficulty and best-result queries.
- `scripts/main.gd`: owns run lifecycle, passes chart target times to the scorer, consumes jump/judgment updates, builds the HUD/results presentation, selects an unlocked difficulty, and submits completed/crashed run data to progression.

Do not refactor the entire runtime-built UI into scenes in this phase. Keep new logic isolated in the two components above and limit `main.gd` changes to integration and presentation.

## Error handling

- Ignore non-finite or negative jump and target times; validate ordered target data at scorer setup.
- Do not score one target more than once, including when input lands exactly on a judgment boundary.
- If a chart has zero score targets, results show zero accuracy and zero counts without division by zero.
- Missing or malformed progression data starts a valid default profile. A write error is non-fatal and the current session remains usable.
- Existing chart fallback, pause/resume, restart, crash, and completion behavior must remain functional.

## Acceptance criteria

1. Deterministic tests cover all timing-window boundaries, early/late input, duplicate-target prevention, Miss resolution, combo multiplier caps, and accuracy accounting.
2. The gameplay HUD changes as scoring events occur and progress tracks the current song position.
3. Completion and crash screens display accurate run statistics; restart resets per-run scoring.
4. Difficulty selection follows the unlocked order, the generated chart receives the selected difficulty, and a completion unlock persists across process starts.
5. Corrupt/missing save data and a save failure do not crash or block gameplay.
6. Existing Phase 1–4 checks and project smoke flow continue to pass.

## Deferred work

Achievements, multiple songs, custom music, chart editor, cloud profile synchronization, settings and audio calibration UI, checkpoints, and release packaging remain deferred to their roadmap phases.
