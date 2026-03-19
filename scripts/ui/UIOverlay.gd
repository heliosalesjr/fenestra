extends Control

# ─── Constantes de layout ────────────────────────────────────────────────────
const VIEWPORT_W   := 390.0
const VIEWPORT_H   := 844.0
const BAR_H        := 62.0
const ICON_Y       := 31.0   # centro vertical da barra

# Vidas (esquerda)
const LIFE_R       := 9.0
const LIFE_START_X := 20.0
const LIFE_SPACING := LIFE_R * 2.6
const LIFE_COLOR   := Color(1.0, 0.85, 0.2)

# Powerups (centro)
const ICON_R       := 10.5
const ICON_SPACING := 40.0
const SHIELD_COLOR := Color(0.35, 0.75, 1.0)
const COIN_COLOR   := Color(1.0, 0.82, 0.15)
const MAGNET_COLOR := Color(0.82, 0.28, 0.95)

# Pause (direita)
const PAUSE_X      := 362.0
const PAUSE_COLOR  := Color(1.0, 1.0, 1.0, 0.75)

# ─── Estado ──────────────────────────────────────────────────────────────────
const MAX_LIVES    := 3
var lives: int     = MAX_LIVES
var _game_over: bool = false


func _ready() -> void:
	$PauseBtn.pressed.connect(_on_pause_btn_pressed)


# ─── API pública ──────────────────────────────────────────────────────────────

func set_lives(n: int) -> void:
	lives = n
	queue_redraw()


func show_game_over() -> void:
	_game_over = true
	mouse_filter = MOUSE_FILTER_STOP
	$PauseBtn.visible = false
	queue_redraw()


# ─── Desenho ─────────────────────────────────────────────────────────────────
func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEWPORT_W, BAR_H), Color(0.0, 0.0, 0.0, 0.42))
	_draw_lives()
	_draw_powerups()
	_draw_pause()
	if _game_over:
		_draw_game_over()


func _draw_lives() -> void:
	for i in MAX_LIVES:
		var c := Vector2(LIFE_START_X + i * LIFE_SPACING, ICON_Y)
		if i < lives:
			draw_circle(c, LIFE_R, LIFE_COLOR)
		else:
			draw_arc(c, LIFE_R, 0.0, TAU, 32, Color(LIFE_COLOR, 0.28), 2.0)


func _draw_powerups() -> void:
	var cx := VIEWPORT_W * 0.5
	_draw_shield(Vector2(cx - ICON_SPACING, ICON_Y))
	_draw_coin(Vector2(cx, ICON_Y))
	_draw_magnet(Vector2(cx + ICON_SPACING, ICON_Y))


func _draw_shield(c: Vector2) -> void:
	var r := ICON_R
	var pts := PackedVector2Array([
		c + Vector2(0,       -r),
		c + Vector2( r*0.78, -r*0.35),
		c + Vector2( r*0.78,  r*0.28),
		c + Vector2(0,        r),
		c + Vector2(-r*0.78,  r*0.28),
		c + Vector2(-r*0.78, -r*0.35),
	])
	draw_colored_polygon(pts, Color(SHIELD_COLOR, 0.18))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(SHIELD_COLOR, 0.82), 1.5)


func _draw_coin(c: Vector2) -> void:
	draw_circle(c, ICON_R, Color(COIN_COLOR, 0.18))
	draw_arc(c, ICON_R, 0.0, TAU, 32, Color(COIN_COLOR, 0.88), 1.5)
	draw_circle(c, ICON_R * 0.5, Color(COIN_COLOR, 0.55))


func _draw_magnet(c: Vector2) -> void:
	var arm := ICON_R * 0.62
	var top := c.y - ICON_R * 0.48
	var bot := c.y + ICON_R * 0.28
	var col := Color(MAGNET_COLOR, 0.88)
	draw_line(Vector2(c.x - arm, top), Vector2(c.x - arm, bot), col, 2.5, true)
	draw_line(Vector2(c.x + arm, top), Vector2(c.x + arm, bot), col, 2.5, true)
	draw_arc(Vector2(c.x, bot), arm, 0.0, PI, 14, col, 2.5)
	draw_line(Vector2(c.x - arm,       top), Vector2(c.x - arm*0.22, top), Color(0.9, 0.2, 0.2, 0.9), 3.5, true)
	draw_line(Vector2(c.x + arm*0.22, top), Vector2(c.x + arm,       top), Color(0.3, 0.55, 1.0, 0.9), 3.5, true)


func _draw_pause() -> void:
	var bw  := 3.5
	var bh  := 13.0
	var gap := 5.0
	draw_line(Vector2(PAUSE_X - gap*0.5 - bw, ICON_Y - bh*0.5),
			  Vector2(PAUSE_X - gap*0.5 - bw, ICON_Y + bh*0.5), PAUSE_COLOR, bw, true)
	draw_line(Vector2(PAUSE_X + gap*0.5,       ICON_Y - bh*0.5),
			  Vector2(PAUSE_X + gap*0.5,       ICON_Y + bh*0.5), PAUSE_COLOR, bw, true)


func _draw_game_over() -> void:
	draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H), Color(0.0, 0.0, 0.05, 0.85))
	var font: Font = ThemeDB.fallback_font

	var title      := "GAME OVER"
	var title_size := 52
	var tw         := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	draw_string(font, Vector2((VIEWPORT_W - tw) * 0.5, VIEWPORT_H * 0.42),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(1.0, 0.85, 0.2, 1.0))

	var sub      := "toque para reiniciar"
	var sub_size := 22
	var sw       := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size).x
	draw_string(font, Vector2((VIEWPORT_W - sw) * 0.5, VIEWPORT_H * 0.54),
		sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, Color(1.0, 1.0, 1.0, 0.5))


# ─── Input ────────────────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if not _game_over:
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		get_tree().reload_current_scene()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			get_tree().reload_current_scene()


# ─── Pause ───────────────────────────────────────────────────────────────────
func _on_pause_btn_pressed() -> void:
	get_tree().paused = not get_tree().paused
