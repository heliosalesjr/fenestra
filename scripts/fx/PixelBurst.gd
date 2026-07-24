extends Node2D

## Efeito de partículas genérico: quadradinhos saltando do ponto de origem,
## com fricção e fade quadrático, com anel de onda de choque opcional.
## Duas variantes prontas (mesma física por baixo, só a config muda):
## - fire_burst(): burst simples de pouso, usado por Player.gd
## - fire_boom(): "boom" do powerup Rocket — maior, mais partículas, com anel,
##   usado por Game.gd
## Instancia-se via código, adiciona-se à cena, e se destrói sozinho.

const BURST_PIXEL_SIZE     := 4.0
const BURST_PARTICLE_COUNT := 12
const BURST_SPEED_MIN      := 120.0
const BURST_SPEED_MAX      := 300.0
const BURST_LIFETIME       := 0.4
const BURST_FRICTION       := 0.88

const BOOM_PIXEL_SIZE      := 5.0
const BOOM_PARTICLE_COUNT  := 22
const BOOM_SPEED_MIN       := 160.0
const BOOM_SPEED_MAX       := 420.0
const BOOM_LIFETIME        := 0.5
const BOOM_FRICTION        := 0.90
const BOOM_RING_MAX_RADIUS := 95.0
const BOOM_RING_LIFETIME   := 0.32
const BOOM_COLORS: Array[Color] = [
	Color(1.0, 0.85, 0.2),
	Color(1.0, 0.55, 0.1),
	Color(1.0, 0.25, 0.05),
	Color(1.0, 1.0, 0.8),
]

const SIZE_JITTER_MIN := 0.7
const SIZE_JITTER_MAX := 1.6

var _particles: Array = []
var _lifetime: float = BURST_LIFETIME
var _friction: float = BURST_FRICTION

var _age: float = 0.0
var _ring_max_radius: float = 0.0
var _ring_lifetime: float = 0.0


## Burst simples de pouso (mesma assinatura de antes — chamado por Player.gd).
func fire_burst(_outward_dir: Vector2, base_color: Color = Color(0.2, 0.9, 0.3)) -> void:
	var colors: Array[Color] = [
		base_color,
		base_color.lightened(0.35),
		base_color.lightened(0.6),
		base_color.darkened(0.25),
	]
	_spawn(colors, BURST_PARTICLE_COUNT, BURST_PIXEL_SIZE, BURST_SPEED_MIN, BURST_SPEED_MAX,
		BURST_LIFETIME, BURST_FRICTION)


## "Boom" do powerup Rocket (mesma assinatura de antes — chamado por Game.gd).
## `scale_mult` escala tamanho do anel de choque e quantidade/tamanho das fagulhas
## — usado pelo Rocket para deixar tiers mais altos mais dramáticos.
func fire_boom(scale_mult: float = 1.0) -> void:
	_ring_max_radius = BOOM_RING_MAX_RADIUS * scale_mult
	_ring_lifetime    = BOOM_RING_LIFETIME
	var count := int(round(BOOM_PARTICLE_COUNT * scale_mult))
	_spawn(BOOM_COLORS, count, BOOM_PIXEL_SIZE * scale_mult, BOOM_SPEED_MIN, BOOM_SPEED_MAX,
		BOOM_LIFETIME, BOOM_FRICTION)


func _spawn(colors: Array[Color], count: int, pixel_size: float, speed_min: float,
		speed_max: float, lifetime: float, friction: float) -> void:
	_lifetime = lifetime
	_friction = friction
	for i in count:
		var angle := randf() * TAU
		var dir   := Vector2(cos(angle), sin(angle))
		var speed := randf_range(speed_min, speed_max)
		var sz    := pixel_size * randf_range(SIZE_JITTER_MIN, SIZE_JITTER_MAX)
		_particles.append({
			"pos":   Vector2.ZERO,
			"vel":   dir * speed,
			"age":   0.0,
			"size":  sz,
			"color": colors[randi() % colors.size()],
		})


func _process(delta: float) -> void:
	_age += delta
	var any_alive := _age < _ring_lifetime
	for p in _particles:
		if p["age"] >= _lifetime:
			continue
		p["age"] += delta
		p["vel"]   = p["vel"] * _friction
		p["pos"]  += p["vel"] * delta
		any_alive = true
	queue_redraw()
	if not any_alive:
		queue_free()


func _draw() -> void:
	if _ring_max_radius > 0.0 and _age < _ring_lifetime:
		var t     := _age / _ring_lifetime
		var r     := lerpf(10.0, _ring_max_radius, t)
		var alpha := 1.0 - t
		draw_arc(Vector2.ZERO, r,       0.0, TAU, 40, Color(1.0, 0.75, 0.25, alpha * 0.85), 4.0)
		draw_arc(Vector2.ZERO, r * 0.6, 0.0, TAU, 32, Color(1.0, 1.0,  0.85, alpha * 0.6),  2.0)

	for p in _particles:
		if p["age"] >= _lifetime:
			continue
		var t: float = p["age"] / _lifetime
		var alpha  := 1.0 - t * t   # fade quadrático
		var sz: float  = p["size"]
		var color: Color = p["color"]
		color.a = alpha
		draw_rect(Rect2(p["pos"] - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), color)
