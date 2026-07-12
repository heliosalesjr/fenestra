extends Node2D

## Powerup Rocket: torna o player invencível e pilota automaticamente os
## próximos círculos (ver Game.gd::_on_rocket_collected / _rocket_advance).
## `level` define quantos círculos são pulados: 1 → 3, 2 → 4, 3 → 5
## (fórmula `level + 2`, ver Game.gd).
signal collected(level: int)

@export_range(1, 3, 1) var level: int = 1

var _active: bool   = true
var _bob_time: float = 0.0

const VISUAL_RADIUS := 12.0
const COLOR         := Color(1.0, 0.4, 0.08)
const FLAME_COLOR   := Color(1.0, 0.75, 0.15)
const TIER_COLOR     := Color(1.0, 0.95, 0.5)


func _process(delta: float) -> void:
	if not _active:
		return
	_bob_time += delta * 3.0
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	var bob    := sin(_bob_time) * 4.0
	var center := Vector2(0.0, bob)
	var r      := VISUAL_RADIUS * (1.0 + (level - 1) * 0.16)

	# Auréola pulsante — uma camada extra por nível de potência.
	var pulse := 0.75 + 0.25 * sin(_bob_time * 1.6)
	for i in level:
		var ring_r := r * (1.5 + i * 0.32)
		draw_circle(center, ring_r, Color(COLOR, 0.10 * pulse))
		draw_arc(center, ring_r * 0.77, 0.0, TAU, 24, Color(COLOR, 0.35), 1.5)

	# Chama (aponta para baixo)
	var flame := PackedVector2Array([
		center + Vector2(-r * 0.32, r * 0.55),
		center + Vector2( r * 0.32, r * 0.55),
		center + Vector2( 0.0,      r * 1.15 + absf(sin(_bob_time * 4.0)) * 4.0),
	])
	draw_colored_polygon(flame, FLAME_COLOR)

	# Corpo do foguete (aponta para cima)
	var body := PackedVector2Array([
		center + Vector2( 0.0,      -r),
		center + Vector2( r * 0.42,  r * 0.45),
		center + Vector2(-r * 0.42,  r * 0.45),
	])
	draw_colored_polygon(body, COLOR)
	draw_polyline(body + PackedVector2Array([body[0]]), Color.WHITE.lightened(0.0), 1.4, true)

	# Ogiva
	draw_circle(center + Vector2(0.0, -r * 0.15), r * 0.34, Color(1.0, 1.0, 1.0, 0.9))

	# Aletas
	draw_line(center + Vector2(-r * 0.42, r * 0.45), center + Vector2(-r * 0.75, r * 0.85), COLOR.darkened(0.15), 3.0, true)
	draw_line(center + Vector2( r * 0.42, r * 0.45), center + Vector2( r * 0.75, r * 0.85), COLOR.darkened(0.15), 3.0, true)

	# Pips de nível (marcam o tier: I, II ou III) acima do foguete.
	for i in level:
		var px := center.x + (float(i) - float(level - 1) * 0.5) * 7.0
		draw_circle(Vector2(px, center.y - r * 1.55), 2.2, TIER_COLOR)


func collect() -> void:
	if not _active:
		return
	_active = false
	collected.emit(level)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale",      Vector2(1.8, 1.8), 0.15)
	tween.tween_property(self, "modulate:a", 0.0,               0.15)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
