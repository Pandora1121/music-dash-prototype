# MUSIC DASH Phase 4 Design: Music Analysis and Procedural Charts

## Goal

Analyze the bundled prototype song before a run, estimate its beat grid and musical energy, then generate a deterministic, fair obstacle chart from those features. Keep a safe authored-chart fallback so an unsupported or ambiguous song can still be played.

## Scope

- Analyze the bundled WAV used by the prototype. Custom file selection and import UI remain in Phase 6.
- Estimate BPM, beat times, onset strength, bass/mid/treble energy, overall intensity, and relative energy sections.
- Generate an obstacle chart for Easy, Normal, Hard, Expert, and Insane using a supplied seed.
- Preserve a deterministic fallback chart at 120 BPM when input audio is unsupported, silent, too short, or has low BPM confidence.
- Keep chart generation separate from playback, which continues to use `AudioConductor`'s audio clock.
- Do not add external runtime dependencies, GDExtensions, or authored-song semantics such as guaranteed verse/chorus labels.

## Approach

`MusicAnalyzer` runs synchronously before playback and analyzes decoded 16-bit PCM from `AudioStreamWAV`. The bundled WAV import setting changes from QOA to uncompressed PCM so analysis reads the same samples the game plays. The prototype's 21-second file is small enough for an offline GDScript pass during the start flow. Godot documents `AudioStreamWAV.data` as sample bytes and WAV import mode 0 as uncompressed PCM ([AudioStreamWAV](https://docs.godotengine.org/en/4.7/classes/class_audiostreamwav.html), [ResourceImporterWAV](https://docs.godotengine.org/en/4.6/classes/class_resourceimporterwav.html)).

The analyzer folds stereo input to mono, computes short-window RMS and representative bass, mid, and treble energy, derives onset strength from positive energy changes, and estimates BPM by autocorrelation over 60–180 BPM. It aligns a beat grid to the strongest nearby onset and samples normalized audio features at each beat. Relative energy over groups of 16 beats is labeled calm, build, or peak; these labels describe measured intensity and do not claim semantic verse/chorus recognition.

`ProceduralChartGenerator` uses the analysis, difficulty, and a fixed seed to select beats and obstacle kinds. Stronger onsets are more likely to receive events; bass and treble features guide the visual kind. All difficulties retain the same fairness guard: consecutive target times must leave at least 0.8 seconds of reaction time after accounting for the obstacle's 48-pixel collision width at the current 360-pixel/second scroll speed. Events before the player can reasonably receive warning are omitted. The generated chart is returned as data and supplied to `LevelController`; it does not change audio playback or physics.

If analysis fails validation or falls below the confidence threshold, the main flow uses the existing authored `ObstacleChart` and its 120 BPM value. Replaying a prepared run reuses the same chart and seed instead of regenerating a different sequence.

## Components and interfaces

- `MusicAnalyzer.analyze(stream: AudioStreamWAV) -> Dictionary` returns `status`, `bpm`, `confidence`, `duration_seconds`, `beat_times`, per-beat feature dictionaries, and relative energy sections. Failure returns a status and reason without throwing or emitting partial invalid data.
- `ProceduralChartGenerator.generate(analysis: Dictionary, difficulty: StringName, seed: int, scroll_speed: float) -> Dictionary` returns a chart with seed, BPM, duration, and ordered events (`beat_index`, `kind`). Invalid analysis returns an explicit failure result.
- `LevelController.set_chart(chart: Dictionary) -> void` accepts validated events and BPM before `begin_level()`; the existing authored chart remains the default.
- `Main` prepares analysis and chart once before starting audio, selects the authored fallback when required, and passes the prepared chart to the conductor and level controller.

## Failure handling and fairness

- Reject null streams, non-PCM formats, unsupported bit depth, invalid sample rate, silence, and clips too short to establish a stable tempo.
- Report analysis status and confidence for the debug view/log; never start a generated chart with a zero or non-finite BPM.
- If autocorrelation has no sufficiently strong, stable tempo candidate, play the authored fallback.
- Remove generated events that violate the minimum reaction-time rule, regardless of difficulty. Difficulty changes density and event selection, not the fairness minimum.
- Seeded generation must return byte-for-byte equivalent event dictionaries for the same analysis, difficulty, seed, and scroll speed.

## Testing and acceptance

1. The bundled synthetic track estimates 120 BPM within a tolerance of 2 BPM and produces increasing beat timestamps with finite normalized feature values.
2. Silent, short, unsupported, or malformed audio returns a failed analysis result that selects the authored fallback without a runtime error.
3. Identical input and seed produce identical events; a different seed can change a chart with enough eligible beats.
4. Every difficulty produces only supported obstacle kinds, sorted beat indices, no events before the warning window, and at least 0.8 seconds of reaction time after travel collision width is accounted for.
5. The main smoke flow starts with the generated chart for confident audio, uses fallback otherwise, and keeps playback position as gameplay's timing source.
6. All existing Phase 1–3 tests continue to pass.

## Deferred work

Custom music selection and decoding, editor tooling, manual chart edits, advanced tempo-change tracking, automatic semantic section labels, and user-facing BPM correction remain out of scope for Phase 4. Phase 6 can add supported formats and UI by passing their decoded audio through the same analyzer interface.
