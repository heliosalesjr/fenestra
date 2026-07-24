extends Node2D

## Catálogo de níveis disponíveis (LevelChunk.tscn) — a run é montada a partir
## daqui, sequencial ou embaralhada, conforme a escolha do player em _ready().
@export var level_pool: Array[PackedScene] = []

## Probabilidade de um item aparecer entre cada par de círculos (0.0 = nunca, 1.0 = sempre).
@export var item_spawn_chance: float = 0.4
## Pesos relativos por tipo de item (ajuste para controlar frequência de cada um).
@export var coin_weight:   int = 70
@export var life_weight:   int = 20
@export var shield_weight: int = 10
## bg_numbers dos níveis que devem ter relógio antes do primeiro círculo.
@export var clock_before_levels: Array[int] = [2, 3, 4]

@onready var player: Player          = $Player
@onready var _camera: Camera2D       = $Camera2D
@onready var _ui: Control            = $UI/TopBar
@onready var _spike_walls: Node2D    = $SpikeLayer/SpikeWalls
@onready var _background: Node2D     = $BackgroundLayer/Background
@onready var _circle_start: Circle   = $CircleStart

var circles: Array[Circle] = []
var _items:  Array[Node2D] = []
var _barrier_nodes: Array[Barrier] = []
var _player_prev_pos: Vector2 = Vector2.ZERO
var current_index: int = 0
var last_checkpoint_index: int = 0
const MAX_LIVES := 3
var lives: int = MAX_LIVES
var score: int = 0
var _first_walls_index: int = -1   # primeiro círculo com drift ou grow (ativa spikes)
var _run_ready: bool = false       # true só depois que o player escolhe o modo e a run é montada
var _input_unlocked: bool = false  # só vira true no primeiro _process() após _run_ready — evita que o
									# próprio toque que escolheu o modo "vaze" como um pulo

var _clock_active:             bool   = false
var _clock_time_left:          float  = 0.0
var _clock_start_circle_index: int    = -1
var _respawn_clock_item:       Node2D = null

const ITEM_COLLECT_RADIUS := 20.0
const ITEM_COIN   := 0
const ITEM_LIFE   := 1
const ITEM_SHIELD := 2

const CLOCK_DURATION := 8.0

const RING_PALETTE: Array[Color] = [
	Color(0.2,  0.9,  0.3,  1.0),  # verde
	Color(1.0,  0.9,  0.1,  1.0),  # amarelo
	Color(0.2,  0.5,  1.0,  1.0),  # azul
	Color(0.7,  0.2,  1.0,  1.0),  # roxo
	Color(1.0,  0.5,  0.1,  1.0),  # laranja
	Color(1.0,  0.3,  0.7,  1.0),  # rosa
	Color(0.9,  0.9,  0.9,  1.0),  # branco
]

const RESPAWN_DELAY  := 0.35
const VIEWPORT_H     := 844.0
const VIEWPORT_W     := 390.0
const CAM_POS_SMOOTH := 6.0
const CAM_ZOOM_SMOOTH := 3.5


# Câmera — estado interpolado
var _cam_pos:  Vector2 = Vector2.ZERO
var _cam_zoom: float   = 1.0

# Câmera — tremor ("trauma" decai com o tempo; offset escala com trauma²
# para um tranco forte no início e suavizar rápido no fim).
var _cam_trauma: float = 0.0
const CAM_TRAUMA_DECAY      := 2.2
const CAM_SHAKE_MAX_OFFSET  := 18.0


# ─── Powerup Rocket ────────────────────────────────────────────────────────
## Quando true, o Game pilota os pulos automáticos do player (ver _rocket_advance).
var _rocket_active: bool      = false
var _rocket_jumps_left: int   = 0
var _rocket_extended: bool    = false
var _rocket_level: int        = 1
## Círculos pulados automaticamente = level + ROCKET_BASE_JUMPS (nível 1 → 3,
## nível 2 → 4, nível 3 → 5), estendido em +1 se cair num checkpoint vazio.
const ROCKET_BASE_JUMPS := 2


func _ready() -> void:
	player.player_died.connect(_on_player_died)
	player.landed_on.connect(_on_player_landed)
	player.shield_broken.connect(_on_shield_broken)

	_ui.mode_selected.connect(_on_mode_selected)
	_ui.show_mode_select()


