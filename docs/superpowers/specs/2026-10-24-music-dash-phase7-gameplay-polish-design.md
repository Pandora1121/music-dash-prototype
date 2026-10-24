# MUSIC DASH Phase 7: Gameplay and Visual Polish

## Intent

Finish the prototype's requested polish pass so a run communicates rhythm more clearly and feels connected to the selected music and difficulty. The player asked for improved UI and map, character animation, more obstacle shapes, level/music-based speed and obstacle counts, and a clear Miss/combo cue that helps with timing.

## Goals

- Keep the project on Godot 4.7.2, GDScript, 2D, and the existing audio playback clock.
- Give each music/difficulty combination a deterministic gameplay profile: obstacle speed and density scale with BPM, measured music energy, and selected difficulty.
- Keep chart fairness tied to actual obstacle speed, including travel lead time and minimum reaction spacing.
- Add two recognizable procedural obstacle shapes while preserving the current spike/block charts and supporting the added kinds in both chart editors.
- Add low-cost geometric character run/jump/land/crash animation and a reactive parallax map that changes color/intensity with musical sections.
- Make live timing actionable in the HUD: countdown to next scoring beat, a visible combo milestone meter, and unmistakable Miss/combo reset feedback.
- Verify the previous 18 tests and add targeted Phase 7 tests; document the result.

## Non-goals

- No new platform, game mode, network feature, audio middleware, imported paid art, or unrelated rewrite.
- No waveform editor, new audio formats, or change to the Phase 6B chart file's version number.
- No Windows export in this phase; that remains the later build phase from the original roadmap.
- No external asset downloads are needed: procedural shapes keep the prototype light, license-simple, and visually consistent.

## Approaches considered

1. **Procedural 2D polish inside the existing game loop (chosen).** Add a small gameplay profile service, extend the existing vector-rendered player/obstacle/world, and update the current HUD. This preserves the audio-clock architecture, keeps iteration fast, and avoids adding third-party assets.
2. **Download free sprite packs and replace the current shapes.** This may produce richer art quickly, but adds attribution/license and import management, can clash with the current neon style, and doesn't solve timing/gameplay feedback.
3. **Rebuild the scene and progression architecture.** This allows a broad redesign but creates migration risk across already-tested scoring, custom music, and both chart editors without improving this prototype's core timing as directly.

## Gameplay profile

`GameplayProfile` is deterministic for the selected analysis and difficulty. Starting scroll speed is 360 px/s. Multiply by `clamp(pow(bpm / 120, 0.25), 0.85, 1.18)` and a difficulty factor: Easy 0.88, Normal 0.96, Hard 1.04, Expert 1.13, Insane 1.22; clamp final speed to 280–520 px/s. Difficulty base event chances are 0.18, 0.28, 0.40, 0.52, and 0.64. Scale chance by `0.85 + 0.35 * average_intensity` (average intensity is clamped 0–1), then clamp to 0.15–0.82. Per-beat selection still favors clear onsets and stronger musical energy.

The chart generator receives the effective speed and enforces at least `0.8 + 48 / speed` seconds between obstacle target times, plus the existing spawn warning distance. `LevelController` computes obstacle spawn lead time from that same effective speed. User-authored charts are validated and played at their selected difficulty's effective speed; if a chart is not fair at that speed, it is refused with a useful reason rather than silently changing its timing.

## Visual and interaction behavior

- New event kinds are `saw` and `crystal`, alongside `spike` and `block`. All remain single-lane, jumpable hazards with shape-appropriate collision geometry. Both chart editors can create all four.
- The player keeps its current collision/physics dimensions; only its vector drawing animates. Run bob, jump pose, landing squash, beat glow, and crash burst do not change jump timing.
- The world remains the same lane and screen geometry. Its parallax stars/lane markings and section palette move/pulse from audio time, not arbitrary obstacles or frame-based gameplay.
- The HUD shows time to the next score target and switches to `JUMP NOW` around the Good timing window. Each successful judgment advances the cue. A Miss flashes a combo reset message, then the countdown resumes. A small meter shows progress to the next score multiplier.
- The screen remains readable at the current 1280x720 viewport, with no new full-screen visual effects that cover hazards.

## Performance and compatibility

- Use built-in drawing and a small fixed number of nodes; no per-frame obstacle creation beyond scheduled chart events.
- Keep procedural choices seeded. Keep score targets and obstacle target times sourced from chart beats/audio position.
- Preserve schema version 1, old spike/block chart JSON, custom WAV behavior, and Phase 1–6B tests.
- Avoid recomputing score text when score state has not changed.

## Acceptance

- A BPM/energy/difficulty matrix proves speed and event chance change in the expected direction and remain bounded.
- Generated obstacle events are deterministic for a seed, use only supported kinds, respect music features, and remain fair at the chosen speed.
- Variable-speed spawn timing equals `(spawn_x - player_x) / effective_speed` and does not change beat hit targets.
- Both editors accept/save/load the four kinds; old JSON is still accepted.
- Character/world state tests cover run, jump/landing/crash, and profile-driven environment response.
- HUD integration tests cover countdown, successful combo progress, and Miss reset feedback.
- All tests pass; Godot project/main scripts and headless editor/plugin load without script errors.
