extends Node2D

const SECTION_COLORS: Array[Color] = [
	Color("43f5ff"),
	Color("b96bff"),
	Color("ff61b5"),
	Color("61ffd6"),
]

var beat_pulse_strength := 0.0
var section_tint: Color = SECTION_COLORS[0]
var section_index := 0
var average_music_intensity := 0.5
var _difficulty_tint := Color("43f5ff")
var _parallax_offset := 0.0

func set_music_profile(analysis: Dictionary, difficulty: StringName) -> void:
	var features: Variant = analysis.get("beat_features", [])
	var intensity_total := 0.0
	var intensity_count := 0
	if features is Array:
		for feature in features:
			if feature is Dictionary and typeof(feature.get("intensity", null)) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(feature.intensity)):
				intensity_total += clampf(float(feature.intensity), 0.0, 1.0)
				intensity_count += 1
	average_music_intensity = intensity_total / float(intensity_count) if intensity_count > 0 else 0.5
	match difficulty:
		&"Easy": _difficulty_tint = Color("51e8b8")
		&"Normal": _difficulty_tint = Color("43f5ff")
		&"Hard": _difficulty_tint = Color("83a7ff")
		&"Expert": _difficulty_tint = Color("c47cff")
		&"Insane": _difficulty_tint = Color("ff5c9a")
		_: _difficulty_tint = Color("43f5ff")
	section_index = 0
	section_tint = SECTION_COLORS[0].lerp(_difficulty_tint, 0.28)
	queue_redraw()

func on_beat(beat_index: int, intensity: float = -1.0) -> void:
	var music_strength := average_music_intensity if intensity < 0.0 or not is_finite(intensity) else clampf(intensity, 0.0, 1.0)
	var downbeat_strength := 1.0 if beat_index % 4 == 0 else 0.52
	var energy_pulse := lerpf(0.52, 0.78, music_strength)
	beat_pulse_strength = maxf(beat_pulse_strength, maxf(downbeat_strength, energy_pulse))
	if beat_index >= 0 and beat_index % 16 == 0:
		section_index = int(beat_index / 16) % SECTION_COLORS.size()
		section_tint = SECTION_COLORS[section_index].lerp(_difficulty_tint, 0.28 + average_music_intensity * 0.18)
	queue_redraw()

func _process(delta: float) -> void:
	beat_pulse_strength = move_toward(beat_pulse_strength, 0.0, delta * 3.6)
	_parallax_offset = fposmod(_parallax_offset + delta * (16.0 + average_music_intensity * 36.0), 4096.0)
	queue_redraw()

func _draw() -> void:
	var viewport := get_viewport_rect().size
	var map_energy := clampf(average_music_intensity * 0.45 + beat_pulse_strength * 0.2, 0.0, 0.65)
	draw_rect(Rect2(0, 0, viewport.x, 590), Color(section_tint.r, section_tint.g, section_tint.b, 0.025 + map_energy * 0.08), true)
	for skyline_index in range(15):
		var skyline_x := fposmod(float(skyline_index * 113) - _parallax_offset * 0.16, viewport.x + 90.0) - 45.0
		var skyline_height := 36.0 + float((skyline_index * 37) % 58)
		var skyline_color := section_tint
		skyline_color.a = 0.08 + average_music_intensity * 0.08
		draw_rect(Rect2(skyline_x, 570.0 - skyline_height, 38.0 + float(skyline_index % 3) * 13.0, skyline_height), skyline_color, true)
	var grid_color := section_tint
	grid_color.a = 0.10 + beat_pulse_strength * (0.20 + average_music_intensity * 0.2)
	for x in range(32, int(viewport.x) + 64, 64):
		var parallax_x := fposmod(float(x) - _parallax_offset * 0.35, viewport.x)
		draw_line(Vector2(parallax_x, 0), Vector2(parallax_x, 588), grid_color, 1.0 + beat_pulse_strength * 0.6)
	for y in range(28, 588, 64):
		var horizontal_color := grid_color
		horizontal_color.a *= 0.72
		draw_line(Vector2(0, y), Vector2(viewport.x, y), horizontal_color, 1.0)
	for index in range(18):
		var star_x := fposmod(float(index * 173 + 39), viewport.x)
		var star_y := fposmod(float(index * 97 + 27), 500.0)
		draw_circle(Vector2(star_x, star_y), 1.5 if index % 3 == 0 else 1.0, Color(0.39, 0.89, 1.0, 0.48))
	draw_rect(Rect2(0, 590, viewport.x, 130), Color("111a37"), true)
	draw_line(Vector2(0, 590), Vector2(viewport.x, 590), Color("43f5ff"), 3.0)
	for x in range(22, int(viewport.x), 76):
		var lane_x := fposmod(float(x) - _parallax_offset, viewport.x + 76.0) - 38.0
		draw_line(Vector2(lane_x, 620), Vector2(lane_x + 34, 620), Color(0.45, 0.58, 0.82, 0.32 + average_music_intensity * 0.12), 2.0)
