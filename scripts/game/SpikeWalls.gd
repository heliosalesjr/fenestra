extends Node2D

## Desenhado dentro de um CanvasLayer — coordenadas de tela (pixels fixos),
## completamente independentes da posição/zoom da câmera.

const VIEWPORT_W    := 390.0
const VIEWPORT_H    := 844.0
const ELEC_INTERVAL := 0.055  # segundos entre flickers

var _elec_timer: float = 0.0


func _process(delta: float) -> void:
	_elec_timer += delta
	if _elec_timer >= ELEC_INTERVAL:
		_elec_timer = 0.0
		queue_redraw()


func _draw() -> void:
	_draw_elec_wall(0.0)
	_draw_elec_wall(VIEWPORT_W)


func _draw_elec_wall(x: float) -> void:
	var n   := max(8, int(VIEWPORT_H / 6.0))
	var pts := PackedVector2Array()
	for i in range(n + 1):
		var t  := float(i) / float(n)
		var y  := t * VIEWPORT_H
		var dx := randf_range(-7.0, 7.0) if (i > 0 and i < n) else 0.0
		pts.append(Vector2(x + dx, y))
	draw_polyline(pts, Color(0.9, 0.15, 0.05, 0.18), 11.0, true)
	draw_polyline(pts, Color(1.0, 0.25, 0.05, 0.40),  5.0, true)
	draw_polyline(pts, Color(1.0, 0.92, 0.88, 0.95),  1.5, true)
