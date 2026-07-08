class_name Barrier
extends Node2D

## Barreira horizontal com um vão (gap) que desliza da esquerda pra direita e volta.
## Fica entre dois círculos; o player precisa cruzar sua altura (Y) exatamente
## quando o vão estiver alinhado com a posição X do pulo. Combina com CircleArc
## para exigir leitura de arco (no círculo) + leitura de posição (na barreira).

@export var gap_width: float = 70.0
@export var speed: float     = 120.0   # px/s de deslocamento do vão
## Quando true, velocidade, largura do vão e posição/direção iniciais são
## sorteadas no _ready() (mesmo padrão de `level_randomize` em Circle.gd).
@export var level_randomize: bool = true

const VIEWPORT_W     := 390.0
const BAR_COLOR      := Color(0.85, 0.15, 0.1, 0.85)
const BAR_THICKNESS  := 6.0

const RAND_SPEED_MIN := 70.0
const RAND_SPEED_MAX := 160.0
const RAND_GAP_MIN   := 60.0
const RAND_GAP_MAX   := 85.0

var _gap_x: float     = VIEWPORT_W * 0.5
var _direction: float = 1.0


func _ready() -> void:
	if level_randomize:
		speed     = randf_range(RAND_SPEED_MIN, RAND_SPEED_MAX)
		gap_width = randf_range(RAND_GAP_MIN, RAND_GAP_MAX)
		_gap_x    = randf_range(gap_width * 0.5, VIEWPORT_W - gap_width * 0.5)
	_direction = 1.0 if randf() > 0.5 else -1.0


func _process(delta: float) -> void:
	var half := gap_width * 0.5
	_gap_x += _direction * speed * delta
	if _gap_x >= VIEWPORT_W - half:
		_gap_x = VIEWPORT_W - half
		_direction = -1.0
	elif _gap_x <= half:
		_gap_x = half
		_direction = 1.0
	queue_redraw()


func _draw() -> void:
	var half  := gap_width * 0.5
	var gap_l := _gap_x - half
	var gap_r := _gap_x + half
	if gap_l > 0.0:
		draw_line(Vector2(0.0, 0.0), Vector2(gap_l, 0.0), BAR_COLOR, BAR_THICKNESS, true)
	if gap_r < VIEWPORT_W:
		draw_line(Vector2(gap_r, 0.0), Vector2(VIEWPORT_W, 0.0), BAR_COLOR, BAR_THICKNESS, true)


## Retorna true se world_x (coordenada X global) está dentro do vão livre agora.
## Chamado por Game._check_barriers() no instante em que o player cruza esta altura.
func is_open_at(world_x: float) -> bool:
	var local_x := world_x - global_position.x
	return local_x >= _gap_x - gap_width * 0.5 and local_x <= _gap_x + gap_width * 0.5
