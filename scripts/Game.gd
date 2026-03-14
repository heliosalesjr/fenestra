extends Node2D

@export var circle_sequence: Array[NodePath] = []

@onready var player: Node2D = $Player

var circles: Array[Node2D] = []
var current_index: int = 0
var last_checkpoint_index: int = 0

const RESPAWN_DELAY := 1.0


func _ready() -> void:
	for path in circle_sequence:
		circles.append(get_node(path))

	player.player_died.connect(_on_player_died)
	player.landed_on.connect(_on_player_landed)

	if circles.size() > 0:
		player.attach_to_circle(circles[0])

	queue_redraw()


func _draw() -> void:
	for i in range(circles.size() - 1):
		draw_line(
			circles[i].position,
			circles[i + 1].position,
			Color(0.65, 0.65, 0.65, 0.35),
			1.5
		)


func _unhandled_input(event: InputEvent) -> void:
	if player.state != player.State.ON_CIRCLE:
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_jump_to_next()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_jump_to_next()


func _jump_to_next() -> void:
	if circles.size() < 2:
		return
	var next_idx := (current_index + 1) % circles.size()
	player.move_to(circles[next_idx])


func _on_player_landed(circle: Node2D) -> void:
	current_index = circles.find(circle)
	circle.clear_orbiters()
	if circle.get("bg_number") > 0:
		last_checkpoint_index = current_index


func _on_player_died(reason: String) -> void:
	print_rich("[color=red]Morte:[/color] ", reason)
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	current_index = last_checkpoint_index
	player.respawn(circles[last_checkpoint_index])