## Chamado pela UI depois que o player escolhe sequencial ou embaralhado.
## A partir daqui a run é montada e o jogo de fato começa.
func _on_mode_selected(shuffled: bool) -> void:
	_build_run(shuffled)
	_finish_setup()


## Monta a sequência de círculos da partida a partir de `level_pool`, instanciando
## cada LevelChunk e encadeando um logo acima do outro (ver LevelChunk.gd).
## Sequencial = ordem de `level_pool`; embaralhado = mesma lista, ordem sorteada.
func _build_run(shuffled: bool) -> void:
	circles.append(_circle_start)

	var pool := level_pool.duplicate()
	if shuffled:
		pool.shuffle()

	var entry_y := _circle_start.position.y
	for i in pool.size():
		var chunk := (pool[i] as PackedScene).instantiate() as LevelChunk
		add_child(chunk)
		chunk.position = Vector2(0.0, entry_y)

		var chunk_circles := chunk.get_level_circles()
		var checkpoint := chunk_circles[chunk_circles.size() - 1]
		checkpoint.bg_number = i + 2
		circles.append_array(chunk_circles)
		_barrier_nodes.append_array(chunk.get_barriers())

		entry_y -= chunk.height


## Tudo que dependia de `circles` já estar montado — câmera, paleta, spawn de
## itens e o primeiro attach do player. Antes disso o jogo fica pausado
## esperando a escolha do modo (ver `_run_ready`).
func _finish_setup() -> void:
	var palette_idx := 0
	for i in circles.size():
		if circles[i].bg_number > 0:
			palette_idx += 1
			circles[i].set_thin_border(true)
		circles[i].set_ring_color(RING_PALETTE[palette_idx % RING_PALETTE.size()])

	for i in circles.size():
		if circles[i].drift_enabled or circles[i].grow_enabled:
			_first_walls_index = i
			break

	player.attach_to_circle(circles[0])

	# Inicializa câmera sem lerp para evitar salto no primeiro frame
	_cam_zoom = _target_zoom()
	_cam_pos  = _target_pos(_cam_zoom)
	_camera.global_position = _cam_pos
	_camera.zoom = Vector2(_cam_zoom, _cam_zoom)

	_spawn_items()
	_run_ready = true
	queue_redraw()


func _process(delta: float) -> void:
	if not _run_ready:
		return
	_input_unlocked = true
	_update_camera(delta)
	_follow_drift_circle()
	_check_grow_wall()
	_update_item_positions()
	_check_barriers()
	_check_items()
	_update_clock(delta)


# ─── Câmera ──────────────────────────────────────────────────────────────────

func _update_camera(delta: float) -> void:
	var tz := _target_zoom()
	_cam_zoom = lerp(_cam_zoom, tz, delta * CAM_ZOOM_SMOOTH)

	var tp := _target_pos(_cam_zoom)
	_cam_pos = _cam_pos.lerp(tp, delta * CAM_POS_SMOOTH)

	var shake_offset := Vector2.ZERO
	if _cam_trauma > 0.0:
		_cam_trauma = maxf(0.0, _cam_trauma - CAM_TRAUMA_DECAY * delta)
		var amount := _cam_trauma * _cam_trauma
		shake_offset = Vector2(
			randf_range(-1.0, 1.0) * CAM_SHAKE_MAX_OFFSET * amount,
			randf_range(-1.0, 1.0) * CAM_SHAKE_MAX_OFFSET * amount
		)

	_camera.global_position = _cam_pos + shake_offset
	_camera.zoom = Vector2(_cam_zoom, _cam_zoom)


## Adiciona "trauma" de câmera (0-1). O tremor decai sozinho em CAM_TRAUMA_DECAY.
func _camera_shake(trauma: float) -> void:
	_cam_trauma = clampf(_cam_trauma + trauma, 0.0, 1.0)


func _spawn_boom(pos: Vector2, scale_mult: float = 1.0) -> void:
	var boom := preload("res://scripts/fx/RocketBoom.gd").new()
	add_child(boom)
	boom.global_position = pos
	boom.fire(scale_mult)


