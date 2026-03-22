extends Node2D

@export var circle_sequence: Array[NodePath] = []

@onready var player: Node2D  = $Player
@onready var _camera: Camera2D = $Camera2D
@onready var _ui: Control = $UI/TopBar

var circles: Array[Node2D] = []
var current_index: int = 0
var last_checkpoint_index: int = 0
var lives: int = 99

const RESPAWN_DELAY  := 1.0
const VIEWPORT_H     := 844.0
const VIEWPORT_W     := 390.0
const CAM_POS_SMOOTH := 6.0
const CAM_ZOOM_SMOOTH := 3.5


# Câmera — estado interpolado
var _cam_pos:  Vector2 = Vector2.ZERO
var _cam_zoom: float   = 1.0


func _ready() -> void:
	for path in circle_sequence:
		circles.append(get_node(path))

	player.player_died.connect(_on_player_died)
	player.landed_on.connect(_on_player_landed)

	if circles.size() > 0:
		player.attach_to_circle(circles[0])

	# Inicializa câmera sem lerp para evitar salto no primeiro frame
	_cam_zoom = _target_zoom()
	_cam_pos  = _target_pos(_cam_zoom)
	_camera.global_position = _cam_pos
	_camera.zoom = Vector2(_cam_zoom, _cam_zoom)

	queue_redraw()


func _process(delta: float) -> void:
	_update_camera(delta)


# ─── Câmera ──────────────────────────────────────────────────────────────────

func _update_camera(delta: float) -> void:
	var tz := _target_zoom()
	_cam_zoom = lerp(_cam_zoom, tz, delta * CAM_ZOOM_SMOOTH)

	var tp := _target_pos(_cam_zoom)
	_cam_pos = _cam_pos.lerp(tp, delta * CAM_POS_SMOOTH)

	_camera.global_position = _cam_pos
	_camera.zoom = Vector2(_cam_zoom, _cam_zoom)


func _next_circle() -> Node2D:
	# Durante movimento, usa o círculo de destino como "próximo"
	var dest := player.get("destination_circle") as Node2D
	if player.state == player.State.MOVING and dest:
		return dest
	return circles[min(current_index + 1, circles.size() - 1)]


func _target_zoom() -> float:
	var nxt  := _next_circle()
	var dist := absf(player.global_position.y - nxt.global_position.y)
	if dist < 10.0:
		return 1.0
	# zoom escolhido para o próximo círculo aparecer em ~1/4 do topo
	# derivação: zoom = viewport_h * (2/3 - 1/4) / dist = viewport_h * 5/12 / dist
	return clampf(VIEWPORT_H * 5.0 / 12.0 / dist, 0.5, 1.4)


func _target_pos(zoom: float) -> Vector2:
	var cur := circles[current_index]
	var nxt := _next_circle()
	# X = ponto médio entre os dois círculos (estável, sem tremer com o player)
	var tx := (cur.global_position.x + nxt.global_position.x) * 0.5
	# Y = player no 1/3 inferior: camera_y = player_y - viewport_h / (6 * zoom)
	var ty := player.global_position.y - VIEWPORT_H / (6.0 * zoom)
	return Vector2(tx, ty)


# ─── Desenho ─────────────────────────────────────────────────────────────────

func _draw() -> void:
	for i in range(circles.size() - 1):
		draw_line(
			circles[i].position,
			circles[i + 1].position,
			Color(0.65, 0.65, 0.65, 0.3),
			1.5
		)


# ─── Input ───────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if player.state != player.State.ON_CIRCLE:
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_jump_to_next()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_jump_to_next()


func _jump_to_next() -> void:
	if circles.size() < 2:
		return
	var cur := circles[current_index]
	if cur.get("orbiter_chaser"):
		cur.call("release_chasers")
	if cur.get("shrink_enabled"):
		cur.call("stop_shrinking")
		_disconnect_shrink(cur)
	var next_idx := (current_index + 1) % circles.size()
	player.move_to(circles[next_idx])


# ─── Sinais do player ────────────────────────────────────────────────────────

func _on_player_landed(circle: Node2D) -> void:
	current_index = circles.find(circle)
	if circle.get("mirror_mode"):
		circle.call("flip_mirror")
	if circle.get("orbiter_chaser"):
		circle.call("activate_chasers", player)
	else:
		circle.clear_orbiters()
	if circle.get("shrink_enabled"):
		circle.call("start_shrinking")
		if not circle.is_connected("shrink_exploded", _on_shrink_exploded):
			circle.connect("shrink_exploded", _on_shrink_exploded)
	if circle.get("bg_number") > 0:
		last_checkpoint_index = current_index


func _on_shrink_exploded() -> void:
	player.force_die("shrink")


func _disconnect_shrink(circle: Node2D) -> void:
	if circle.is_connected("shrink_exploded", _on_shrink_exploded):
		circle.disconnect("shrink_exploded", _on_shrink_exploded)


func _on_player_died(reason: String) -> void:
	print_rich("[color=red]Morte:[/color] ", reason)
	var cur := circles[current_index]
	if cur.get("orbiter_chaser"):
		cur.call("release_chasers")
	if cur.get("shrink_enabled"):
		cur.call("stop_shrinking")
		_disconnect_shrink(cur)
	lives -= 1
	_ui.set_lives(lives)
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	if lives <= 0:
		_ui.show_game_over()
		return
	current_index = last_checkpoint_index
	_reset_circles_after_checkpoint()
	player.respawn(circles[last_checkpoint_index])


func _reset_circles_after_checkpoint() -> void:
	for i in range(last_checkpoint_index + 1, circles.size()):
		var c := circles[i]
		if c.get("orbiter_count") > 0:
			c.call("reset_orbiters")
		if c.get("mirror_mode"):
			c.call("reset_mirror")
		if c.get("shrink_enabled"):
			c.call("stop_shrinking")
