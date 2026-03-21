@tool
extends Node2D

## Círculo giratório — unidade central de jogo.
## Contém RotationRoot (que gira) com ArcVisual (que desenha os segmentos).

signal landing_failed(reason: String)
signal shrink_exploded()

## Razão do último pouso inválido — lida pelo Player após is_landing_valid() retornar false.
var last_fail_reason: String = ""

@export var rotation_speed: float = 90.0:   # graus por segundo
	set(value):
		rotation_speed = value

@export var circle_radius: float = 80.0:
	set(value):
		circle_radius = value
		_sync_arc_visual()
		_sync_collision_shape()

## Pares [inicio_grau, fim_grau] no espaço local de RotationRoot.
## Exemplo: Vector2(30, 150) bloqueia de 30° a 150° no sentido horário.
@export var blocked_arcs: Array[Vector2] = [Vector2(30, 150), Vector2(210, 330)]:
	set(value):
		blocked_arcs = value
		_sync_arc_visual()

@export var is_active: bool = true:
	set(value):
		is_active = value
		_sync_active_state()

@export var pulse_enabled: bool = false:
	set(value):
		pulse_enabled = value
		_pulse_timer = 0.0
		if not pulse_enabled:
			is_active = true

@export var pulse_active_duration: float   = 1.3
@export var pulse_inactive_duration: float = 0.8

var _pulse_timer: float = 0.0

## Número de orbiters gerados proceduralmente no _ready().
@export var orbiter_count: int = 0
@export var orbiter_base_radius_mult: float = 1.5

## Quando true, ao pousar os orbiters ficam vermelhos e perseguem o player.
## Game.gd chama activate_chasers() em vez de clear_orbiters() ao pousar.
@export var orbiter_chaser: bool = false

## Quando true, a cada pouso a rotação inverte e as zonas livre/bloqueada trocam.
@export var mirror_mode: bool = false
var _mirror_flipped: bool = false

## Quando true, ao pousar o anel externo começa a encolher em direção ao anel interno.
## Ao tocar o anel interno, explode e o player morre.
@export var shrink_enabled: bool = false
@export var inner_radius: float = 28.0   # raio do anel interno fixo
@export var shrink_speed: float = 18.0   # px/s de encolhimento
var _shrink_radius: float = 0.0
var _shrinking: bool = false

## Quando true, raio, velocidade/direção e padrão de arcos são randomizados no _ready().
@export var level_randomize: bool = false

const RAND_RADIUS_MIN       := 48.0
const RAND_RADIUS_MAX       := 80.0
const RAND_SPEED_MIN        := 50.0
const RAND_SPEED_MAX        := 95.0
const RAND_PULSE_SPEED_MIN  := 35.0
const RAND_PULSE_SPEED_MAX  := 80.0
const RAND_MIRROR_SPEED_MIN  := 60.0
const RAND_MIRROR_SPEED_MAX  := 110.0
const RAND_SHRINK_RADIUS_MIN := 65.0
const RAND_SHRINK_RADIUS_MAX := 88.0
const RAND_SHRINK_SPEED_MIN  := 14.0   # px/s
const RAND_SHRINK_SPEED_MAX  := 28.0   # px/s

## Número exibido em background no centro (0 = nenhum). Usado nos círculos de checkpoint.
@export var bg_number: int = 0:
	set(value):
		bg_number = value
		queue_redraw()

@onready var rotation_root: Node2D      = $RotationRoot
@onready var arc_visual: Node2D         = $RotationRoot/ArcVisual
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D


const PULSE_RING_OFFSET := 8.0   # distância do anel ao círculo (px)
const PULSE_RING_WIDTH  := 3.5   # espessura do anel
const PULSE_RING_ACTIVE_COLOR   := Color(0.9,  0.95, 1.0,  0.75)
const PULSE_RING_INACTIVE_COLOR := Color(1.0,  0.55, 0.1,  0.75)


func _draw() -> void:
	if bg_number > 0:
		var font: Font = ThemeDB.fallback_font
		var font_size := int(circle_radius * 1.15)
		var text := str(bg_number)
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(-tw * 0.5, font_size * 0.38),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			Color(1.0, 1.0, 1.0, 0.13))

	if shrink_enabled:
		draw_arc(Vector2.ZERO, inner_radius, 0.0, TAU, 48, Color(0.2, 0.55, 1.0, 0.85), 2.5)

	if pulse_enabled:
		var duration: float = pulse_active_duration if is_active else pulse_inactive_duration
		var remaining: float = 1.0 - clampf(_pulse_timer / duration, 0.0, 1.0)
		var span: float = TAU * remaining
		if span > 0.01:
			var ring_r: float = circle_radius + PULSE_RING_OFFSET
			var color: Color = PULSE_RING_ACTIVE_COLOR if is_active else PULSE_RING_INACTIVE_COLOR
			var pts: int = max(4, int(remaining * 64))
			# Começa no topo (−PI/2) e drena no sentido horário
			draw_arc(Vector2.ZERO, ring_r, -PI * 0.5, -PI * 0.5 + span, pts, color, PULSE_RING_WIDTH)


