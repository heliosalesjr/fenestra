extends Node2D

@export var orbit_radius: float = 90.0
@export var orbit_speed: float  = 80.0    # graus/s  (positivo = horário)
@export var sphere_radius: float = 7.0
@export var sphere_color: Color  = Color(0.95, 0.35, 0.35)
@export var start_angle: float   = 0.0    # graus

enum Mode { ORBITING, CHASING, FLEEING }

const CHASE_SPEED := 110.0   # px/s em direção ao player
const FLEE_SPEED  := 240.0   # px/s ao fugir após o player sair

var _angle_deg: float = 0.0
var _mode: Mode = Mode.ORBITING
var _chase_target: Node2D = null
var _flee_dir: Vector2 = Vector2.ZERO
var _draw_color: Color


func _ready() -> void:
	_angle_deg = start_angle
	_draw_color = sphere_color


func _process(delta: float) -> void:
	match _mode:
		Mode.ORBITING:
			_angle_deg += orbit_speed * delta
			position = Vector2.RIGHT.rotated(deg_to_rad(_angle_deg)) * orbit_radius
		Mode.CHASING:
			if _chase_target and is_instance_valid(_chase_target):
				var dir := (_chase_target.global_position - global_position).normalized()
				global_position += dir * CHASE_SPEED * delta
		Mode.FLEEING:
			global_position += _flee_dir * FLEE_SPEED * delta


func _draw() -> void:
	draw_circle(Vector2.ZERO, sphere_radius, _draw_color)


# ─── API de perseguição ──────────────────────────────────────────────────────

## Ativa o modo perseguidor: fica vermelho e começa a se mover em direção a target.
func start_chasing(target: Node2D) -> void:
	_mode = Mode.CHASING
	_chase_target = target
	_draw_color = Color(0.95, 0.15, 0.15)
	queue_redraw()


## Para a perseguição: voa para longe do centro do círculo e faz fade out.
## Chamado quando o player sai do círculo.
func stop_chasing() -> void:
	if _mode != Mode.CHASING:
		return
	_flee_dir = (global_position - get_parent().global_position).normalized()
	if _flee_dir.length_squared() < 0.01:
		_flee_dir = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	_mode = Mode.FLEEING
	_chase_target = null
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


## Fade out padrão (orbiters normais ao pousar no círculo).
func fade_and_free() -> void:
	if _mode == Mode.CHASING:
		stop_chasing()
		return
	set_process(false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
