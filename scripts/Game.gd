extends Node2D

@export var circle_sequence: Array[NodePath] = []

@onready var player: Node2D = $Player

var circles: Array[Node2D] = []
var current_index: int = 0

const RESPAWN_DELAY := 1.2


func _ready() -> void:
	for path in circle_sequence:
		circles.append(get_node(path))

	player.player_died.connect(_on_player_died)
	player.landed_on.connect(_on_player_landed)

	if circles.size() > 0:
		player.attach_to_circle(circles[0])
		# Orienta a seta do primeiro círculo em direção ao segundo para início intuitivo
		_point_circle_toward_next(0)


func _unhandled_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)

	if tapped and player.state == player.State.ON_CIRCLE:
		_jump_to_next()


func _jump_to_next() -> void:
	if circles.size() < 2:
		return
	var next_idx := (current_index + 1) % circles.size()
	player.jump_to(circles[next_idx])


func _on_player_landed(circle: Node2D) -> void:
	current_index = circles.find(circle)


func _on_player_died(reason: String) -> void:
	print_rich("[color=red]Morte:[/color] ", reason)
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	current_index = 0
	player.respawn(circles[0])


# Aponta o RotationRoot do círculo idx na direção do próximo círculo.
# Chamado só na inicialização para dar um ponto de partida intuitivo.
func _point_circle_toward_next(idx: int) -> void:
	if circles.size() < 2:
		return
	var next_idx := (idx + 1) % circles.size()
	var dir := (circles[next_idx].global_position - circles[idx].global_position).normalized()
	var rot_root := circles[idx].get_node("RotationRoot") as Node2D
	rot_root.rotation = dir.angle()
