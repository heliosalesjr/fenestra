extends Node2D

@export var circle_sequence: Array[NodePath] = []

## Probabilidade de um item aparecer entre cada par de círculos (0.0 = nunca, 1.0 = sempre).
@export var item_spawn_chance: float = 0.4
## Pesos relativos por tipo de item (ajuste para controlar frequência de cada um).
@export var coin_weight:   int = 70
@export var life_weight:   int = 20
@export var shield_weight: int = 10

@onready var player: Node2D       = $Player
@onready var _camera: Camera2D    = $Camera2D
@onready var _ui: Control         = $UI/TopBar
@onready var _spike_walls: Node2D = $SpikeLayer/SpikeWalls

var circles: Array[Node2D] = []
var _items:  Array[Node2D] = []
var _player_prev_pos: Vector2 = Vector2.ZERO
var current_index: int = 0
var last_checkpoint_index: int = 0
var lives: int = 99
var _first_walls_index: int = -1   # primeiro círculo com drift ou grow (ativa spikes)

const ITEM_COLLECT_RADIUS := 20.0
const ITEM_COIN   := 0
const ITEM_LIFE   := 1
const ITEM_SHIELD := 2

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

	for i in circles.size():
		if circles[i].get("drift_enabled") or circles[i].get("grow_enabled"):
			_first_walls_index = i
			break

	player.player_died.connect(_on_player_died)
	player.landed_on.connect(_on_player_landed)

	if circles.size() > 0:
		player.attach_to_circle(circles[0])

	# Inicializa câmera sem lerp para evitar salto no primeiro frame
	_cam_zoom = _target_zoom()
	_cam_pos  = _target_pos(_cam_zoom)
	_camera.global_position = _cam_pos
	_camera.zoom = Vector2(_cam_zoom, _cam_zoom)

	_spawn_items()
	queue_redraw()


func _process(delta: float) -> void:
	_update_camera(delta)
	_follow_drift_circle()
	_check_grow_wall()
	_check_items()


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


# ─── Drift: player segue o círculo ──────────────────────────────────────────

func _follow_drift_circle() -> void:
	var needs_redraw := false
	if player.state == player.State.ON_CIRCLE:
		var cur := circles[current_index]
		if cur.get("drift_enabled") and cur.get("_drifting"):
			player.global_position = cur.global_position
			needs_redraw = true
			# Colisão com as bordas reais da tela (compensa zoom da câmera)
			var radius: float    = cur.get("circle_radius")
			var half_w: float    = (VIEWPORT_W * 0.5) / _cam_zoom
			var wall_left: float  = _cam_pos.x - half_w
			var wall_right: float = _cam_pos.x + half_w
			if cur.position.x - radius <= wall_left or \
			   cur.position.x + radius >= wall_right:
				cur.call("trigger_drift_explode")
	if not needs_redraw:
		for c in circles:
			if c.get("_drift_returning"):
				needs_redraw = true
				break
	if needs_redraw:
		queue_redraw()


func _check_grow_wall() -> void:
	if player.state != player.State.ON_CIRCLE:
		return
	var cur := circles[current_index]
	if not cur.get("grow_enabled") or not cur.get("_growing"):
		return
	var radius: float    = cur.get("_grow_radius")
	var half_w: float    = (VIEWPORT_W * 0.5) / _cam_zoom
	var wall_left: float  = _cam_pos.x - half_w
	var wall_right: float = _cam_pos.x + half_w
	if cur.position.x - radius <= wall_left or \
	   cur.position.x + radius >= wall_right:
		cur.call("trigger_grow_explode")


# ─── Itens ───────────────────────────────────────────────────────────────────

func _spawn_items() -> void:
	var scene := preload("res://scenes/entities/Item.tscn")
	for i in range(circles.size() - 1):
		if randf() > item_spawn_chance:
			continue
		var mid := (circles[i].position + circles[i + 1].position) * 0.5
		var item: Node2D = scene.instantiate()
		item.set("item_type", _random_item_type())
		item.position = mid
		add_child(item)
		item.connect("collected", _on_item_collected)
		_items.append(item)


func _check_items() -> void:
	if player.state != player.State.MOVING:
		_player_prev_pos = player.global_position
		return
	for item in _items:
		if not is_instance_valid(item):
			continue
		if item.get("_active") and \
				_segment_dist(_player_prev_pos, player.global_position, item.global_position) < ITEM_COLLECT_RADIUS:
			item.call("collect")
	_player_prev_pos = player.global_position


