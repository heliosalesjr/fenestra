@tool
extends Node2D

## Desenhado como filho de RotationRoot.
## As coordenadas são locais ao RotationRoot, então giram automaticamente com ele.

const FREE_COLOR    := Color(0.2, 0.9, 0.3)        # verde vibrante
const BLOCKED_COLOR := Color(0.15, 0.15, 0.15, 1.0) # cinza escuro
const ARC_WIDTH     := 5.0
const ARC_POINTS    := 64

var circle_radius: float = 80.0
var blocked_arcs: Array = []  # Array de Vector2(start_deg, end_deg)


func _draw() -> void:
	# 1. Anel completo na cor livre (verde)
	draw_arc(Vector2.ZERO, circle_radius, 0.0, TAU, ARC_POINTS, FREE_COLOR, ARC_WIDTH)

	# 2. Segmentos bloqueados por cima (cinza escuro, ligeiramente mais grosso)
	for arc in blocked_arcs:
		_draw_arc_segment(arc.x, arc.y, BLOCKED_COLOR, ARC_WIDTH + 1.0)


func _draw_arc_segment(start_deg: float, end_deg: float, color: Color, width: float) -> void:
	if start_deg <= end_deg:
		var pts := _arc_points(end_deg - start_deg)
		draw_arc(Vector2.ZERO, circle_radius,
				deg_to_rad(start_deg), deg_to_rad(end_deg),
				pts, color, width)
	else:
		# Arco que cruza 0° — divide em duas partes
		var pts1 := _arc_points(360.0 - start_deg)
		var pts2 := _arc_points(end_deg)
		draw_arc(Vector2.ZERO, circle_radius,
				deg_to_rad(start_deg), TAU,
				pts1, color, width)
		draw_arc(Vector2.ZERO, circle_radius,
				0.0, deg_to_rad(end_deg),
				pts2, color, width)


func _arc_points(span_deg: float) -> int:
	return max(4, int(span_deg / 360.0 * ARC_POINTS))
