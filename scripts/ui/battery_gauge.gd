extends Control
class_name BatteryGauge
## ▼ 2026-06-28 신규: 손으로 그린 듯한 '배터리형' 색 에너지 게이지.
##   - 칸(SEGMENTS)으로 나뉘어 에너지 비율만큼 채워진다(배터리 잔량처럼).
##   - 채움 색 = 플레이어 색(검정/흰색). 내부 배경이 밝아 검정/흰색 둘 다 잘 보인다.
##   - 외곽선을 살짝 흔들리게(지터) 그려 '직접 그린' 느낌. 지터는 고정 시드라 깜빡이지 않는다.
##   사용: hud 가 set_state(ratio, is_white) 를 매 프레임 호출.

const SEGMENTS: int = 5
const BODY_W: float = 188.0
const BODY_H: float = 50.0
const OX: float = 7.0
const OY: float = 8.0

var ratio: float = 1.0
var is_white: bool = false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	custom_minimum_size = Vector2(BODY_W + OX * 2.0 + 12.0, BODY_H + OY * 2.0)

func set_state(r: float, white: bool) -> void:
	if absf(r - ratio) > 0.01 or white != is_white:
		ratio = clampf(r, 0.0, 1.0)
		is_white = white
		queue_redraw()

func _lit_count() -> int:
	return clampi(int(ceil(ratio * SEGMENTS)), 0, SEGMENTS)

func _j(amp: float) -> float:
	return _rng.randf_range(-amp, amp)

## 모서리를 살짝 흔든 사각형. filled=true 면 채우기, false 면 외곽선만.
func _jrect(r: Rect2, col: Color, filled: bool, width: float = 3.0) -> void:
	var a := 1.6
	var p := PackedVector2Array([
		r.position + Vector2(_j(a), _j(a)),
		r.position + Vector2(r.size.x, 0) + Vector2(_j(a), _j(a)),
		r.position + r.size + Vector2(_j(a), _j(a)),
		r.position + Vector2(0, r.size.y) + Vector2(_j(a), _j(a)),
	])
	if filled:
		draw_colored_polygon(p, col)
	else:
		var pl := p
		pl.append(p[0])
		draw_polyline(pl, col, width)

func _draw() -> void:
	_rng.seed = 7777                          # 고정 시드 → 매 redraw 동일한 지터(안 깜빡임)
	var ink := Color(0.07, 0.07, 0.10)

	# 내부 배경(밝게) — 검정 칸도 보이게
	_jrect(Rect2(OX, OY, BODY_W, BODY_H), Color(0.85, 0.85, 0.88, 0.92), true)

	# 칸 채우기/외곽선
	var lit := _lit_count()
	var pad := 6.0
	var seg_w := (BODY_W - pad * float(SEGMENTS + 1)) / float(SEGMENTS)
	var fill_col := Color(1, 1, 1) if is_white else Color(0.06, 0.06, 0.08)
	for i in SEGMENTS:
		var sx := OX + pad + float(i) * (seg_w + pad)
		var cell := Rect2(sx, OY + pad, seg_w, BODY_H - pad * 2.0)
		if i < lit:
			_jrect(cell, fill_col, true)
		_jrect(cell, ink, false, 2.0)

	# 배터리 외곽(손그림 두꺼운 선) + 오른쪽 단자
	_jrect(Rect2(OX, OY, BODY_W, BODY_H), ink, false, 4.0)
	draw_rect(Rect2(OX + BODY_W + 2.0, OY + BODY_H * 0.3, 8.0, BODY_H * 0.4), ink)
