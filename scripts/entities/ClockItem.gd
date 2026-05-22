extends Node2D

signal collected

var _active: bool  = true
var _bob_time: float = 0.0

const VISUAL_RADIUS := 11.0
const COLOR         := Color(1.0, 0.72, 0.15)


func _process(delta: float) -> void:
	if not _active:
		return
	_bob_time += delta * 2.5
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	var bob    := sin(_bob_time) * 4.0
	var center := Vector2(0.0, bob)
	var r      := VISUAL_RADIUS
	var col    := COLOR

	draw_circle(center, r, Color(col, 0.14))
	draw_arc(center, r, 0.0, TAU, 32, col, 2.0)

	for i in 4:
		var angle := i * (PI * 0.5) - PI * 0.5
		var dir   := Vector2(cos(angle), sin(angle))
		draw_line(center + dir * (r - 3.5), center + dir * r, Color(col, 0.7), 1.5, true)

	draw_line(center, center + Vector2(0.0, -r * 0.52), col, 2.2, true)
	draw_line(center, center + Vector2(r * 0.68, 0.0),  col, 1.6, true)
	draw_circle(center, 2.2, col)


func collect() -> void:
	if not _active:
		return
	_active = false
	collected.emit()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale",      Vector2(1.6, 1.6), 0.15)
	tween.tween_property(self, "modulate:a", 0.0,               0.15)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
