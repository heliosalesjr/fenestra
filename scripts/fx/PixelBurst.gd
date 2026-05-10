extends Node2D

## Efeito de choque pixelado: quadradinhos saltando do ponto de contato.
## Instancia-se via código, adiciona-se ao pai do Player, e se destrói sozinho.

const PIXEL_SIZE     := 4.0
const PARTICLE_COUNT := 12
const SPEED_MIN      := 120.0
const SPEED_MAX      := 300.0
const LIFETIME       := 0.4
const FRICTION       := 0.88  # multiplicador de velocidade por frame

const COLORS: Array = [
	Color(0.2, 0.9,  0.3),     # verde base do círculo
	Color(0.4, 1.0,  0.5),     # verde claro
	Color(0.1, 0.75, 0.25),    # verde escuro
	Color(0.7, 1.0,  0.75),    # verde quase branco
]

var _particles: Array = []


func fire(_outward_dir: Vector2) -> void:
	for i in PARTICLE_COUNT:
		var angle := randf() * TAU
		var dir   := Vector2(cos(angle), sin(angle))
		var speed := randf_range(SPEED_MIN, SPEED_MAX)
		var sz    := PIXEL_SIZE * randf_range(0.75, 1.5)
		_particles.append({
			"pos":   Vector2.ZERO,
			"vel":   dir * speed,
			"age":   0.0,
			"size":  sz,
			"color": COLORS[randi() % COLORS.size()],
		})


func _process(delta: float) -> void:
	var any_alive := false
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
	for p in _particles:
		if p["age"] >= LIFETIME:
			continue
		var t: float = p["age"] / LIFETIME
		var alpha  := 1.0 - t * t   # fade quadrático
		var sz: float  = p["size"]
		var color: Color = p["color"]
		color.a = alpha
		draw_rect(Rect2(p["pos"] - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), color)
