extends CharacterBody2D

signal crashed
signal jumped(song_position: float)

@export var gravity: float = 1800.0
@export var jump_velocity: float = -700.0

var crashed_state := false
var timing_position := 0.0
var beat_glow_strength := 0.0
var _animation_state: StringName = &"run"
var _animation_time := 0.0

func current_animation() -> StringName:
	return _animation_state

func _set_animation(state: StringName) -> void:
	if _animation_state == state:
		return
	_animation_state = state
	_animation_time = 0.0
	queue_redraw()

func apply_beat_pulse(strength: float) -> void:
	beat_glow_strength = maxf(beat_glow_strength, clampf(strength, 0.0, 1.0))
	queue_redraw()

func _process(delta: float) -> void:
	_animation_time += delta
	beat_glow_strength = move_toward(beat_glow_strength, 0.0, delta * 3.6)
	if _animation_state == &"land" and _animation_time >= 0.18:
		_set_animation(&"run")
	else:
		queue_redraw()

func _physics_process(delta: float) -> void:
	if crashed_state:
		return
	var grounded_before_move := is_on_floor()
	if not is_on_floor():
		velocity.y += gravity * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0
	if Input.is_action_just_pressed("jump"):
		try_jump(is_on_floor())
	move_and_slide()
	if is_on_floor() and not grounded_before_move and _animation_state == &"jump":
		_set_animation(&"land")
	elif not is_on_floor() and _animation_state == &"run":
		_set_animation(&"jump")
	queue_redraw()

func try_jump(grounded: bool) -> bool:
	if crashed_state or not grounded:
		return false
	velocity.y = jump_velocity
	_set_animation(&"jump")
	jumped.emit(timing_position)
	return true

func crash() -> void:
	if crashed_state:
		return
	crashed_state = true
	velocity = Vector2.ZERO
	_set_animation(&"crash")
	crashed.emit()

func reset_player() -> void:
	crashed_state = false
	velocity = Vector2.ZERO
	rotation = 0.0
	_set_animation(&"run")

func _draw() -> void:
	var bob := sin(_animation_time * 15.0) * 1.7 if _animation_state == &"run" else 0.0
	var squash := 0.72 if _animation_state == &"land" else 1.0
	var tilt := -0.12 if _animation_state == &"jump" else 0.0
	var body := Rect2(Vector2(-17, -23), Vector2(34, 44))
	var glow_color := Color("ff527f") if _animation_state == &"crash" else Color("43f5ff")
	if _animation_state == &"crash":
		for index in range(8):
			var angle := TAU * float(index) / 8.0
			var inner := Vector2(cos(angle), sin(angle)) * 27.0
			var outer := Vector2(cos(angle), sin(angle)) * (39.0 + fposmod(_animation_time * 22.0 + float(index * 7), 10.0))
			draw_line(inner, outer, Color(1.0, 0.28, 0.48, 0.78), 2.0)
	if _animation_state == &"run" and beat_glow_strength > 0.1:
		for trail_index in range(3):
			var trail_rect := body
			trail_rect.position.x -= float(trail_index + 1) * (8.0 + beat_glow_strength * 6.0)
			draw_rect(trail_rect, Color(glow_color.r, glow_color.g, glow_color.b, 0.10 - trail_index * 0.025), true)
	draw_rect(body.grow(7.0 + beat_glow_strength * 9.0), Color(glow_color.r, glow_color.g, glow_color.b, 0.12 + beat_glow_strength * 0.24), true)
	draw_set_transform(Vector2(0.0, bob), tilt, Vector2(1.0, squash))
	draw_colored_polygon(PackedVector2Array([Vector2(-15, -22), Vector2(10, -22), Vector2(17, -12), Vector2(17, 18), Vector2(-15, 18)]), glow_color)
	draw_rect(Rect2(Vector2(-7, -14), Vector2(18, 5)), Color("071326"), true)
	draw_rect(Rect2(Vector2(4, -14), Vector2(4, 4)), Color.WHITE, true)
	var stride := sin(_animation_time * 17.0) * 5.0 if _animation_state == &"run" else 0.0
	var leg_spread := 6.0 if _animation_state == &"jump" else 0.0
	draw_line(Vector2(-7, 18), Vector2(-8.0 - leg_spread, 26.0 + stride), Color.WHITE, 4.0)
	draw_line(Vector2(8, 18), Vector2(8.0 + leg_spread, 26.0 - stride), Color.WHITE, 4.0)
	draw_line(Vector2(-13, 27.0 + stride), Vector2(-3 - leg_spread, 27.0 + stride), Color("43f5ff"), 3.0)
	draw_line(Vector2(4 + leg_spread, 27.0 - stride), Vector2(14, 27.0 - stride), Color("43f5ff"), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
