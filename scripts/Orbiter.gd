extends Node2D

@export var orbit_radius: float = 90.0
@export var orbit_speed: float  = 80.0    # graus/s  (positivo = horário)
@export var sphere_radius: float = 7.0
@export var sphere_color: Color  = Color(0.95, 0.35, 0.35)
@export var start_angle: float   = 0.0    # graus

var _angle_deg: float = 0.0


func _ready() -> void:
	_angle_deg = start_angle


func _process(delta: float) -> void:
	_angle_deg += orbit_speed * delta
	position = Vector2.RIGHT.rotated(deg_to_rad(_angle_deg)) * orbit_radius


func _draw() -> void:
	draw_circle(Vector2.ZERO, sphere_radius, sphere_color)


func fade_and_free() -> void:
	set_process(false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
