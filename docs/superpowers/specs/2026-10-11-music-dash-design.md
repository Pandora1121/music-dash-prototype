# MUSIC DASH Prototype Design

## Goal

Build a playable Windows-first rhythm action prototype that establishes the movement, beat timing, obstacle patterns, and score feedback. The prototype is the first phase of the larger MUSIC DASH brief; it is not a static mockup.

## Engine and language

- **Engine:** Godot 4.x, using its native 2D renderer and scene system.
- **Language:** GDScript, to keep iteration fast and avoid external runtime dependencies.
- **Target:** Windows desktop. Keep gameplay, audio timing, and UI in separate scenes/scripts so other platforms can be considered later.
- **Distribution:** A Godot project that can be opened in the editor and exported as a Windows build when the matching export templates are installed.

Godot is selected because the game needs responsive 2D movement, audio playback, input handling, and a path to a native Windows build. The project currently has no engine or codebase, so this prototype can use a clean scene structure.

## Prototype scope

The first playable slice contains one short, replayable level with a neon track, an auto-running character, beat-timed jump obstacles, a readable HUD, a result state, and restart. The controls are Space or Up to jump, Esc to pause, and a visible restart action after a collision or level completion. Obstacles use a deterministic pattern and fixed tempo so the first version is reproducible and fair.

The prototype includes a bundled original/synthetic beat track or a simple generated rhythm source, a beat timeline, configurable audio offset, and scoring windows for Perfect, Great, Good, and Miss. Gameplay timing is derived from the audio playback position, with elapsed-time fallback only for safe event processing across frames. A small debug overlay can show playback position, BPM, next beat, and the latest judgment.

## Architecture

- `Main` owns scene flow and transitions between menu, gameplay, pause, and results.
- `AudioConductor` owns playback and exposes the authoritative song position, BPM, beat events, and offset.
- `Player` owns input, jump motion, and collision feedback.
- `Level` owns a deterministic obstacle chart and spawns obstacles from beat timestamps.
- `ScoreManager` owns timing judgments, combo, accuracy, and results.
- `HUD` displays score, combo, accuracy, song progress, and optional debug timing data.

Keep the first chart authored as data in the project. This avoids promising automatic music analysis before the basic audio/gameplay synchronization is proven. Use placeholder shapes and built-in visuals; optional prototype sound effects may come from Kenney's free CC0 audio packs, with the source and license recorded in the project. The core game must still run if those optional assets are absent.

## Acceptance criteria

1. The project opens in Godot 4.x and can run the prototype scene.
2. The player can jump, collide with obstacles, receive timing judgments, pause, restart, and reach a results state.
3. Beat-driven obstacles and feedback remain tied to the audio playback clock after pause/resume and frame delays.
4. The same level chart and tempo produce the same obstacle sequence on each restart.
5. The HUD and debug overlay expose enough timing information to diagnose obvious synchronization problems.
6. The README explains the Godot version, controls, project launch steps, and Windows export prerequisites.

## Deferred work

Campaign progression, endless/practice/challenge modes, custom music import, automatic BPM/onset analysis, procedural chart generation, checkpoints, achievements, level editor, advanced effects, performance tuning, and release-quality Windows packaging are later phases. They should build on the verified timing and movement foundation from this prototype.

## Hardware and constraints

The prototype uses Godot's 2D renderer and simple geometry to support modest Windows hardware. No dedicated GPU, external plugin, or network access is required to run the project in the editor. A Windows export requires a compatible Godot export template installation.
