extends Node2D

signal landed_on(circle: Node2D)
signal player_died(reason: String)

enum State { ON_CIRCLE, JUMPING, LANDING, DEAD }

const JUMP_SPEED    := 500.0
const PLAYER_RADIUS := 12.0
const PLAYER_COLOR  := Color(1.0, 0.85, 0.2)
const DEAD_COLOR    := Color(1.0, 0.2, 0.2)
const ARROW_COLOR   := Color(1.0, 1.0, 1.0, 0.85)
const MAX_TRAVEL    := 1400.0  # mata se voar longe demais sem pousar

var state: State = State.ON_CIRCLE

var current_circle:     Node2D = null
var destination_circle: Node2D = null

var jump_direction: Vector2 = Vector2.ZERO
var traveled: float = 0.0

# Direção atual da seta em espaço-mundo, atualizada a cada frame.
var _arrow_dir: Vector2 = Vector2.RIGHT


func _draw() -> void:
	var color := DEAD_COLOR if state == State.DEAD else PLAYER_COLOR
	draw_circle(Vector2.ZERO, PLAYER_RADIUS, color)

	if state == State.ON_CIRCLE and current_circle:
		_draw_direction_arrow()


func _draw_direction_arrow() -> void:
	var r: float = current_circle.get("circle_radius")
	var tip  := _arrow_dir * (r - 6.0)
	var stem := _arrow_dir * (PLAYER_RADIUS + 4.0)

	# Haste
	draw_line(stem, tip - _arrow_dir * 14.0, ARROW_COLOR, 2.5)

	# Ponta triangular
	var perp := _arrow_dir.rotated(PI * 0.5)
	var pts  := PackedVector2Array([
		tip,
		tip - _arrow_dir * 14.0 + perp * 7.0,
		tip - _arrow_dir * 14.0 - perp * 7.0,
	])
	draw_colored_polygon(pts, ARROW_COLOR)


func _process(delta: float) -> void:
	match state:
		State.ON_CIRCLE: _tick_on_circle()
		State.JUMPING:   _tick_jump(delta)
		State.LANDING:   pass  # tween cuida do movimento


# ---------------------------------------------------------------------------
# API pública
# ---------------------------------------------------------------------------

func attach_to_circle(circle: Node2D) -> void:
	current_circle     = circle
	destination_circle = null
	traveled           = 0.0
	state              = State.ON_CIRCLE
	global_position    = circle.global_position
	queue_redraw()


func jump_to(target: Node2D) -> void:
	if state != State.ON_CIRCLE:
		return
	destination_circle = target
	jump_direction     = _arrow_dir.normalized()
	traveled           = 0.0
	state              = State.JUMPING


func respawn(circle: Node2D) -> void:
	attach_to_circle(circle)


# ---------------------------------------------------------------------------
# Tick helpers
# ---------------------------------------------------------------------------

func _tick_on_circle() -> void:
	if not current_circle:
		return
	global_position = current_circle.global_position
	var rot_root := current_circle.get_node("RotationRoot") as Node2D
	_arrow_dir = Vector2.RIGHT.rotated(rot_root.rotation)
	queue_redraw()


func _tick_jump(delta: float) -> void:
	var step := jump_direction * JUMP_SPEED * delta
	global_position += step
	traveled        += step.length()

	if traveled > MAX_TRAVEL:
		_die("missed")
		return

	if not destination_circle:
		return

	var dist := global_position.distance_to(destination_circle.global_position)
	if dist <= destination_circle.circle_radius + PLAYER_RADIUS * 0.5:
		_resolve_landing()


func _resolve_landing() -> void:
	var circle := destination_circle

	# Ângulo de chegada: vetor do centro do círculo destino → posição do player
	var to_player       := global_position - circle.global_position
	var world_angle_deg := rad_to_deg(to_player.angle())

	# Snapa o player exatamente na borda
	global_position = circle.global_position \
		+ Vector2.RIGHT.rotated(deg_to_rad(world_angle_deg)) * circle.circle_radius

	if circle.is_landing_valid(world_angle_deg):
		_slide_to_center(circle)
	else:
		_die(circle.last_fail_reason)


func _slide_to_center(circle: Node2D) -> void:
	state = State.LANDING
	var tween := create_tween()
	tween.tween_property(self, "global_position", circle.global_position, 0.18) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func() -> void:
		attach_to_circle(circle)
		landed_on.emit(circle)
	)


func _die(reason: String) -> void:
	state = State.DEAD
	queue_redraw()
	player_died.emit(reason)
