extends Area2D

signal reached_player

@export var scroll_speed := 360.0
@export var kind: StringName = &"spike"

func _physics_process(delta: float) -> void:
	position.x -= scroll_speed * delta
	if position.x < -80.0:
		queue_free()
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("crash"):
		body.crash()
		reached_player.emit()

func _draw() -> void:
	if kind == &"block":
		draw_rect(Rect2(Vector2(-23, -27), Vector2(46, 54)), Color(1.0, 0.28, 0.48), true)
		draw_rect(Rect2(Vector2(-17, -21), Vector2(34, 42)), Color("10162b"), false, 2.0)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(-25, 27), Vector2(0, -29), Vector2(25, 27)]), Color(1.0, 0.28, 0.48))
		draw_colored_polygon(PackedVector2Array([Vector2(-12, 18), Vector2(0, -8), Vector2(12, 18)]), Color("10162b"))
