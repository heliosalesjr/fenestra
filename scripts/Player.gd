extends Node2D

signal landed_on(circle: Node2D)
signal player_died(reason: String)

enum State { ON_CIRCLE, MOVING, DEAD }

const PLAYER_RADIUS := 12.0
const PLAYER_COLOR  := Color(1.0, 0.85, 0.2)
const DEAD_COLOR    := Color(1.0, 0.2, 0.2)
const MOVE_DURATION := 0.14   # segundos do centro ao centro

var state: State = State.ON_CIRCLE

var current_circle:     Node2D = null
var destination_circle: Node2D = null


func _draw() -> void:
	var color := DEAD_COLOR if state == State.DEAD else PLAYER_COLOR
	draw_circle(Vector2.ZERO, PLAYER_RADIUS, color)


# ---------------------------------------------------------------------------
# API pública
# ---------------------------------------------------------------------------

func attach_to_circle(circle: Node2D) -> void:
	current_circle     = circle
	destination_circle = null
	state              = State.ON_CIRCLE
	global_position    = circle.global_position
	queue_redraw()


func move_to(target: Node2D) -> void:
	if state != State.ON_CIRCLE:
		return
	destination_circle = target
	state              = State.MOVING

	var tween := create_tween()
	tween.tween_property(self, "global_position", target.global_position, MOVE_DURATION) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(_on_arrived)


func respawn(circle: Node2D) -> void:
	attach_to_circle(circle)


# ---------------------------------------------------------------------------
# Chegada ao destino
# ---------------------------------------------------------------------------

func _on_arrived() -> void:
	var circle := destination_circle
	if not circle:
		return

	# Ângulo de entrada: direção da origem → destino,
	# expressa como vetor do centro do destino apontando de volta para a origem.
	# É o ponto da borda por onde o player "atravessou".
	var from_pos          := current_circle.global_position if current_circle else global_position
	var approach_angle_deg := rad_to_deg((from_pos - circle.global_position).angle())

	if circle.is_landing_valid(approach_angle_deg):
		attach_to_circle(circle)
		landed_on.emit(circle)
	else:
		_die(circle.last_fail_reason)


func _die(reason: String) -> void:
	state = State.DEAD
	queue_redraw()
	player_died.emit(reason)