func _segment_dist(a: Vector2, b: Vector2, p: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.0001:
		return a.distance_to(p)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return (a + ab * t).distance_to(p)


func _random_item_type() -> int:
	var total := coin_weight + life_weight + shield_weight
	var r := randi() % total
	if r < coin_weight:
		return ITEM_COIN
	elif r < coin_weight + life_weight:
		return ITEM_LIFE
	else:
		return ITEM_SHIELD


func _on_item_collected(type: int) -> void:
	match type:
		ITEM_COIN:
			pass  # TODO: adicionar moeda ao score
		ITEM_LIFE:
			pass  # TODO: restaurar vida (lives = min(lives + 1, max_lives))
		ITEM_SHIELD:
			pass  # TODO: ativar escudo


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
	if cur.get("drift_enabled"):
		cur.call("stop_drifting")
		_disconnect_drift(cur)
	if cur.get("grow_enabled"):
		cur.call("stop_growing")
		_disconnect_grow(cur)
	if cur.get("poison_enabled"):
		cur.call("stop_poisoning")
		_disconnect_poison(cur)
	if cur.get("reverse_enabled"):
		cur.call("stop_reversing")
	var next_idx := (current_index + 1) % circles.size()
	player.move_to(circles[next_idx])


# ─── Sinais do player ────────────────────────────────────────────────────────

func _on_player_landed(circle: Node2D) -> void:
	current_index = circles.find(circle)
	_spike_walls.visible = circle.get("drift_enabled") or circle.get("grow_enabled")
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
	if circle.get("drift_enabled"):
		circle.call("start_drifting")
		if not circle.is_connected("drift_exploded", _on_drift_exploded):
			circle.connect("drift_exploded", _on_drift_exploded)
	if circle.get("grow_enabled"):
		circle.call("start_growing")
		if not circle.is_connected("grow_exploded", _on_grow_exploded):
			circle.connect("grow_exploded", _on_grow_exploded)
	if circle.get("poison_enabled"):
		circle.call("start_poisoning")
		if not circle.is_connected("poison_exploded", _on_poison_exploded):
			circle.connect("poison_exploded", _on_poison_exploded)
	if circle.get("reverse_enabled"):
		circle.call("start_reversing")
	if circle.get("bg_number") > 0:
		last_checkpoint_index = current_index


func _on_shrink_exploded() -> void:
	player.force_die("shrink")


func _disconnect_shrink(circle: Node2D) -> void:
	if circle.is_connected("shrink_exploded", _on_shrink_exploded):
		circle.disconnect("shrink_exploded", _on_shrink_exploded)


func _on_drift_exploded() -> void:
	player.force_die("drift")


func _disconnect_drift(circle: Node2D) -> void:
	if circle.is_connected("drift_exploded", _on_drift_exploded):
		circle.disconnect("drift_exploded", _on_drift_exploded)


func _on_grow_exploded() -> void:
	player.force_die("grow")


func _disconnect_grow(circle: Node2D) -> void:
	if circle.is_connected("grow_exploded", _on_grow_exploded):
		circle.disconnect("grow_exploded", _on_grow_exploded)


func _on_poison_exploded() -> void:
	player.force_die("poison")


func _disconnect_poison(circle: Node2D) -> void:
	if circle.is_connected("poison_exploded", _on_poison_exploded):
		circle.disconnect("poison_exploded", _on_poison_exploded)


func _on_player_died(reason: String) -> void:
	print_rich("[color=red]Morte:[/color] ", reason)
	var cur := circles[current_index]
	if cur.get("orbiter_chaser"):
		cur.call("release_chasers")
	if cur.get("shrink_enabled"):
		cur.call("stop_shrinking")
		_disconnect_shrink(cur)
	if cur.get("drift_enabled"):
		cur.call("stop_drifting")
		_disconnect_drift(cur)
	if cur.get("grow_enabled"):
		cur.call("stop_growing")
		_disconnect_grow(cur)
	if cur.get("poison_enabled"):
		cur.call("stop_poisoning")
		_disconnect_poison(cur)
	if cur.get("reverse_enabled"):
		cur.call("stop_reversing")
	lives -= 1
	_ui.set_lives(lives)
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	if lives <= 0:
		_ui.show_game_over()
		return
	current_index = last_checkpoint_index
	var cp_circle := circles[last_checkpoint_index]
	_spike_walls.visible = cp_circle.get("drift_enabled") or cp_circle.get("grow_enabled")
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
		if c.get("drift_enabled"):
			c.call("stop_drifting")
		if c.get("grow_enabled"):
			c.call("stop_growing")
		if c.get("poison_enabled"):
			c.call("stop_poisoning")
		if c.get("reverse_enabled"):
			c.call("stop_reversing")
