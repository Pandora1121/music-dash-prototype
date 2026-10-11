# MUSIC DASH

A Windows-first rhythm action prototype made with Godot 4.7.2 and GDScript.

## Run

1. Install Godot 4.7.2 or a compatible Godot 4.x editor.
2. Open this folder's `project.godot` in Godot.
3. Press **F6** to run the main scene or **F5** to run the project.

## Controls

- **Space / Up:** jump
- **Esc:** pause or resume
- **Enter:** restart after a crash or level clear

The prototype includes an original, synthesized 120 BPM drum loop (`assets/audio/music_dash_prototype.wav`). The audio playback clock is the source for the level timeline, obstacle scheduling, song progress, and jump timestamps. Beat timing includes a configurable `audio_offset_seconds` value on the `AudioConductor` node; positive values move beat events later and negative values move them earlier. Audio playback position is estimated from Godot's playback position, time since the last mix, and output latency.

Phase 4 analyzes the bundled WAV as uncompressed PCM when a run starts, then prepares a seeded obstacle chart from its estimated tempo and musical energy. Low-confidence or unsupported audio uses the authored 120 BPM chart. The prepared chart is reused after a restart so the prototype stays deterministic.

Phase 5 scores jumps against chart obstacle beats with Perfect, Great, Good, and Miss timing judgments. The HUD shows score, combo, accuracy, judgment feedback, BPM, and song progress; run results include judgment counts and best combo. Easy is unlocked for a new profile, and completing a chart unlocks the next difficulty. Best scores and unlocks are saved locally as `user://music_dash_profile.json`.

## Custom Music (Phase 6A)

From the menu, choose **LOAD CUSTOM WAV** and select a local `.wav` file. The prototype accepts uncompressed 16-bit PCM WAV audio with a valid sample rate, at least two seconds of non-silent audio, and a confident tempo estimate. Files that cannot be analyzed or do not produce a playable chart are rejected; the current selection stays active and the menu shows an error. **USE BUILT-IN** restores the bundled track. The selected audio path is used for the current session only: the file is not copied into the project and its path is not saved. OGG/MP3 import and the Phase 6B Level Editor are not included in this increment.

Art is drawn from built-in shapes, so there are no external art assets or licenses to install. The prototype audio was generated for this project and uses no sampled third-party sounds.

## Checks

Run the headless checks from PowerShell:

```powershell
$env:APPDATA = Join-Path (Get-Location).Path '.godot-user'
godot --headless --path . --script res://tests/test_project_smoke.gd
godot --headless --path . --script res://tests/test_player_rules.gd
godot --headless --path . --script res://tests/test_obstacle_chart.gd
godot --headless --path . --script res://tests/test_level_controller.gd
godot --headless --path . --script res://tests/test_beat_chart.gd
godot --headless --path . --script res://tests/test_music_analyzer.gd
godot --headless --path . --script res://tests/test_procedural_chart_generator.gd
godot --headless --path . --script res://tests/test_phase4_integration.gd
godot --headless --path . --script res://tests/test_run_scorer.gd
godot --headless --path . --script res://tests/test_progression_store.gd
godot --headless --path . --script res://tests/test_phase5_integration.gd
```

If `godot` is not on `PATH`, replace it with the full path to `Godot_v4.7.2-stable_win64_console.exe`.

Windows export requires matching Godot 4.7.2 export templates.
