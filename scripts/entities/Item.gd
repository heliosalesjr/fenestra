extends Node2D

enum Type { COIN, LIFE, SHIELD }

signal collected(type: int)

@export var item_type: Type = Type.COIN

var _active: bool = true

const COLLECT_RADIUS := 20.0
const VISUAL_RADIUS  := 9.0

func _draw() -> void:
	var col: Color
	match item_type:
		Type.COIN:   col = Color(1.0,  0.82, 0.10)
		Type.LIFE:   col = Color(1.0,  0.22, 0.32)
		Type.SHIELD: col = Color(0.25, 0.60, 1.00)
		_:           col = Color.WHITE
	draw_circle(Vector2.ZERO, VISUAL_RADIUS, col)
	draw_arc(Vector2.ZERO, VISUAL_RADIUS, 0.0, TAU, 16, col.lightened(0.4), 1.5)


func collect() -> void:
	if not _active:
		return
	_active = false
	collected.emit(item_type)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale",       Vector2(1.6, 1.6), 0.15)
	tween.tween_property(self, "modulate:a",  0.0,               0.15)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
