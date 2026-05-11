@tool
extends Node2D

## Desenhado como filho de RotationRoot.
## As coordenadas são locais ao RotationRoot, então giram automaticamente com ele.

const BLOCKED_COLOR := Color(0.15, 0.15, 0.15, 1.0)
const ARC_WIDTH     := 5.0
const ARC_POINTS    := 64

var free_color: Color = Color(0.2, 0.9, 0.3)
var circle_radius: float = 80.0
var blocked_arcs: Array = []  # Array de Vector2(start_deg, end_deg)
var mirror_flipped: bool = false
var thin_border: bool = false


func _draw() -> void:
	var width := 1.0 if thin_border else ARC_WIDTH
	if not mirror_flipped:
		draw_arc(Vector2.ZERO, circle_radius, 0.0, TAU, ARC_POINTS, free_color, width)
		for arc in blocked_arcs:
			_draw_arc_segment(arc.x, arc.y, BLOCKED_COLOR, width)
	else:
		draw_arc(Vector2.ZERO, circle_radius, 0.0, TAU, ARC_POINTS, BLOCKED_COLOR, width)
		for arc in blocked_arcs:
			_draw_arc_segment(arc.x, arc.y, free_color, width)


func _draw_arc_segment(start_deg: float, end_deg: float, color: Color, width: float) -> void:
	if start_deg <= end_deg:
		var pts := _arc_points(end_deg - start_deg)
		draw_arc(Vector2.ZERO, circle_radius,
				deg_to_rad(start_deg), deg_to_rad(end_deg), pts, color, width)
	else:
		var pts1 := _arc_points(360.0 - start_deg)
		var pts2 := _arc_points(end_deg)
		draw_arc(Vector2.ZERO, circle_radius,
				deg_to_rad(start_deg), TAU, pts1, color, width)
		draw_arc(Vector2.ZERO, circle_radius,
				0.0, deg_to_rad(end_deg), pts2, color, width)


func _arc_points(span_deg: float) -> int:
	return max(4, int(span_deg / 360.0 * ARC_POINTS))