func _next_circle() -> Node2D:
	# Durante movimento, usa o círculo de destino como "próximo"
	if player.state == player.State.MOVING and player.destination_circle:
		return player.destination_circle
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
		if cur.drift_enabled and cur._drifting:
			player.global_position = cur.global_position
			needs_redraw = true
			# Colisão com as bordas reais da tela (compensa zoom da câmera)
			var radius: float     = cur.circle_radius
			var half_w: float     = (VIEWPORT_W * 0.5) / _cam_zoom
			var wall_left: float  = _cam_pos.x - half_w
			var wall_right: float = _cam_pos.x + half_w
			if cur.global_position.x - radius <= wall_left or \
			   cur.global_position.x + radius >= wall_right:
				cur.trigger_drift_explode()
	if not needs_redraw:
		for c in circles:
			if c._drift_returning:
				needs_redraw = true
				break
	if needs_redraw:
		queue_redraw()


func _check_grow_wall() -> void:
	if player.state != player.State.ON_CIRCLE:
		return
	var cur := circles[current_index]
	if not cur.grow_enabled or not cur._growing:
		return
	var radius: float     = cur._grow_radius
	var half_w: float     = (VIEWPORT_W * 0.5) / _cam_zoom
	var wall_left: float  = _cam_pos.x - half_w
	var wall_right: float = _cam_pos.x + half_w
	if cur.global_position.x - radius <= wall_left or \
	   cur.global_position.x + radius >= wall_right:
		cur.trigger_grow_explode()


# ─── Itens ───────────────────────────────────────────────────────────────────

func _spawn_items() -> void:
	var item_scene  := preload("res://scenes/entities/Item.tscn")
	var clock_scene := preload("res://scenes/entities/ClockItem.tscn")

	# Identifica gaps que devem ter relógio (gap i = entre circles[i] e circles[i+1])
	var clock_gaps: Dictionary = {}
	for i in circles.size():
		var bg_n: int = circles[i].bg_number
		if bg_n > 0 and clock_before_levels.has(bg_n) and i > 0:
			var gap_idx := i - 1
			clock_gaps[gap_idx] = true
			var mid := (circles[gap_idx].global_position + circles[i].global_position) * 0.5
			var clock_item: Node2D = clock_scene.instantiate()
			clock_item.position = mid
			clock_item.set_meta("circle_a", circles[gap_idx])
			clock_item.set_meta("circle_b", circles[i])
			add_child(clock_item)
			clock_item.connect("collected", _on_clock_collected)
			_items.append(clock_item)

	for i in range(circles.size() - 1):
		if clock_gaps.has(i):
			continue
		if randf() > item_spawn_chance:
			continue
		var mid := (circles[i].global_position + circles[i + 1].global_position) * 0.5
		var item: Node2D = item_scene.instantiate()
		item.set("item_type", _random_item_type())
		item.position = mid
		item.set_meta("circle_a", circles[i])
		item.set_meta("circle_b", circles[i + 1])
		add_child(item)
		item.connect("collected", _on_item_collected)
		_items.append(item)

	_spawn_rocket_item()


## Spawn de teste do powerup Rocket: aparece sempre no vão logo após o primeiro
## checkpoint (bg_number == 2, o "início do segundo nível"), qualquer que seja
## o LevelChunk sorteado ali — funciona tanto no modo sequencial quanto embaralhado.
func _spawn_rocket_item() -> void:
	var idx := -1
	for i in circles.size():
		if circles[i].bg_number == 2:
			idx = i
			break
	if idx == -1 or idx + 1 >= circles.size():
		return

	var rocket_scene := preload("res://scenes/entities/RocketItem.tscn")
	var mid := (circles[idx].global_position + circles[idx + 1].global_position) * 0.5
	var rocket: Node2D = rocket_scene.instantiate()
	rocket.position = mid
	rocket.set_meta("circle_a", circles[idx])
	rocket.set_meta("circle_b", circles[idx + 1])
	add_child(rocket)
	rocket.connect("collected", _on_rocket_collected)
	_items.append(rocket)


func _update_item_positions() -> void:
	for item in _items:
		if not is_instance_valid(item):
			continue
		if not item.get("_active"):
			continue
		var ca := item.get_meta("circle_a") as Node2D
		var cb := item.get_meta("circle_b") as Node2D
		if is_instance_valid(ca) and is_instance_valid(cb):
			item.position = (ca.global_position + cb.global_position) * 0.5


