extends Control
## [2026-07-13 도형 · 신규] 물감 게이지 UI — 화면 상단, 벡터 드로잉(도트 아님).
## 사양 (2026-07-13 도형 확정):
##  - 흑/백 게이지는 따로 존재하지만, 화면에는 "현재 플레이어 색"의 게이지만 표시.
##    색 반전(Shift) 순간 UI가 반대 색 게이지로 교체된다.
##  - 칸은 1칸씩 분리 배치, 각 칸에 순서대로 번호(1~) 표시.
##  - 빈 칸 = 격자(그리드) 무늬. 회색 페널티로 파괴된 칸은 아예 그려지지 않음(최대치 감소).
class_name PaintGaugeUI

const SLOT_SIZE := Vector2(44, 44)
const SLOT_GAP: float = 10.0
const TOP_MARGIN: float = 14.0

var _paint_system: PaintSystem
var _player: Node
var _denied_flash: float = 0.0   # 발사 거부 시 잠깐 붉은 테두리

func setup(ps: PaintSystem, player: Node) -> void:
	_paint_system = ps
	_player       = player
	ps.gauge_changed.connect(queue_redraw)
	ps.fire_denied.connect(func(_c: int) -> void: _denied_flash = 0.35)

func _process(delta: float) -> void:
	if _denied_flash > 0.0:
		_denied_flash -= delta
		queue_redraw()
	queue_redraw()   # 색 전환(Shift)을 즉시 반영하기 위해 매 프레임 갱신 (프로토라 비용 무시)

func _draw() -> void:
	if _paint_system == null or _player == null:
		return
	var color: int = _player.get("player_color")
	var slots: Array[bool] = _paint_system.slots_of(color)
	var n := slots.size()
	if n <= 0:
		return

	var total_w := n * SLOT_SIZE.x + (n - 1) * SLOT_GAP
	var x0 := (size.x - total_w) * 0.5
	var font := ThemeDB.fallback_font

	var fill_col   := Color(0.08, 0.08, 0.08) if color == ColorDefs.BLACK else Color(0.96, 0.96, 0.96)
	var border_col := Color(0.85, 0.85, 0.85) if color == ColorDefs.BLACK else Color(0.15, 0.15, 0.15)
	if _denied_flash > 0.0:
		border_col = Color(0.9, 0.2, 0.2)

	for i in n:
		var rect := Rect2(Vector2(x0 + i * (SLOT_SIZE.x + SLOT_GAP), TOP_MARGIN), SLOT_SIZE)
		# 칸 바탕
		draw_rect(rect, Color(0.5, 0.5, 0.5, 0.25), true)
		if slots[i]:
			draw_rect(rect.grow(-3.0), fill_col, true)          # 차 있는 칸 = 현재 색
		else:
			_draw_grid(rect.grow(-3.0))                          # 빈 칸 = 격자 무늬
		draw_rect(rect, border_col, false, 2.0)
		# 칸 번호 (1~) — 칸 아래 중앙
		var num := str(i + 1)
		var ts := font.get_string_size(num, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
		draw_string(font, rect.position + Vector2((SLOT_SIZE.x - ts.x) * 0.5, SLOT_SIZE.y + 16.0),
			num, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.75, 0.75))

	# 현재 색 라벨 (게이지 왼쪽의 작은 원)
	var icon_c := Vector2(x0 - 26.0, TOP_MARGIN + SLOT_SIZE.y * 0.5)
	draw_circle(icon_c, 10.0, fill_col)
	draw_arc(icon_c, 10.0, 0.0, TAU, 24, border_col, 2.0)

## 빈 칸의 격자 무늬 (8px 간격 세로/가로줄)
func _draw_grid(r: Rect2) -> void:
	var c := Color(0.6, 0.6, 0.6, 0.55)
	var x := r.position.x + 8.0
	while x < r.end.x:
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), c, 1.0)
		x += 8.0
	var y := r.position.y + 8.0
	while y < r.end.y:
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), c, 1.0)
		y += 8.0