func _ready() -> void:
	if not Engine.is_editor_hint() and level_randomize:
		_apply_random_arc()
	_sync_arc_visual()
	_sync_active_state()
	_sync_collision_shape()
	_shrink_radius = circle_radius
	if not Engine.is_editor_hint() and orbiter_count > 0:
		_spawn_orbiters()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	rotation_root.rotation_degrees += rotation_speed * delta

	if pulse_enabled:
		_pulse_timer += delta
		var duration := pulse_active_duration if is_active else pulse_inactive_duration
		if _pulse_timer >= duration:
			_pulse_timer = 0.0
			is_active = !is_active
		queue_redraw()

	if _shrinking:
		_shrink_radius -= shrink_speed * delta
		arc_visual.circle_radius = _shrink_radius
		arc_visual.queue_redraw()
		queue_redraw()
		if _shrink_radius <= inner_radius:
			_shrinking = false
			shrink_exploded.emit()


# ---------------------------------------------------------------------------
# API pública
# ---------------------------------------------------------------------------

## Gera orbiters proceduralmente com tamanhos, raios e velocidades aleatórios.
## Raio de órbita proporcional a circle_radius * orbiter_base_radius_mult.
func _spawn_orbiters() -> void:
	var scene := preload("res://scenes/entities/Orbiter.tscn")
	for i in orbiter_count:
		var orb: Node2D = scene.instantiate()
		add_child(orb)
		orb.orbit_radius  = circle_radius * orbiter_base_radius_mult * randf_range(0.9, 1.7)
		orb.orbit_speed   = randf_range(45.0, 140.0) * (1.0 if randf() > 0.5 else -1.0)
		orb.start_angle   = randf() * 360.0
		orb.sphere_radius = randf_range(3.5, 11.0)
		orb.sphere_color  = Color(
			randf_range(0.75, 1.0),
			randf_range(0.1,  0.5),
			randf_range(0.1,  0.35)
		)


## Faz todos os orbiters filhos sumirem (chamado pelo Game ao pousar neste círculo).
func clear_orbiters() -> void:
	for child in get_children():
		if child.has_method("fade_and_free"):
			child.fade_and_free()


## Ativa o modo perseguidor em todos os orbiters filhos.
## Chamado pelo Game ao pousar num círculo com orbiter_chaser = true.
func activate_chasers(target: Node2D) -> void:
	for child in get_children():
		if child.has_method("start_chasing"):
			child.start_chasing(target)


## Inicia o encolhimento do anel externo em direção ao inner_radius.
## Chamado pelo Game ao pousar num círculo com shrink_enabled = true.
func start_shrinking() -> void:
	if not shrink_enabled:
		return
	_shrink_radius = circle_radius
	arc_visual.circle_radius = _shrink_radius
	_shrinking = true


## Para o encolhimento e restaura o raio original.
## Chamado quando o player sai do círculo ou morre.
func stop_shrinking() -> void:
	_shrinking = false
	_shrink_radius = circle_radius
	arc_visual.circle_radius = circle_radius
	arc_visual.queue_redraw()


## Inverte o estado do mirror: troca rotação e zonas livre/bloqueada.
## Chamado pelo Game ao pousar num círculo com mirror_mode = true.
func flip_mirror() -> void:
	if not mirror_mode:
		return
	_mirror_flipped = not _mirror_flipped
	rotation_speed = -rotation_speed
	_sync_arc_visual()


## Libera todos os chasers (player saiu do círculo ou morreu).
func release_chasers() -> void:
	for child in get_children():
		if child.has_method("stop_chasing"):
			child.stop_chasing()


## Remove instantaneamente todos os orbiters e os recria.
## Chamado pelo Game ao respawnar, para restaurar o estado original do círculo.
func reset_orbiters() -> void:
	if orbiter_count <= 0:
		return
	for child in get_children():
		if child.has_method("fade_and_free"):
			child.queue_free()
	_spawn_orbiters()


## Reverte o estado do mirror para o inicial (não-flipado).
## Chamado pelo Game ao respawnar.
func reset_mirror() -> void:
	if _mirror_flipped:
		flip_mirror()


## Verifica se é possível SAIR deste círculo na direção world_angle_deg.
## Mesma lógica de is_landing_valid, mas silenciosa (sem sinais, sem last_fail_reason).
func can_exit(world_angle_deg: float) -> bool:
	if not is_active:
		return false
	var local_angle := _world_to_local_angle(world_angle_deg)
	var in_arc := false
	for arc in blocked_arcs:
		if _angle_in_arc(local_angle, arc.x, arc.y):
			in_arc = true
			break
	# Normal: bloqueado se in_arc. Mirror flip: bloqueado se NOT in_arc.
	return in_arc == _mirror_flipped