## Checa se o player cruzou a altura (Y) de alguma barreira neste frame e, se cruzou,
## se a posição X do cruzamento caiu dentro do vão livre daquele instante.
## Precisa rodar ANTES de _check_items(), que é quem atualiza _player_prev_pos.
func _check_barriers() -> void:
	if player.state != player.State.MOVING:
		return
	var prev := _player_prev_pos
	var cur  := player.global_position
	if is_equal_approx(prev.y, cur.y):
		return
	for barrier in _barrier_nodes:
		if not is_instance_valid(barrier):
			continue
		var by: float = barrier.global_position.y
		if (prev.y - by) * (cur.y - by) > 0.0:
			continue  # não cruzou a altura desta barreira neste frame
		var t := (by - prev.y) / (cur.y - prev.y)
		var x_at_cross := prev.x + t * (cur.x - prev.x)
		if not barrier.is_open_at(x_at_cross):
			player.force_die("barrier")
			return


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


# ─── Relógio ─────────────────────────────────────────────────────────────────

func _on_clock_collected() -> void:
	_respawn_clock_item = null
	_clock_start_circle_index = current_index + 1
	_start_clock()


func _start_clock() -> void:
	_clock_active    = true
	_clock_time_left = CLOCK_DURATION
	_ui.show_clock_bar()


func _stop_clock() -> void:
	if not _clock_active:
		return
	_clock_active = false
	_ui.hide_clock_bar()


func _update_clock(delta: float) -> void:
	if not _clock_active:
		return
	_clock_time_left -= delta
	_ui.update_clock_bar(_clock_time_left / CLOCK_DURATION)
	if _clock_time_left <= 0.0:
		_stop_clock()
		player.force_die("clock")


func _on_item_collected(type: int) -> void:
	match type:
		ITEM_COIN:
			score += 1
			_ui.set_score(score)
		ITEM_LIFE:
			pass  # TODO: restaurar vida (lives = min(lives + 1, max_lives))
		ITEM_SHIELD:
			player.set_shield(true)
			_ui.set_shield(true)


func _on_shield_broken() -> void:
	_ui.set_shield(false)


# ─── Rocket ──────────────────────────────────────────────────────────────────

## Ao coletar, o player fica invencível e o Game passa a pilotar os pulos
## automaticamente (ver _rocket_advance, chamado a cada pouso via landed_on).
## `level` (1-3) vem do RocketItem coletado e define quantos círculos são
## pulados: nível 1 → 3, nível 2 → 4, nível 3 → 5 (fórmula level + ROCKET_BASE_JUMPS).
func _on_rocket_collected(level: int) -> void:
	_rocket_active       = true
	_rocket_level        = level
	_rocket_jumps_left   = level + ROCKET_BASE_JUMPS
	_rocket_extended     = false
	player.set_rocket_active(true)
	_camera_shake(0.5 + level * 0.15)
	_spawn_boom(player.global_position, level)


## Chamado a cada pouso enquanto o Rocket está ativo. Conta o pouso, estende a
## sequência em +1 pulo se o círculo for um checkpoint "vazio" (bg_number > 0,
## sem perigo — ver CircleCheckpoint.tscn), e encadeia o próximo pulo sozinho.
func _rocket_advance(landed_circle: Circle) -> void:
	_rocket_jumps_left -= 1
	if landed_circle.bg_number > 0 and not _rocket_extended:
		_rocket_extended = true
		_rocket_jumps_left += 1

	_camera_shake(0.4 + _rocket_level * 0.12)
	_spawn_boom(landed_circle.global_position, _rocket_level)

	if _rocket_jumps_left <= 0 or circles.size() < 2:
		_rocket_active = false
		player.set_rocket_active(false)
		return

	_leave_circle_cleanup(current_index)
	var next_idx := (current_index + 1) % circles.size()
	player.move_to(circles[next_idx])


# ─── Desenho ─────────────────────────────────────────────────────────────────

