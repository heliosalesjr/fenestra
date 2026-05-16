@tool
extends Node2D

## Desenhado como filho de RotationRoot.
## As coordenadas são locais ao RotationRoot, então giram automaticamente com ele.

const BLOCKED_COLOR  := Color(0.15, 0.15, 0.15, 1.0)
const ARC_WIDTH      := 5.0
const ARC_POINTS     := 64
const ELEC_INTERVAL  := 0.055  # segundos entre flickers da eletricidade

var free_color: Color    = Color(0.2, 0.9, 0.3)
var circle_radius: float = 80.0
var blocked_arcs: Array  = []  # Array de Vector2(start_deg, end_deg)
var mirror_flipped: bool  = false
var thin_border: bool     = false
var pulse_inactive: bool  = false  # true quando círculo pulse está na fase inativa

var _elec_timer: float = 0.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or thin_border:
		return
	if blocked_arcs.is_empty() and not pulse_inactive:
		return
	_elec_timer += delta
	if _elec_timer >= ELEC_INTERVAL:
		_elec_timer = 0.0
		queue_redraw()


func _draw() -> void:
	var width := 1.0 if thin_border else ARC_WIDTH

	if thin_border:
		# Checkpoint: círculo completo + arcos sólidos sobrepostos
		draw_arc(Vector2.ZERO, circle_radius, 0.0, TAU, ARC_POINTS, free_color, width)
		for arc in blocked_arcs:
			_draw_arc_segment(arc.x, arc.y, BLOCKED_COLOR, width)
		return

	if pulse_inactive:
		# Círculo inativo: eletricidade cobrindo o arco completo
		_draw_electricity(0.0, 360.0)
		return

	if mirror_flipped:
		# Mirror flipped: zonas seguras (blocked_arcs originais) em verde sólido,
		# zonas perigosas (complemento) em eletricidade
		for arc in blocked_arcs:
			_draw_arc_segment(arc.x, arc.y, free_color, ARC_WIDTH)
		for fa in _free_arcs():
			_draw_electricity(fa.x, fa.y)
		return

	# Normal: partes livres em arco sólido, partes bloqueadas em eletricidade
	for fa in _free_arcs():
		_draw_arc_segment(fa.x, fa.y, free_color, ARC_WIDTH)
	for arc in blocked_arcs:
		_draw_electricity(arc.x, arc.y)


# ─── Cálculo dos arcos livres (complemento dos blocked_arcs) ─────────────────

func _free_arcs() -> Array[Vector2]:
	if blocked_arcs.is_empty():
		return [Vector2(0.0, 360.0)]

	# Normaliza arcos com wrap-around em dois segmentos simples
	var segs: Array = []
	for arc in blocked_arcs:
		var s: float = arc.x
		var e: float = arc.y
		if s <= e:
			segs.append([s, e])
		else:
			segs.append([s, 360.0])
			segs.append([0.0, e])

	segs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])

	# Mescla intervalos sobrepostos
	var merged: Array = []
	for seg in segs:
		if merged.is_empty() or seg[0] > merged[-1][1]:
			merged.append([seg[0], seg[1]])
		else:
			merged[-1][1] = maxf(merged[-1][1], seg[1])

	# Complemento
	var free: Array[Vector2] = []
	var prev: float = 0.0
	for m in merged:
		if m[0] > prev + 0.1:
			free.append(Vector2(prev, m[0]))
		prev = m[1]
	if prev < 359.9:
		free.append(Vector2(prev, 360.0))
	return free


# ─── Eletricidade ─────────────────────────────────────────────────────────────

func _draw_electricity(start_deg: float, end_deg: float) -> void:
	if start_deg <= end_deg:
		_draw_elec_span(start_deg, end_deg)
	else:
		_draw_elec_span(start_deg, 360.0)
		_draw_elec_span(0.0, end_deg)


func _draw_elec_span(start_deg: float, end_deg: float) -> void:
	var span := end_deg - start_deg
	if span < 1.0:
		return
	var n: int = max(4, int(span / 4.5))
	var pts := PackedVector2Array()
	for i in range(n + 1):
		var t := float(i) / float(n)
		var angle_rad := deg_to_rad(start_deg + t * span)
		var r := circle_radius
		if i > 0 and i < n:
			r += randf_range(-7.0, 7.0)
		pts.append(Vector2(cos(angle_rad), sin(angle_rad)) * r)
	# Glow externo: vermelho-alaranjado (perigo)
	draw_polyline(pts, Color(0.9, 0.15, 0.05, 0.18), 11.0, true)
	# Glow médio: vermelho mais vivo
	draw_polyline(pts, Color(1.0, 0.25, 0.05, 0.40),  5.0, true)
	# Núcleo: branco quase puro (relâmpago real)
	draw_polyline(pts, Color(1.0, 0.92, 0.88, 0.95),  1.5, true)


# ─── Arco sólido ──────────────────────────────────────────────────────────────

func _draw_arc_segment(start_deg: float, end_deg: float, color: Color, width: float) -> void:
	if start_deg <= end_deg:
		draw_arc(Vector2.ZERO, circle_radius,
				deg_to_rad(start_deg), deg_to_rad(end_deg),
				_arc_points(end_deg - start_deg), color, width)
	else:
		draw_arc(Vector2.ZERO, circle_radius,
				deg_to_rad(start_deg), TAU,
				_arc_points(360.0 - start_deg), color, width)
		draw_arc(Vector2.ZERO, circle_radius,
				0.0, deg_to_rad(end_deg),
				_arc_points(end_deg), color, width)


func _arc_points(span_deg: float) -> int:
	return max(4, int(span_deg / 360.0 * ARC_POINTS))
