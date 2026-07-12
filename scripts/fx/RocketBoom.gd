extends Node2D

## Efeito de "boom" do powerup Rocket: onda de choque + fagulhas maiores e mais
## numerosas que o PixelBurst normal de pouso. Instancia-se via código,
## adiciona-se à cena, e se destrói sozinho.

const RING_MAX_RADIUS := 95.0
const RING_LIFETIME    := 0.32

const PARTICLE_COUNT := 22
const PIXEL_SIZE     := 5.0
const SPEED_MIN       := 160.0
const SPEED_MAX       := 420.0
const LIFETIME        := 0.5
const FRICTION        := 0.90

const COLORS: Array[Color] = [
	Color(1.0, 0.85, 0.2),
	Color(1.0, 0.55, 0.1),
	Color(1.0, 0.25, 0.05),
	Color(1.0, 1.0, 0.8),
]

var _particles: Array = []
var _age: float = 0.0


func fire() -> void:
	for i in PARTICLE_COUNT:
		var angle := randf() * TAU
		var dir   := Vector2(cos(angle), sin(angle))
		var speed := randf_range(SPEED_MIN, SPEED_MAX)
		var sz    := PIXEL_SIZE * randf_range(0.7, 1.6)
		_particles.append({
			"pos":   Vector2.ZERO,
			"vel":   dir * speed,
			"age":   0.0,
			"size":  sz,
			"color": COLORS[randi() % COLORS.size()],
		})


func _process(delta: float) -> void:
	_age += delta
	var any_alive := _age < RING_LIFETIME
	for p in _particles:
		if p["age"] >= LIFETIME:
			continue
		p["age"] += delta
		p["vel"]   = p["vel"] * FRICTION
		p["pos"]  += p["vel"] * delta
		any_alive = true
	queue_redraw()
	if not any_alive:
		queue_free()


func _draw() -> void:
	if _age < RING_LIFETIME:
		var t     := _age / RING_LIFETIME
		var r     := lerpf(10.0, RING_MAX_RADIUS, t)
		var alpha := 1.0 - t
		draw_arc(Vector2.ZERO, r,       0.0, TAU, 40, Color(1.0, 0.75, 0.25, alpha * 0.85), 4.0)
		draw_arc(Vector2.ZERO, r * 0.6, 0.0, TAU, 32, Color(1.0, 1.0,  0.85, alpha * 0.6),  2.0)

	for p in _particles:
		if p["age"] >= LIFETIME:
			continue
		var t: float = p["age"] / LIFETIME
		var alpha  := 1.0 - t * t
		var sz: float  = p["size"]
		var color: Color = p["color"]
		color.a = alpha
		draw_rect(Rect2(p["pos"] - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), color)
