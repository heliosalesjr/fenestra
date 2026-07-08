extends Control

signal mode_selected(shuffled: bool)

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

# Escudo (centro) e contador de moedas
const ICON_R       := 10.5
const SHIELD_X     := VIEWPORT_W * 0.5
const COIN_X       := 278.0
const SHIELD_COLOR := Color(0.35, 0.75, 1.0)
const COIN_COLOR   := Color(1.0, 0.82, 0.15)

# Pause (direita)
const PAUSE_X      := 362.0
const PAUSE_COLOR  := Color(1.0, 1.0, 1.0, 0.75)

# Tela de escolha de modo (sequencial / embaralhado)
const MODE_BTN_W    := VIEWPORT_W - 80.0
const MODE_BTN_H    := 96.0
const MODE_BTN_GAP  := 26.0
const MODE_BTN_X    := 40.0
const MODE_SEQ_Y    := VIEWPORT_H * 0.40
const MODE_SHUF_Y   := MODE_SEQ_Y + MODE_BTN_H + MODE_BTN_GAP
const MODE_SEQ_COLOR  := Color(0.2,  0.9,  0.3)
const MODE_SHUF_COLOR := Color(0.82, 0.28, 0.95)

# ─── Estado ──────────────────────────────────────────────────────────────────
const MAX_LIVES    := 3
var lives: int     = MAX_LIVES
var _game_over: bool = false

var _clock_active:   bool  = false
var _clock_progress: float = 1.0
var _shield_active:  bool  = false
var score: int = 0
var _mode_select_active: bool = false


func _ready() -> void:
	$PauseBtn.pressed.connect(_on_pause_btn_pressed)


func _mode_seq_rect() -> Rect2:
	return Rect2(MODE_BTN_X, MODE_SEQ_Y, MODE_BTN_W, MODE_BTN_H)


func _mode_shuffle_rect() -> Rect2:
	return Rect2(MODE_BTN_X, MODE_SHUF_Y, MODE_BTN_W, MODE_BTN_H)


# ─── API pública ──────────────────────────────────────────────────────────────

func set_lives(n: int) -> void:
	lives = n
	queue_redraw()


func show_clock_bar() -> void:
	_clock_active   = true
	_clock_progress = 1.0
	queue_redraw()


func update_clock_bar(progress: float) -> void:
	_clock_progress = progress
	queue_redraw()


func hide_clock_bar() -> void:
	_clock_active = false
	queue_redraw()


func set_shield(active: bool) -> void:
	_shield_active = active
	queue_redraw()


func set_score(n: int) -> void:
	score = n
	queue_redraw()


func show_game_over() -> void:
	_game_over = true
	mouse_filter = MOUSE_FILTER_STOP
	$PauseBtn.visible = false
	queue_redraw()


## Mostra a tela inicial de escolha de modo e bloqueia o input do jogo até
## o player tocar em um dos dois botões (emite `mode_selected`).
func show_mode_select() -> void:
	_mode_select_active = true
	mouse_filter = MOUSE_FILTER_STOP
	$PauseBtn.visible = false
	queue_redraw()


func _finish_mode_select(shuffled: bool) -> void:
	_mode_select_active = false
	mouse_filter = MOUSE_FILTER_IGNORE
	$PauseBtn.visible = true
	queue_redraw()
	mode_selected.emit(shuffled)


# ─── Desenho ─────────────────────────────────────────────────────────────────
func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEWPORT_W, BAR_H), Color(0.0, 0.0, 0.0, 0.42))
	_draw_lives()
	_draw_shield(Vector2(SHIELD_X, ICON_Y))
	_draw_coin_counter(Vector2(COIN_X, ICON_Y))
	_draw_pause()
	if _clock_active:
		_draw_clock_bar()
	if _game_over:
		_draw_game_over()
	if _mode_select_active:
		_draw_mode_select()


