# MUSIC DASH Phase 8: Windows Build and Distribution

## Goal

Make the Phase 7 prototype straightforward to export as a portable 64-bit Windows build and share as a ZIP, using the existing Godot 4.7.2 project.

## Current state

- The game targets Windows and uses Godot 4.7.2 stable.
- There is no `export_presets.cfg` or repeatable export script.
- No matching templates were initially installed in the current user template directory; the official archive was downloaded and the Windows x86_64 templates were extracted to the ignored worktree-local Godot cache for this verification.
- The app uses no C# scripts, external runtime plugins, or third-party runtime assets.

## Approaches

1. **Committed Godot preset plus a PowerShell export/package script (recommended):** works from the editor or command line, keeps release settings reviewable, checks the installed Godot version, exports one self-contained executable, and creates a ZIP. It is easy to rerun locally.
2. **GitHub Actions release workflow:** automates builds on GitHub, but adds CI configuration and release credentials/workflow complexity before the prototype has a tagged release process.
3. **Editor-only manual export:** few files, but easy to forget settings and harder to reproduce.

Use approach 1. Keep exported `.exe` and `.zip` out of source control. Do not add code signing, installers, auto-updates, or a multi-platform release pipeline in this phase.

## Behavior

- Add a Windows Desktop preset named `Windows Desktop`, targeting 64-bit Windows with the PCK embedded in the executable.
- `scripts/export_windows.ps1` accepts the Godot console executable path, verifies it reports Godot 4.7.2 stable, performs a release export to `builds/windows/MusicDash.exe`, verifies the output exists and is non-empty, then packages it as `builds/windows/MusicDash-Windows-x64.zip`.
- Export errors explain that matching 4.7.2 stable export templates are required and link to the official Godot template manager guidance.
- Add a package smoke check that runs the exported executable headlessly for a bounded number of frames.
- Document installation of matching templates, export command, output location, and how to unpack/run the build.

## Acceptance

1. Godot 4.7.2 editor recognizes the committed preset.
2. The export script rejects unsupported engine versions and missing presets with actionable errors.
3. With matching templates installed, the script generates a runnable `MusicDash.exe` and ZIP under `builds/windows/`.
4. The exported binary starts in headless smoke mode and the existing 23 project test scripts still pass.
5. Build artifacts remain ignored and are not committed.

## Verification note

The export was completed with the official Godot 4.7.2 stable templates. The locally downloaded template archive/cache and exported executable/ZIP are ignored build artifacts and are not included in the source commit.
