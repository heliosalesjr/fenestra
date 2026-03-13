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

@onready var rotation_root: Node2D      = $RotationRoot
@onready var arc_visual: Node2D         = $RotationRoot/ArcVisual
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D


func _ready() -> void:
	_sync_arc_visual()
	_sync_active_state()
	_sync_collision_shape()


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

## Faz todos os orbiters filhos sumirem (chamado pelo Game ao pousar neste círculo).
func clear_orbiters() -> void:
	for child in get_children():
		if child.has_method("fade_and_free"):
			child.fade_and_free()


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
