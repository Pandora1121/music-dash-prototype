# MUSIC DASH Phase 6A Design: Custom Music

## Goal

Let a Windows player choose a local WAV file and play a rhythm-action chart generated from that song, while keeping the bundled prototype song as the safe default. This is the first part of Phase 6; the Level Editor follows as Phase 6B.

## Scope

- Add a song source choice for the bundled prototype track or a player-selected local WAV.
- Support WAV files that `MusicAnalyzer` can analyze: uncompressed 16-bit PCM, valid sample rate, non-silent audio, at least two seconds long, and a confident tempo estimate.
- Generate a deterministic chart for the selected difficulty from the selected song analysis, using the current fairness rules and chart seed.
- Play the same selected audio stream that produced the analysis, using `AudioConductor`'s playback clock for gameplay timing.
- Show the selected file name and useful analysis details such as BPM and duration in the menu.
- Explain unsupported or invalid files in the menu. A failed selection must not replace the currently selected song or interrupt gameplay.
- Keep the selection session-local. Do not copy, upload, or persist user audio paths.
- Leave manual obstacle editing out of this subphase; it is planned for Phase 6B.

## User flow

1. The menu starts with the bundled prototype song selected.
2. The player chooses Custom WAV and opens the native Godot file dialog filtered to WAV files.
3. The loader opens and validates the file, then runs `MusicAnalyzer` before accepting it.
4. On success, the menu displays the filename, estimated BPM, and duration; starting a run generates and caches a chart for the selected difficulty and deterministic seed.
5. Changing difficulty regenerates the chart for the same selected analysis. Restart reuses the prepared chart and selected stream.
6. Canceling the dialog leaves the current selection unchanged. Invalid, unsupported, silent, too-short, or low-confidence audio shows a readable error and also leaves the current selection unchanged.

## Architecture

- Add a small `CustomMusicLoader` service that checks the path/extension, loads with Godot's `AudioStreamWAV.load_from_file`, invokes `MusicAnalyzer`, and returns either a complete valid track record (`stream`, `analysis`, `path`, `display_name`) or a failure reason. It must not mutate global gameplay state.
- Add an explicit stream-selection method to `AudioConductor`; its existing bundled stream remains the default. Starting, pausing, resuming, stopping, and querying song position continue through the same `AudioStreamPlayer` and beat clock.
- Update `Main` to own the selected track record, file dialog, source controls, and prepared chart. Commit a new selection only after loader and chart validation succeeds.
- Reuse `ProceduralChartGenerator`, `LevelController`, and `RunScorer`; derive targets and progress duration from the selected analysis/chart, not the bundled track constants.
- Keep analysis synchronous for this prototype. Show a clear preparing state if needed, and do not start playback until analysis and chart preparation have succeeded.

## Failure handling

- Reject paths that cannot be opened, non-WAV extensions, null streams, unsupported PCM formats, invalid sample rates, malformed sample buffers, silence, clips shorter than the analyzer minimum, and analysis without sufficient tempo confidence.
- Surface the analyzer's user-readable reason in the menu and retain the current selected track and difficulty.
- If chart generation fails after a successful analysis, reject the selection and retain the previous track.
- The built-in song remains playable regardless of custom file failures.

## Acceptance criteria

1. A new profile still opens with the bundled song selected and the current Phase 1–5 flow remains unchanged.
2. A supported local WAV loads, analyzes, appears in the menu, and can be played with the chart generated from its beat times and selected difficulty.
3. The chart and run are deterministic for the same song analysis, seed, and difficulty; restart does not silently switch to the bundled song or regenerate a different chart.
4. The conductor's playback clock remains the sole gameplay timing source for custom and bundled songs, including pause/resume and restart.
5. Changing difficulty regenerates a fair chart from the selected song without reselecting the file.
6. Cancel, unsupported format, malformed/unsupported PCM, silence, short audio, and low-confidence analysis leave the active selection intact and show a useful message.
7. Headless tests cover loader validation, success and failure selection behavior, chart integration, and existing regression checks.

## Out of scope

OGG/MP3 decoding or analysis, arbitrary codecs, copying imported songs into the project, persistent custom-file paths, cloud uploads, per-song profile history, manual chart editing, visual polish, and release packaging. These can be considered in later phases without changing this interface.
