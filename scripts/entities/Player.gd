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
	elif state == State.ON_CIRCLE and current_circle:
		_check_chaser_collision()


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

	# Checagem de SAÍDA: borda escura ou círculo inativo = morte imediata.
	if current_circle:
		if not current_circle.get("is_active"):
			_die("inactive")
		elif _arc_is_blocked(current_circle, target.global_position - current_circle.global_position):
			_die("blocked")


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


# Verifica se a direção `world_dir` (vetor do centro do círculo → ponto na borda)
# cai num arco bloqueado do círculo. Sem nenhuma chamada a métodos de Circle.gd.
func _arc_is_blocked(circle: Node2D, world_dir: Vector2) -> bool:
	var arcs: Array = circle.get("blocked_arcs")
	if arcs.is_empty():
		return false

	var rot_root := circle.get_node_or_null("RotationRoot") as Node2D
	if not rot_root:
		return false

	# Ângulo do vetor no espaço local do RotationRoot
	var world_angle_deg := rad_to_deg(world_dir.angle())
	var local_deg := fmod(world_angle_deg - rot_root.rotation_degrees, 360.0)
	if local_deg < 0.0:
		local_deg += 360.0

	var in_arc := false
	for arc in arcs:
		var s: float = (arc as Vector2).x
		var e: float = (arc as Vector2).y
		if s <= e:
			if local_deg >= s and local_deg <= e:
				in_arc = true
				break
		else:
			if local_deg >= s or local_deg <= e:
				in_arc = true
				break

	var mirror_flipped: bool = circle.get("_mirror_flipped")
	return in_arc != mirror_flipped


## Verifica colisão com chasers enquanto o player está parado no círculo.
## Orbiters normais nunca alcançam o centro, então só chasers ativam isso.
func _check_chaser_collision() -> void:
	for child in current_circle.get_children():
		if not child.has_method("fade_and_free"):
			continue
		var orb_radius: float = child.get("sphere_radius")
		if global_position.distance_to(child.global_position) < PLAYER_RADIUS + orb_radius:
			_die("chaser")
			return


func _check_orbiter_collision() -> void:
	for child in destination_circle.get_children():
		if not child.has_method("fade_and_free"):
			continue
		var orb_radius: float = child.get("sphere_radius")
		if global_position.distance_to(child.global_position) < PLAYER_RADIUS + orb_radius:
			_die("orbiter")
			return


func force_die(reason: String) -> void:
	if state != State.DEAD:
		_die(reason)


func _die(reason: String) -> void:
	if _active_tween:
		_active_tween.kill()
		_active_tween = null
	state = State.DEAD
	queue_redraw()
	player_died.emit(reason)
