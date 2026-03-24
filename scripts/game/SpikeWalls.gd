extends Node2D

## Desenhado dentro de um CanvasLayer — coordenadas de tela (pixels fixos),
## completamente independentes da posição/zoom da câmera.

const VIEWPORT_W := 390.0
const VIEWPORT_H := 844.0
const DEPTH      := 14.0   # profundidade dos dentes para dentro da tela (px)
const STEP       := 20.0   # espaçamento entre dentes (px)


func _draw() -> void:
	var wall  := Color(0.65, 0.08, 0.08, 0.75)
	var teeth := Color(0.92, 0.18, 0.12, 0.9)

	# ── Parede esquerda (x = 0) ────────────────────────────────────────────
	draw_line(Vector2(0.0, 0.0), Vector2(0.0, VIEWPORT_H), wall, 3.0)
	var pts_l := PackedVector2Array()
	var y     := 0.0
	while y <= VIEWPORT_H + STEP:
		pts_l.append(Vector2(0.0, y))
		pts_l.append(Vector2(DEPTH, y + STEP * 0.5))
		y += STEP
	draw_polyline(pts_l, teeth, 2.0, true)

	# ── Parede direita (x = VIEWPORT_W) ────────────────────────────────────
	draw_line(Vector2(VIEWPORT_W, 0.0), Vector2(VIEWPORT_W, VIEWPORT_H), wall, 3.0)
	var pts_r := PackedVector2Array()
	y = 0.0
	while y <= VIEWPORT_H + STEP:
		pts_r.append(Vector2(VIEWPORT_W, y))
		pts_r.append(Vector2(VIEWPORT_W - DEPTH, y + STEP * 0.5))
		y += STEP
	draw_polyline(pts_r, teeth, 2.0, true)
