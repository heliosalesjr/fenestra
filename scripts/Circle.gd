@tool
extends Node2D

## Círculo giratório — unidade central de jogo.
## Contém RotationRoot (que gira) com ArcVisual (que desenha os segmentos).

signal landing_failed(reason: String)

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

## Número exibido em background no centro (0 = nenhum). Usado nos círculos de checkpoint.
@export var bg_number: int = 0:
	set(value):
		bg_number = value
		queue_redraw()

@onready var rotation_root: Node2D      = $RotationRoot
@onready var arc_visual: Node2D         = $RotationRoot/ArcVisual
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D


func _draw() -> void:
	if bg_number <= 0:
		return
	var font: Font = ThemeDB.fallback_font
	var font_size := int(circle_radius * 1.15)
	var text := str(bg_number)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(-tw * 0.5, font_size * 0.38),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		Color(1.0, 1.0, 1.0, 0.13))


func _ready() -> void:
	_sync_arc_visual()
	_sync_active_state()
	_sync_collision_shape()
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


# ---------------------------------------------------------------------------
# API pública
# ---------------------------------------------------------------------------

## Gera orbiters proceduralmente com tamanhos, raios e velocidades aleatórios.
## Raio de órbita proporcional a circle_radius * orbiter_base_radius_mult.
func _spawn_orbiters() -> void:
	var scene := preload("res://scenes/Orbiter.tscn")
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


## Verifica se é possível SAIR deste círculo na direção world_angle_deg.
## Mesma lógica de is_landing_valid, mas silenciosa (sem sinais, sem last_fail_reason).
func can_exit(world_angle_deg: float) -> bool:
	if not is_active:
		return false
	var local_angle := _world_to_local_angle(world_angle_deg)
	for arc in blocked_arcs:
		if _angle_in_arc(local_angle, arc.x, arc.y):
			return false
	return true


## Verifica se o pouso no ângulo world_angle_deg (em graus, relativo ao centro
## deste círculo) é válido. Emite landing_failed com a razão em caso negativo.
func is_landing_valid(world_angle_deg: float) -> bool:
	if not is_active:
		last_fail_reason = "inactive"
		landing_failed.emit("inactive")
		return false

	var local_angle := _world_to_local_angle(world_angle_deg)

	for arc in blocked_arcs:
		if _angle_in_arc(local_angle, arc.x, arc.y):
			last_fail_reason = "blocked"
			landing_failed.emit("blocked")
			return false

	last_fail_reason = ""
	return true


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
	arc_visual.circle_radius = circle_radius
	arc_visual.blocked_arcs  = blocked_arcs
	arc_visual.queue_redraw()


func _sync_active_state() -> void:
	modulate.a = 1.0 if is_active else 0.3


func _sync_collision_shape() -> void:
	if not is_node_ready():
		return
	if collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = circle_radius