const PATH_HAZE_COLOR := Color(0.72, 0.72, 0.8, 1.0)
## Comprimento (px) do fade nas pontas de cada segmento — alpha vai a 0 aqui.
const PATH_FADE_LEN := 80.0
## Camadas de glow: [largura, alpha no trecho sólido]. Larga/fraca por baixo,
## fina/mais forte por cima — mesma técnica da eletricidade em ArcVisual.gd.
const PATH_HAZE_LAYERS := [
	[11.0, 0.045],
	[7.5,  0.065],
	[5.0,  0.095],
	[2.8,  0.13],
	[1.2,  0.17],
]


func _draw() -> void:
	for i in range(circles.size() - 1):
		_draw_hazy_path(circles[i].global_position, circles[i + 1].global_position)


## Desenha a conexão entre dois círculos como uma linha esfumaçada: várias
## camadas de glow sobrepostas, com o alpha suavizado nas pontas (fade in/out
## via draw_polyline_colors) em vez de uma linha nítida de ponta a ponta.
func _draw_hazy_path(a: Vector2, b: Vector2) -> void:
	var dist := a.distance_to(b)
	if dist < 1.0:
		return
	var dir  := (b - a) / dist
	var fade := minf(PATH_FADE_LEN, dist * 0.5)
	var points := PackedVector2Array([a, a + dir * fade, b - dir * fade, b])

	for layer in PATH_HAZE_LAYERS:
		var width: float       = layer[0]
		var solid_alpha: float = layer[1]
		var colors := PackedColorArray([
			Color(PATH_HAZE_COLOR, 0.0),
			Color(PATH_HAZE_COLOR, solid_alpha),
			Color(PATH_HAZE_COLOR, solid_alpha),
			Color(PATH_HAZE_COLOR, 0.0),
		])
		draw_polyline_colors(points, colors, width, true)


# ─── Input ───────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not _input_unlocked:
		return
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
	_leave_circle_cleanup(current_index)
	var next_idx := (current_index + 1) % circles.size()
	player.move_to(circles[next_idx])


## Encerra os efeitos de perigo do círculo que está sendo deixado (chasers,
## shrink, drift, grow, poison, reverse). Usado tanto no pulo manual (tap)
## quanto no encadeamento automático do powerup Rocket.
func _leave_circle_cleanup(idx: int) -> void:
	var cur := circles[idx]
	if cur.orbiter_chaser:
		cur.release_chasers()
	if cur.shrink_enabled:
		cur.stop_shrinking()
		_disconnect_shrink(cur)
	if cur.drift_enabled:
		cur.stop_drifting()
		_disconnect_drift(cur)
	if cur.grow_enabled:
		cur.stop_growing()
		_disconnect_grow(cur)
	if cur.poison_enabled:
		cur.stop_poisoning()
		_disconnect_poison(cur)
	if cur.reverse_enabled:
		cur.stop_reversing()


# ─── Sinais do player ────────────────────────────────────────────────────────

func _on_player_landed(circle_node: Node2D) -> void:
	var circle := circle_node as Circle
	current_index = circles.find(circle)
	var arc_visual := circle.get_node_or_null("RotationRoot/ArcVisual")
	if arc_visual:
		_background.set_tint(arc_visual.free_color)
	_spike_walls.visible = circle.drift_enabled or circle.grow_enabled
	if circle.mirror_mode:
		circle.flip_mirror()
	if circle.orbiter_chaser:
		circle.activate_chasers(player)
	else:
		circle.clear_orbiters()
	if circle.shrink_enabled:
		circle.start_shrinking()
		if not circle.shrink_exploded.is_connected(_on_shrink_exploded):
			circle.shrink_exploded.connect(_on_shrink_exploded)
	if circle.drift_enabled:
		circle.start_drifting()
		if not circle.drift_exploded.is_connected(_on_drift_exploded):
			circle.drift_exploded.connect(_on_drift_exploded)
	if circle.grow_enabled:
		circle.start_growing()
		if not circle.grow_exploded.is_connected(_on_grow_exploded):
			circle.grow_exploded.connect(_on_grow_exploded)
	if circle.poison_enabled:
		circle.start_poisoning()
		if not circle.poison_exploded.is_connected(_on_poison_exploded):
			circle.poison_exploded.connect(_on_poison_exploded)
	if circle.reverse_enabled:
		circle.start_reversing()
	if circle.bg_number > 0:
		last_checkpoint_index = current_index
		if _clock_active and current_index > _clock_start_circle_index:
			_stop_clock()

	if _rocket_active:
		_rocket_advance(circle)


