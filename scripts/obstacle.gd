extends Area2D

signal reached_player

@export var scroll_speed := 360.0
@export var kind: StringName = &"spike"

var _animation_time := 0.0

func _ready() -> void:
	var collider := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if is_instance_valid(collider):
		collider.shape = _collision_shape_for_kind()

func _process(delta: float) -> void:
	if kind == &"saw":
		rotation += delta * 3.2
		queue_redraw()
	elif kind == &"crystal":
		_animation_time += delta
		queue_redraw()

func _physics_process(delta: float) -> void:
	position.x -= scroll_speed * delta
	if position.x < -80.0:
		queue_free()
	queue_redraw()

func _collision_shape_for_kind() -> Shape2D:
	match kind:
		&"block":
			var rectangle := RectangleShape2D.new()
			rectangle.size = Vector2(46.0, 54.0)
			return rectangle
		&"saw":
			var circle := CircleShape2D.new()
			circle.radius = 25.0
			return circle
		&"crystal":
			var diamond := ConvexPolygonShape2D.new()
			diamond.points = PackedVector2Array([Vector2(-23.0, 0.0), Vector2(0.0, -31.0), Vector2(23.0, 0.0), Vector2(0.0, 31.0)])
			return diamond
		_:
			var triangle := ConvexPolygonShape2D.new()
			triangle.points = PackedVector2Array([Vector2(-25.0, 27.0), Vector2(0.0, -29.0), Vector2(25.0, 27.0)])
			return triangle

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("crash"):
		body.crash()
		reached_player.emit()

func _draw() -> void:
	if kind == &"block":
		draw_rect(Rect2(Vector2(-23, -27), Vector2(46, 54)), Color(1.0, 0.28, 0.48), true)
		draw_rect(Rect2(Vector2(-17, -21), Vector2(34, 42)), Color("10162b"), false, 2.0)
	elif kind == &"saw":
		var teeth := PackedVector2Array()
		for index in range(16):
			var angle := TAU * float(index) / 16.0
			var radius := 29.0 if index % 2 == 0 else 21.0
			teeth.append(Vector2(cos(angle), sin(angle)) * radius)
		draw_colored_polygon(teeth, Color("ff5c9a"))
		draw_circle(Vector2.ZERO, 13.0, Color("11162b"))
		draw_circle(Vector2.ZERO, 5.0, Color("ffd36b"))
	elif kind == &"crystal":
		var pulse := 0.78 + 0.22 * sin(_animation_time * 7.0)
		draw_colored_polygon(PackedVector2Array([Vector2(0, -32), Vector2(24, 0), Vector2(0, 32), Vector2(-24, 0)]), Color(0.27, 0.95, 1.0, pulse))
		draw_colored_polygon(PackedVector2Array([Vector2(0, -22), Vector2(8, 0), Vector2(0, 21), Vector2(-6, 0)]), Color("e8ffff"))
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(-25, 27), Vector2(0, -29), Vector2(25, 27)]), Color(1.0, 0.28, 0.48))
		draw_colored_polygon(PackedVector2Array([Vector2(-12, 18), Vector2(0, -8), Vector2(12, 18)]), Color("10162b"))
