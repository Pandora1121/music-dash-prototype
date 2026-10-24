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

From the menu, choose **LOAD CUSTOM WAV** and select a local `.wav` file. The prototype accepts uncompressed 16-bit PCM WAV audio with a valid sample rate, at least two seconds of non-silent audio, and a confident tempo estimate. Files that cannot be analyzed or do not produce a playable chart are rejected; the current selection stays active and the menu shows an error. **USE BUILT-IN** restores the bundled track. The selected audio path is used for the current session only: the file is not copied into the project and its path is not saved. OGG/MP3 import is not included.

## Level Editor (Phase 6B)

The main menu's **LEVEL EDITOR** opens the runtime chart editor for the currently selected song. It creates a beat grid from the analyzed BPM, lets you cycle each beat between empty, spike, block, saw, and crystal, and validates timing and obstacle spacing before accepting edits. **LOAD** and **SAVE** exchange chart files; **PLAY** starts the selected song with the edited chart. Runtime charts are saved under `user://music_dash_charts/` by default. The selected song's audio remains session-local and is never written into chart JSON.

The Godot editor also has a **MUSIC DASH Charts** dock (right dock area). Use **NEW GRID** to set a chart name, BPM, and duration, then select a beat index and choose **SPIKE**, **BLOCK**, **SAW**, or **CRYSTAL** to place an obstacle; **REMOVE** clears that beat. **OPEN JSON** and **SAVE JSON** use the same schema as the in-game editor. The dock defaults to the project's `charts/` folder. Its plugin is enabled in `project.godot` and can be toggled in **Project > Project Settings > Plugins**.

Chart JSON version 1 stores the chart name, BPM, duration, beat times, and obstacle events. It does not store audio files or audio paths, so a chart can be shared independently of locally selected music. The editor covers beat/event authoring; waveform editing and cloud sharing are not included.

## Gameplay Polish (Phase 7)

Obstacle speed now responds to the track BPM and selected difficulty. Chart density responds to difficulty and the analyzed average music intensity; per-beat onset and bass/treble features also guide placement and shape. Easy through Insane use increasing speed/density. The chart stays deterministic for a given song analysis and seed, while spawn lead time and minimum obstacle spacing use the active speed so faster charts remain fair.

Four jumpable hazard shapes are available: spike, block, rotating saw, and pulsing crystal. The runner has lightweight run/jump/landing/crash poses, and the neon map shifts palette by musical section and reacts to beat energy. The HUD shows **JUMP IN** with a countdown, switches to **JUMP NOW** near the scoring window, tracks progress to the next combo bonus, and briefly shows **MISS • COMBO RESET** when a target is missed.

These visuals use built-in vector drawing and a fixed small set of background details. The score HUD refreshes when a judgment changes, rather than rebuilding score text every frame. Gameplay timing still comes from the audio clock; the visual polish does not change jump physics or score windows.

Art is drawn from built-in shapes, so there are no external art assets or licenses to install. The prototype audio was generated for this project and uses no sampled third-party sounds.

## Checks

Run all headless test scripts and the main script parse check from PowerShell:

```powershell
$env:APPDATA = Join-Path (Get-Location).Path '.godot-user'
$godot = (Get-Command Godot_v4.7.2-stable_win64_console.exe).Source
Get-ChildItem tests\test_*.gd | ForEach-Object {
    & $godot --headless --path . --script ("res://tests/" + $_.Name)
    if ($LASTEXITCODE -ne 0) { throw "Failed: $($_.Name)" }
}
& $godot --headless --path . --check-only --script res://scripts/main.gd
if ($LASTEXITCODE -ne 0) { throw "Main script parse check failed" }
```

If `godot` is not on `PATH`, replace it with the full path to `Godot_v4.7.2-stable_win64_console.exe`.

Check the Windows export helper contract with `pwsh -NoProfile -File tests/test_export_windows_script.ps1`.

## Windows Build (Phase 8)

This project includes a 64-bit Windows Desktop preset. Before exporting, open the project in Godot 4.7.2 stable and install the matching standard export templates from **Editor > Manage Export Templates**. The engine and template versions must match; Godot's [export guide](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html) explains template setup.

From PowerShell, run:

```powershell
$godot = (Get-Command Godot_v4.7.2-stable_win64_console.exe).Source
.\scripts\export_windows.ps1 -GodotPath $godot
```

The script validates the engine version, exports and starts the executable in a headless smoke check, then creates `builds/windows/MusicDash-Windows-x64.zip`. Extract the ZIP and run `MusicDash.exe`. The exported executable contains the project resources; the Godot project folder is not needed to play it. Build outputs are local and excluded from Git.
