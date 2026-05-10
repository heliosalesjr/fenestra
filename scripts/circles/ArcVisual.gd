@tool
extends Node2D

## Desenhado como filho de RotationRoot.
## As coordenadas são locais ao RotationRoot, então giram automaticamente com ele.

const FREE_COLOR    := Color(0.2, 0.9, 0.3)
const BLOCKED_COLOR := Color(0.15, 0.15, 0.15, 1.0)

## Tamanho de cada "pixel" em screen pixels. Aumente para mais chunky.
const PIXEL_SIZE := 4.0

var circle_radius: float = 80.0
var blocked_arcs: Array = []  # Array de Vector2(start_deg, end_deg)
var mirror_flipped: bool = false


func _draw() -> void:
	var r_px: int = int(round(circle_radius / PIXEL_SIZE))
	var pixels := _midpoint_circle(r_px)
	var half := PIXEL_SIZE * 0.5
	for px in pixels:
		var world := Vector2(px.x, px.y) * PIXEL_SIZE
		var angle := fmod(rad_to_deg(atan2(world.y, world.x)) + 360.0, 360.0)
		var in_blocked := _in_blocked_arc(angle)
		var color: Color
		if not mirror_flipped:
			color = BLOCKED_COLOR if in_blocked else FREE_COLOR
		else:
			color = FREE_COLOR if in_blocked else BLOCKED_COLOR
		draw_rect(Rect2(world - Vector2(half, half), Vector2(PIXEL_SIZE, PIXEL_SIZE)), color)


func _midpoint_circle(r: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var seen := {}
	var x := r
	var y := 0
	var p := 1 - r
	while x >= y:
		_add_octant(result, seen, x, y)
		y += 1
		if p <= 0:
			p += 2 * y + 1
		else:
			x -= 1
			p += 2 * (y - x) + 1
	return result


func _add_octant(result: Array[Vector2i], seen: Dictionary, x: int, y: int) -> void:
	var candidates: Array[Vector2i] = [
		Vector2i(x, y),  Vector2i(-x, y),  Vector2i(x, -y),  Vector2i(-x, -y),
		Vector2i(y, x),  Vector2i(-y, x),  Vector2i(y, -x),  Vector2i(-y, -x),
	]
	for pt in candidates:
		if not seen.has(pt):
			seen[pt] = true
			result.append(pt)


func _in_blocked_arc(angle: float) -> bool:
	for arc in blocked_arcs:
		if _angle_in_arc(angle, arc.x, arc.y):
			return true
	return false


func _angle_in_arc(angle: float, start: float, end: float) -> bool:
	if start <= end:
		return angle >= start and angle <= end
	else:
		return angle >= start or angle <= end
