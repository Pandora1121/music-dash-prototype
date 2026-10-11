extends CharacterBody2D

signal crashed
signal jumped(song_position: float)

@export var gravity: float = 1800.0
@export var jump_velocity: float = -700.0

var crashed_state := false
var timing_position := 0.0

func _physics_process(delta: float) -> void:
	if crashed_state:
		return
	if not is_on_floor():
		velocity.y += gravity * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0
	if Input.is_action_just_pressed("jump"):
		try_jump(is_on_floor())
	move_and_slide()
	queue_redraw()

func try_jump(grounded: bool) -> bool:
	if crashed_state or not grounded:
		return false
	velocity.y = jump_velocity
	jumped.emit(timing_position)
	return true

func crash() -> void:
	if crashed_state:
		return
	crashed_state = true
	velocity = Vector2.ZERO
	crashed.emit()

func reset_player() -> void:
	crashed_state = false
	velocity = Vector2.ZERO
	rotation = 0.0

func _draw() -> void:
	var body := Rect2(Vector2(-18, -26), Vector2(36, 52))
	draw_rect(body.grow(7), Color(0.05, 0.9, 1.0, 0.12), true)
	draw_rect(body, Color("48f5ff"), true)
	draw_rect(Rect2(Vector2(-9, -16), Vector2(17, 4)), Color("071326"), true)
	draw_colored_polygon(PackedVector2Array([Vector2(13, -8), Vector2(24, 0), Vector2(13, 8)]), Color.WHITE)
