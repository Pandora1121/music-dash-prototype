extends Node2D

func _draw() -> void:
	var viewport := get_viewport_rect().size
	for x in range(32, int(viewport.x), 64):
		draw_line(Vector2(x, 0), Vector2(x, 588), Color(0.18, 0.32, 0.56, 0.16), 1.0)
	for y in range(28, 588, 64):
		draw_line(Vector2(0, y), Vector2(viewport.x, y), Color(0.18, 0.32, 0.56, 0.11), 1.0)
	for index in range(18):
		var star_x := fposmod(float(index * 173 + 39), viewport.x)
		var star_y := fposmod(float(index * 97 + 27), 500.0)
		draw_circle(Vector2(star_x, star_y), 1.5 if index % 3 == 0 else 1.0, Color(0.39, 0.89, 1.0, 0.48))
	draw_rect(Rect2(0, 590, viewport.x, 130), Color("111a37"), true)
	draw_line(Vector2(0, 590), Vector2(viewport.x, 590), Color("43f5ff"), 3.0)
	for x in range(22, int(viewport.x), 76):
		draw_line(Vector2(x, 620), Vector2(x + 34, 620), Color(0.45, 0.58, 0.82, 0.32), 2.0)