## Verifica se o pouso no ângulo world_angle_deg (em graus, relativo ao centro
## deste círculo) é válido. Emite landing_failed com a razão em caso negativo.
func is_landing_valid(world_angle_deg: float) -> bool:
	if not is_active:
		last_fail_reason = "inactive"
		landing_failed.emit("inactive")
		return false

	var local_angle := _world_to_local_angle(world_angle_deg)
	var in_arc := false
	for arc in blocked_arcs:
		if _angle_in_arc(local_angle, arc.x, arc.y):
			in_arc = true
			break

	# Normal: bloqueado se in_arc. Mirror flip: bloqueado se NOT in_arc.
	var blocked := in_arc != _mirror_flipped
	if blocked:
		last_fail_reason = "blocked"
		landing_failed.emit("blocked")
		return false

	last_fail_reason = ""
	return true


# ---------------------------------------------------------------------------
# Randomização de nível
# ---------------------------------------------------------------------------

func _apply_random_arc() -> void:
	circle_radius = randf_range(RAND_RADIUS_MIN, RAND_RADIUS_MAX)
	var speed := randf_range(RAND_SPEED_MIN, RAND_SPEED_MAX)
	rotation_speed = speed if randf() > 0.5 else -speed
	if orbiter_chaser:
		_apply_random_chaser_config()
	elif shrink_enabled:
		circle_radius  = randf_range(RAND_SHRINK_RADIUS_MIN, RAND_SHRINK_RADIUS_MAX)
		var spd := randf_range(RAND_SPEED_MIN, RAND_SPEED_MAX)
		rotation_speed = spd if randf() > 0.5 else -spd
		shrink_speed   = randf_range(RAND_SHRINK_SPEED_MIN, RAND_SHRINK_SPEED_MAX)
		blocked_arcs   = _random_arc_pattern()
	elif mirror_mode:
		rotation_speed = (randf_range(RAND_MIRROR_SPEED_MIN, RAND_MIRROR_SPEED_MAX)
				* (1.0 if randf() > 0.5 else -1.0))
		blocked_arcs = _random_arc_pattern()
	elif pulse_enabled:
		rotation_speed = (randf_range(RAND_PULSE_SPEED_MIN, RAND_PULSE_SPEED_MAX)
				* (1.0 if randf() > 0.5 else -1.0))
		_apply_random_pulse_timing()
	else:
		blocked_arcs = _random_arc_pattern()


func _apply_random_pulse_timing() -> void:
	var timings: Array = [
		[1.8, 0.7],
		[1.5, 0.9],
		[0.7, 1.4],
		[2.0, 0.5],
		[1.0, 1.2],
	]
	var t: Array = timings[randi() % timings.size()]
	pulse_active_duration   = t[0]
	pulse_inactive_duration = t[1]


func _apply_random_chaser_config() -> void:
	# Cada padrão: [orbiter_count, orbiter_base_radius_mult]
	var configs: Array = [
		[2, 1.5],
		[2, 1.3],
		[3, 1.4],
		[3, 1.3],
		[4, 1.35],
	]
	var c: Array = configs[randi() % configs.size()]
	orbiter_count             = c[0]
	orbiter_base_radius_mult  = c[1]


func _random_arc_pattern() -> Array[Vector2]:
	var p0: Array[Vector2] = [Vector2(30,  150)]
	var p1: Array[Vector2] = [Vector2(15,  175)]
	var p2: Array[Vector2] = [Vector2(200, 340)]
	var p3: Array[Vector2] = [Vector2(10,  70),  Vector2(190, 250)]
	var p4: Array[Vector2] = [Vector2(40,  110), Vector2(210, 285)]
	var patterns: Array    = [p0, p1, p2, p3, p4]
	return patterns[randi() % patterns.size()]


# ---------------------------------------------------------------------------
# Helpers internos
# ---------------------------------------------------------------------------

func _world_to_local_angle(world_angle_deg: float) -> float:
	var local := fmod(world_angle_deg - rotation_root.rotation_degrees, 360.0)
	if local < 0.0:
		local += 360.0
	return local


## Retorna true se angle está dentro do arco [start, end] (ambos em graus).
## Suporta arcos que cruzam 0° (start > end).
func _angle_in_arc(angle: float, start: float, end: float) -> bool:
	if start <= end:
		return angle >= start and angle <= end
	else:
		return angle >= start or angle <= end


func _sync_arc_visual() -> void:
	if not is_node_ready():
		return
	arc_visual.circle_radius  = circle_radius
	arc_visual.blocked_arcs   = blocked_arcs
	arc_visual.mirror_flipped = _mirror_flipped
	arc_visual.queue_redraw()


func _sync_active_state() -> void:
	modulate.a = 1.0 if is_active else 0.3


func _sync_collision_shape() -> void:
	if not is_node_ready():
		return
	if collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = circle_radius