func _draw_lives() -> void:
	for i in MAX_LIVES:
		var c := Vector2(LIFE_START_X + i * LIFE_SPACING, ICON_Y)
		if i < lives:
			draw_circle(c, LIFE_R, LIFE_COLOR)
		else:
			draw_arc(c, LIFE_R, 0.0, TAU, 32, Color(LIFE_COLOR, 0.28), 2.0)


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
	if _shield_active:
		draw_arc(c, r + 3.5, 0.0, TAU, 20, Color(SHIELD_COLOR, 0.30), 3.0)
		draw_colored_polygon(pts, Color(SHIELD_COLOR, 0.85))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1.0, 1.0, 1.0, 0.95), 2.0)
	else:
		draw_colored_polygon(pts, Color(SHIELD_COLOR, 0.18))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(SHIELD_COLOR, 0.82), 1.5)


func _draw_coin_counter(c: Vector2) -> void:
	draw_circle(c, ICON_R, Color(COIN_COLOR, 0.22))
	draw_arc(c, ICON_R, 0.0, TAU, 32, Color(COIN_COLOR, 0.9), 1.5)
	draw_circle(c, ICON_R * 0.5, Color(COIN_COLOR, 0.6))

	var font: Font = ThemeDB.fallback_font
	var font_size := 20
	var text := "x%d" % score
	draw_string(font, c + Vector2(ICON_R + 6.0, font_size * 0.35),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 1.0, 1.0, 0.92))


func _draw_clock_bar() -> void:
	const BAR_Y  := BAR_H
	const BAR_HT := 8.0

	draw_rect(Rect2(0.0, BAR_Y, VIEWPORT_W, BAR_HT), Color(0.0, 0.0, 0.0, 0.5))

	var col: Color
	if _clock_progress > 0.5:
		col = Color(0.2, 0.9, 0.3)
	elif _clock_progress > 0.25:
		col = Color(1.0, 0.85, 0.1)
	else:
		col = Color(1.0, 0.22, 0.22)
		if _clock_progress < 0.15:
			col.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)

	draw_rect(Rect2(0.0, BAR_Y, VIEWPORT_W * _clock_progress, BAR_HT), col)


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

	var sub      := "tap to restart"
	var sub_size := 22
	var sw       := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size).x
	draw_string(font, Vector2((VIEWPORT_W - sw) * 0.5, VIEWPORT_H * 0.54),
		sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, Color(1.0, 1.0, 1.0, 0.5))


func _draw_mode_select() -> void:
	draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H), Color(0.0, 0.0, 0.05, 0.94))
	var font: Font = ThemeDB.fallback_font

	var title      := "ESCOLHA O MODO"
	var title_size := 30
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	draw_string(font, Vector2((VIEWPORT_W - tw) * 0.5, MODE_SEQ_Y - 50.0),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(1.0, 1.0, 1.0, 0.9))

	_draw_mode_button(_mode_seq_rect(), MODE_SEQ_COLOR,
		"SEQUENCIAL", "os 15 níveis na ordem original")
	_draw_mode_button(_mode_shuffle_rect(), MODE_SHUF_COLOR,
		"EMBARALHADO", "os 15 níveis em ordem sorteada")


func _draw_mode_button(rect: Rect2, color: Color, label: String, subtitle: String) -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(rect, Color(color, 0.16))
	draw_rect(rect, Color(color, 0.9), false, 2.0)

	var label_size := 24
	draw_string(font, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.44),
		label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, label_size, Color.WHITE)

	var sub_size := 13
	draw_string(font, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.72),
		subtitle, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, sub_size, Color(1.0, 1.0, 1.0, 0.6))


# ─── Input ────────────────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	var pos: Vector2
	var pressed: bool
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		pos     = t.position
		pressed = t.pressed
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		pos     = mb.position
		pressed = mb.pressed
	else:
		return

	if not pressed:
		return

	if _mode_select_active:
		if _mode_seq_rect().has_point(pos):
			_finish_mode_select(false)
			get_viewport().set_input_as_handled()
		elif _mode_shuffle_rect().has_point(pos):
			_finish_mode_select(true)
			get_viewport().set_input_as_handled()
	elif _game_over:
		get_tree().reload_current_scene()
		get_viewport().set_input_as_handled()


# ─── Pause ───────────────────────────────────────────────────────────────────
func _on_pause_btn_pressed() -> void:
	get_tree().paused = not get_tree().paused
