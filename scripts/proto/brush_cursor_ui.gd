extends Control
## [2026-07-14 도형 · 신규] 붓 커서 + 횟수 표시 UI — 게이지 UI(paint_gauge_ui.gd) 대체.
## 사양 (2026-07-14 도형 확정):
##  - 마우스 커서 = 붓 아이콘 (색칠 게임 정체성). assets/textures/ui/brush_cursor.svg
##  - 붓을 "칠 가능(무색) 발판"에 올리면 붓 옆에 작은 숫자 = 그 발판을 현재 색으로
##    바꾸는 데 필요한 남은 발사 횟수 (x2 처럼 표시).
##  - 이미 칠해진 반대색 발판 위에서는 ⚠ (쏘면 회색이 된다는 경고), 회색 위에서는 ✕.
##  - 탄착 순간 해당 발판 위에 남은 횟수/결과가 잠깐 떠올랐다 사라짐 (팝업).
##  - "다음에 회수(E)될 발판" 위에 작은 E 마커 표시 (FIFO 순서를 눈으로 확인).
##  - show_message(): 화면 중앙 상단 안내문 (zone_02 전환 잠김 피드백 등).
class_name BrushCursorUI

const BRUSH_CURSOR_PATH := "res://assets/textures/ui/brush_cursor.svg"
const POPUP_LIFETIME: float = 0.9    # 탄착 팝업 표시 시간(초)
const MESSAGE_LIFETIME: float = 1.4  # 중앙 메시지 표시 시간(초)

var _paint_system: PaintSystem
var _terrain: TileMapLayer
var _player: Node

## 탄착 팝업 목록. 원소 = { "cell": Vector2i, "text": String, "color": Color, "age": float }
var _popups: Array[Dictionary] = []
var _message: String = ""
var _message_age: float = 0.0

func setup(ps: PaintSystem, terrain: TileMapLayer, player: Node) -> void:
	_paint_system = ps
	_terrain      = terrain
	_player       = player
	ps.hit_feedback.connect(_on_hit_feedback)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# OS 커서를 붓으로 교체. 핫스팟 = 붓끝(좌하단) — 조준점이 붓끝이 되도록.
	var brush := load(BRUSH_CURSOR_PATH)
	if brush:
		Input.set_custom_mouse_cursor(brush, Input.CURSOR_ARROW, Vector2(3, 25))

func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)   # 씬을 떠나면 기본 커서 복원

func _process(delta: float) -> void:
	for p in _popups:
		p["age"] += delta
	_popups = _popups.filter(func(p: Dictionary) -> bool: return p["age"] < POPUP_LIFETIME)
	if _message != "":
		_message_age += delta
		if _message_age >= MESSAGE_LIFETIME:
			_message = ""
	queue_redraw()   # 붓 위치·호버 상태를 매 프레임 갱신 (프로토라 비용 무시)

## zone_02 전환 잠김 등 안내문 표시용 (외부 호출 API)
func show_message(text: String) -> void:
	_message = text
	_message_age = 0.0

func _on_hit_feedback(cell: Vector2i, result: String, remaining: int) -> void:
	var text := ""
	var col := Color(1, 1, 1)
	match result:
		"progress":   text = "x%d" % remaining;  col = Color(1.0, 0.9, 0.3)   # 남은 횟수
		"painted":    text = "칠해짐!";           col = Color(0.4, 1.0, 0.5)
		"wasted":     text = "이미 같은 색";       col = Color(0.8, 0.8, 0.8)
		"mixed_gray": text = "회색! 복구 불가";    col = Color(1.0, 0.35, 0.3)
		"blocked":    text = "✕";                col = Color(0.6, 0.6, 0.6)
		"recovered":  text = "회수됨";            col = Color(0.5, 0.8, 1.0)
	_popups.append({ "cell": cell, "text": text, "color": col, "age": 0.0 })

