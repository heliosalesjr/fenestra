extends Node2D

## Círculo translúcido desenhado por cima da sprite do player enquanto o escudo está ativo.
## Nó irmão posicionado depois do Sprite2D na árvore — garante que desenha na frente dele
## sem mexer no z_index global (que afetaria a ordem contra círculos/spikes na cena).

@export var radius: float = 50.0
@export var color: Color   = Color(1.0, 1.0, 1.0, 0.2)

var active: bool = false


func _draw() -> void:
	if active:
		draw_circle(Vector2.ZERO, radius, color)


func set_active(value: bool) -> void:
	active = value
	queue_redraw()
