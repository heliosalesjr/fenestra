extends Node2D

signal landed_on(circle: Node2D)
signal player_died(reason: String)

enum State { ON_CIRCLE, MOVING, DEAD }

const PLAYER_RADIUS := 12.0
const PLAYER_COLOR  := Color(1.0, 0.85, 0.2)
const DEAD_COLOR    := Color(1.0, 0.2, 0.2)
const MOVE_DURATION := 0.14

var state: State = State.ON_CIRCLE
var current_circle: Node2D = null
var destination_circle: Node2D = null
var _active_tween: Tween = null


func _draw() -> void:
	var color := DEAD_COLOR if state == State.DEAD else PLAYER_COLOR
	draw_circle(Vector2.ZERO, PLAYER_RADIUS, color)


func _process(_delta: float) -> void:
	if state == State.MOVING and destination_circle:
		_check_orbiter_collision()


func attach_to_circle(circle: Node2D) -> void:
	current_circle = circle
	destination_circle = null
	state = State.ON_CIRCLE
	global_position = circle.global_position
	queue_redraw()


func move_to(target: Node2D) -> void:
	if state != State.ON_CIRCLE:
		return
	destination_circle = target
	state = State.MOVING
	_active_tween = create_tween()
	_active_tween.tween_property(self, "global_position", target.global_position, MOVE_DURATION).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	_active_tween.tween_callback(_on_arrived)


func respawn(circle: Node2D) -> void:
	attach_to_circle(circle)


func _on_arrived() -> void:
	var circle := destination_circle
	if not circle:
		return
	var from_pos := current_circle.global_position if current_circle else global_position
	var approach_angle_deg := rad_to_deg((from_pos - circle.global_position).angle())
	if circle.is_landing_valid(approach_angle_deg):
		attach_to_circle(circle)
		landed_on.emit(circle)
	else:
		_die(circle.last_fail_reason)


func _check_orbiter_collision() -> void:
	for child in destination_circle.get_children():
		if not child.has_method("fade_and_free"):
			continue
		var orb_radius: float = child.get("sphere_radius")
		if global_position.distance_to(child.global_position) < PLAYER_RADIUS + orb_radius:
			_die("orbiter")
			return


func _die(reason: String) -> void:
	if _active_tween:
		_active_tween.kill()
		_active_tween = null
	state = State.DEAD
	queue_redraw()
	player_died.emit(reason)