func _on_shrink_exploded() -> void:
	player.force_die("shrink")


func _disconnect_shrink(circle: Circle) -> void:
	if circle.shrink_exploded.is_connected(_on_shrink_exploded):
		circle.shrink_exploded.disconnect(_on_shrink_exploded)


func _on_drift_exploded() -> void:
	player.force_die("drift")


func _disconnect_drift(circle: Circle) -> void:
	if circle.drift_exploded.is_connected(_on_drift_exploded):
		circle.drift_exploded.disconnect(_on_drift_exploded)


func _on_grow_exploded() -> void:
	player.force_die("grow")


func _disconnect_grow(circle: Circle) -> void:
	if circle.grow_exploded.is_connected(_on_grow_exploded):
		circle.grow_exploded.disconnect(_on_grow_exploded)


func _on_poison_exploded() -> void:
	player.force_die("poison")


func _disconnect_poison(circle: Circle) -> void:
	if circle.poison_exploded.is_connected(_on_poison_exploded):
		circle.poison_exploded.disconnect(_on_poison_exploded)


func _on_player_died(reason: String) -> void:
	print_rich("[color=red]Morte:[/color] ", reason)
	_stop_clock()
	var cur := circles[current_index]
	if cur.orbiter_chaser:
		cur.release_chasers()
	if cur.shrink_enabled:
		cur.stop_shrinking()
		_disconnect_shrink(cur)
	if cur.drift_enabled:
		cur.stop_drifting()
		_disconnect_drift(cur)
	if cur.grow_enabled:
		cur.stop_growing()
		_disconnect_grow(cur)
	if cur.poison_enabled:
		cur.stop_poisoning()
		_disconnect_poison(cur)
	if cur.reverse_enabled:
		cur.stop_reversing()
	lives -= 1
	_ui.set_lives(lives)
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	if lives <= 0:
		_camera_shake(0.8)
		_ui.show_game_over()
		return
	current_index = last_checkpoint_index
	var cp_circle := circles[last_checkpoint_index]
	_spike_walls.visible = cp_circle.drift_enabled or cp_circle.grow_enabled
	_reset_circles_after_checkpoint()
	player.respawn(circles[last_checkpoint_index])
	if clock_before_levels.has(cp_circle.bg_number):
		_spawn_respawn_clock()


func _spawn_respawn_clock() -> void:
	var next_idx := last_checkpoint_index + 1
	if next_idx >= circles.size():
		return
	if is_instance_valid(_respawn_clock_item):
		_items.erase(_respawn_clock_item)
		_respawn_clock_item.queue_free()
	var clock_scene := preload("res://scenes/entities/ClockItem.tscn")
	var mid := (circles[last_checkpoint_index].global_position + circles[next_idx].global_position) * 0.5
	_respawn_clock_item = clock_scene.instantiate()
	_respawn_clock_item.position = mid
	_respawn_clock_item.set_meta("circle_a", circles[last_checkpoint_index])
	_respawn_clock_item.set_meta("circle_b", circles[next_idx])
	add_child(_respawn_clock_item)
	_respawn_clock_item.connect("collected", _on_clock_collected)
	_items.append(_respawn_clock_item)


func _reset_circles_after_checkpoint() -> void:
	# Fim do nível atual: até o próximo círculo de checkpoint (ou o fim da sequência).
	var level_end := circles.size()
	for i in range(last_checkpoint_index + 1, circles.size()):
		if circles[i].bg_number > 0:
			level_end = i
			break

	for i in range(last_checkpoint_index + 1, circles.size()):
		var c := circles[i]
		if c.mirror_mode:
			c.reset_mirror()
		if c.shrink_enabled:
			c.stop_shrinking()
		if c.drift_enabled:
			c.stop_drifting()
		if c.grow_enabled:
			c.stop_growing()
		if c.poison_enabled:
			c.stop_poisoning()
		if c.reverse_enabled:
			c.stop_reversing()
		if i < level_end and c.level_randomize:
			c.randomize_level()
		if c.orbiter_count > 0:
			c.reset_orbiters()
