extends Node2D

const SECTION_COLORS: Array[Color] = [
	Color("43f5ff"),
	Color("b96bff"),
	Color("ff61b5"),
	Color("61ffd6"),
]

var beat_pulse_strength := 0.0
var section_tint: Color = SECTION_COLORS[0]

func on_beat(beat_index: int) -> void:
	beat_pulse_strength = 1.0 if beat_index % 4 == 0 else 0.52
	if beat_index >= 0 and beat_index % 16 == 0:
		var section_index := int(beat_index / 16) % SECTION_COLORS.size()
		section_tint = SECTION_COLORS[section_index]
	queue_redraw()

func _process(delta: float) -> void:
	var previous_strength := beat_pulse_strength
	beat_pulse_strength = move_toward(beat_pulse_strength, 0.0, delta * 3.6)
	if not is_equal_approx(previous_strength, beat_pulse_strength):
		queue_redraw()

func _draw() -> void:
	var viewport := get_viewport_rect().size
	draw_rect(Rect2(0, 0, viewport.x, 590), Color(section_tint.r, section_tint.g, section_tint.b, beat_pulse_strength * 0.045), true)
	var grid_color := section_tint
	grid_color.a = 0.16 + beat_pulse_strength * 0.34
	for x in range(32, int(viewport.x), 64):
		draw_line(Vector2(x, 0), Vector2(x, 588), grid_color, 1.0 + beat_pulse_strength)
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
		draw_line(Vector2(x, 620), Vector2(x + 34, 620), Color(0.45, 0.58, 0.82, 0.32), 2.0)
