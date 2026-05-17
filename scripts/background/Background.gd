extends Node2D

const VIEWPORT_W  := 390.0
const VIEWPORT_H  := 844.0
const CLOUD_COUNT := 14
const DRIFT_MIN   := 3.0
const DRIFT_MAX   := 10.0
const TINT_SPEED  := 0.35

# Lua — estados
enum MoonState { HIDDEN, FADE_IN, VISIBLE, FADE_OUT }

const MOON_RADIUS     := 38.0
const MOON_FADE_DUR   := 2.5   # segundos para entrar/sair
const MOON_VISIBLE_MIN := 8.0  # segundos visível
const MOON_VISIBLE_MAX := 16.0
const MOON_HIDDEN_MIN  := 12.0  # segundos escondida antes de voltar
const MOON_HIDDEN_MAX  := 25.0

var _clouds: Array = []
var _tint: Color        = Color(0.2, 0.9, 0.3)
var _target_tint: Color = Color(0.2, 0.9, 0.3)

var _moon_state: MoonState = MoonState.HIDDEN
var _moon_timer: float     = 0.0
var _moon_duration: float  = 0.0
var _moon_alpha: float     = 0.0
var _moon_pos: Vector2     = Vector2.ZERO


func _ready() -> void:
	randomize()
	for i in CLOUD_COUNT:
		_clouds.append({
			"pos":       Vector2(randf() * VIEWPORT_W, randf() * VIEWPORT_H),
			"speed":     randf_range(DRIFT_MIN, DRIFT_MAX) * (1.0 if randf() > 0.5 else -1.0),
			"bob_phase": randf() * TAU,
			"bob_amp":   randf_range(5.0, 14.0),
			"bob_speed": randf_range(0.25, 0.6),
			"blobs":     _gen_blobs(),
			"alpha":     randf_range(0.13, 0.24),
		})
	# Começa escondida, aguarda um tempo antes de aparecer
	_moon_timer    = randf_range(MOON_HIDDEN_MIN, MOON_HIDDEN_MAX)
	_moon_duration = _moon_timer


func _gen_blobs() -> Array[Dictionary]:
	var blobs: Array[Dictionary] = []
	var n := randi_range(3, 6)
	for i in n:
		blobs.append({
			"off": Vector2(randf_range(-55.0, 55.0), randf_range(-20.0, 20.0)),
			"r":   randf_range(22.0, 58.0),
		})
	return blobs


func set_tint(color: Color) -> void:
	_target_tint = color


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001

	# Drift das nuvens
	for cloud in _clouds:
		cloud["pos"].x += float(cloud["speed"]) * delta
		var px: float = cloud["pos"].x
		if px > VIEWPORT_W + 90.0:
			cloud["pos"].x = -90.0
		elif px < -90.0:
			cloud["pos"].x = VIEWPORT_W + 90.0

	# Tint
	_tint = _tint.lerp(_target_tint, delta * TINT_SPEED)

	# Máquina de estado da lua
	_moon_timer -= delta
	match _moon_state:
		MoonState.HIDDEN:
			if _moon_timer <= 0.0:
				_moon_state    = MoonState.FADE_IN
				_moon_timer    = MOON_FADE_DUR
				_moon_duration = MOON_FADE_DUR
				_moon_pos      = Vector2(randf_range(60.0, VIEWPORT_W - 60.0),
										randf_range(80.0, 260.0))
		MoonState.FADE_IN:
			_moon_alpha = 1.0 - clampf(_moon_timer / MOON_FADE_DUR, 0.0, 1.0)
			if _moon_timer <= 0.0:
				_moon_state    = MoonState.VISIBLE
				_moon_timer    = randf_range(MOON_VISIBLE_MIN, MOON_VISIBLE_MAX)
				_moon_duration = _moon_timer
				_moon_alpha    = 1.0
		MoonState.VISIBLE:
			_moon_alpha = 1.0
			if _moon_timer <= 0.0:
				_moon_state    = MoonState.FADE_OUT
				_moon_timer    = MOON_FADE_DUR
				_moon_duration = MOON_FADE_DUR
		MoonState.FADE_OUT:
			_moon_alpha = clampf(_moon_timer / MOON_FADE_DUR, 0.0, 1.0)
			if _moon_timer <= 0.0:
				_moon_state    = MoonState.HIDDEN
				_moon_timer    = randf_range(MOON_HIDDEN_MIN, MOON_HIDDEN_MAX)
				_moon_duration = _moon_timer
				_moon_alpha    = 0.0

	queue_redraw()


func _draw() -> void:
	var base := _tint.darkened(0.62)

	# Nuvens
	for cloud in _clouds:
		var a: float     = cloud["alpha"]
		var t := Time.get_ticks_msec() * 0.001
		var bob: float   = sin(t * float(cloud["bob_speed"]) + float(cloud["bob_phase"])) * float(cloud["bob_amp"])
		var pos: Vector2 = cloud["pos"] + Vector2(0.0, bob)
		for blob in cloud["blobs"]:
			var bp: Vector2 = pos + Vector2(blob["off"])
			var r: float    = blob["r"]
			draw_circle(bp, r * 1.45, Color(base.r, base.g, base.b, a * 0.4))
			draw_circle(bp, r,        Color(base.r, base.g, base.b, a))

	# Lua
	if _moon_alpha > 0.001:
		var a := _moon_alpha
		var r := MOON_RADIUS
		var p := _moon_pos
		# Halos externos
		draw_circle(p, r * 2.6, Color(1.0, 0.97, 0.85, 0.04 * a))
		draw_circle(p, r * 1.8, Color(1.0, 0.97, 0.85, 0.10 * a))
		draw_circle(p, r * 1.3, Color(1.0, 0.97, 0.85, 0.18 * a))
		# Corpo
		draw_circle(p, r,       Color(1.0, 0.97, 0.85, 0.82 * a))
		# Brilho central
		draw_circle(p, r * 0.55, Color(1.0, 1.0,  0.96, 0.35 * a))
