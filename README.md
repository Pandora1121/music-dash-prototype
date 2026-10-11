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

The Phase 1 prototype has a fixed, deterministic 120 BPM obstacle chart and uses the game clock. Audio playback synchronization is the next phase. Art is drawn from built-in shapes, so there are no external assets or licenses to install.

## Checks

Run the headless checks from PowerShell:

```powershell
$env:APPDATA = Join-Path (Get-Location).Path '.godot-user'
godot --headless --path . --script res://tests/test_project_smoke.gd
godot --headless --path . --script res://tests/test_player_rules.gd
godot --headless --path . --script res://tests/test_obstacle_chart.gd
godot --headless --path . --script res://tests/test_level_controller.gd
```

If `godot` is not on `PATH`, replace it with the full path to `Godot_v4.7.2-stable_win64_console.exe`.

Windows export requires matching Godot 4.7.2 export templates.