## 셀(타일) 좌표 → 화면 좌표 (카메라·줌이 있어도 정확하도록 캔버스 변환 사용)
func _cell_to_screen(cell: Vector2i) -> Vector2:
	return _terrain.get_global_transform_with_canvas() * _terrain.map_to_local(cell)

func _draw() -> void:
	if _paint_system == null or _terrain == null or _player == null:
		return
	var font := ThemeDB.fallback_font
	var mouse := get_viewport().get_mouse_position()

	# ── 1. 호버 중인 발판의 필요 횟수 (붓 옆 작은 숫자) ─────────────────
	var cell := _terrain.local_to_map(_terrain.get_local_mouse_position())
	if _terrain.get_cell_source_id(cell) != -1:
		var color: int = _player.get("player_color")
		var atlas := _terrain.get_cell_atlas_coords(cell)
		var tag := ""
		var tag_col := Color(1, 1, 1)
		var remaining := _paint_system.remaining_hits(_terrain, cell, color)
		if remaining > 0:
			tag = "x%d" % remaining                       # 몇 발 쏘면 바뀌는지
			tag_col = Color(1.0, 0.9, 0.3)
		elif atlas == PaintSystem.ATLAS_GRAY:
			tag = "✕"                                     # 죽은 지형
			tag_col = Color(0.65, 0.65, 0.65)
		elif atlas == PaintSystem.ATLAS_BLACK or atlas == PaintSystem.ATLAS_WHITE:
			var mine := (atlas == PaintSystem.ATLAS_BLACK and color == ColorDefs.BLACK) \
				or (atlas == PaintSystem.ATLAS_WHITE and color == ColorDefs.WHITE)
			if not mine:
				tag = "⚠회색됨"                            # 반대색: 쏘면 회색 경고
				tag_col = Color(1.0, 0.45, 0.3)
		if tag != "":
			_draw_outlined_text(font, mouse + Vector2(16, -10), tag, 16, tag_col)

	# ── 2. 다음 회수(E) 대상 마커 — FIFO 맨 앞 발판 위에 E 표시 ─────────
	var next = _paint_system.next_recover_cell()
	if next != null:
		var sp := _cell_to_screen(next) + Vector2(0, -26)
		draw_circle(sp, 10.0, Color(0.5, 0.8, 1.0, 0.85))
		_draw_outlined_text(font, sp + Vector2(-5, 5), "E", 14, Color(0.05, 0.05, 0.05))

	# ── 3. 탄착 팝업 (발판 위에서 떠오르며 사라짐) ──────────────────────
	for p in _popups:
		var t: float = p["age"] / POPUP_LIFETIME
		var pos := _cell_to_screen(p["cell"]) + Vector2(0, -20.0 - 18.0 * t)
		var c: Color = p["color"]
		c.a = 1.0 - t
		var ts := font.get_string_size(p["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, 15)
		_draw_outlined_text(font, pos + Vector2(-ts.x * 0.5, 0), p["text"], 15, c)

	# ── 4. 중앙 상단 메시지 (전환 잠김 등) ──────────────────────────────
	if _message != "":
		var a: float = clampf(1.0 - _message_age / MESSAGE_LIFETIME, 0.0, 1.0)
		var msize := font.get_string_size(_message, HORIZONTAL_ALIGNMENT_CENTER, -1, 22)
		var mpos := Vector2((size.x - msize.x) * 0.5, 70.0)
		draw_rect(Rect2(mpos + Vector2(-14, -24), msize + Vector2(28, 34)),
			Color(0.0, 0.0, 0.0, 0.55 * a), true)
		_draw_outlined_text(font, mpos, _message, 22, Color(1.0, 0.85, 0.3, a))

## 어두운/밝은 배경 어디서든 읽히도록 외곽선 있는 글자 그리기
func _draw_outlined_text(font: Font, pos: Vector2, text: String, size_px: int, col: Color) -> void:
	var outline := Color(0.05, 0.05, 0.05, col.a)
	for off in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_string(font, pos + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, outline)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)
