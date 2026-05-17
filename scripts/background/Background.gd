extends Node2D

const VIEWPORT_W   := 390.0
const VIEWPORT_H   := 844.0
const CLOUD_COUNT  := 8
const DRIFT_MIN    := 3.0    # px/s horizontal
const DRIFT_MAX    := 10.0
const TINT_SPEED   := 0.35   # lerp speed para a cor alvo

var _clouds: Array = []
var _tint: Color        = Color(0.2, 0.9, 0.3)
var _target_tint: Color = Color(0.2, 0.9, 0.3)


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

	for cloud in _clouds:
		cloud["pos"].x += float(cloud["speed"]) * delta
		var px: float = cloud["pos"].x
		if px > VIEWPORT_W + 90.0:
			cloud["pos"].x = -90.0
		elif px < -90.0:
			cloud["pos"].x = VIEWPORT_W + 90.0

	_tint = _tint.lerp(_target_tint, delta * TINT_SPEED)
	queue_redraw()


func _draw() -> void:
	var t    := Time.get_ticks_msec() * 0.001
	var base := _tint.darkened(0.62)

	for cloud in _clouds:
		var a: float     = cloud["alpha"]
		var bob: float   = sin(t * float(cloud["bob_speed"]) + float(cloud["bob_phase"])) * float(cloud["bob_amp"])
		var pos: Vector2 = cloud["pos"] + Vector2(0.0, bob)

		for blob in cloud["blobs"]:
			var bp: Vector2 = pos + Vector2(blob["off"])
			var r: float    = blob["r"]
			# glow externo suave
			draw_circle(bp, r * 1.45, Color(base.r, base.g, base.b, a * 0.4))
			# corpo principal
			draw_circle(bp, r, Color(base.r, base.g, base.b, a))
