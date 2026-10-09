extends Control
## ============================================================================
## [2026-10-09 Claude 신규] 퍼즐 조각 — 퍼즐 보드의 스테이지 한 칸
## ----------------------------------------------------------------------------
## ▣ 도형님(10-09): "스테이지를 클리어하면 퍼즐이 채워지고, 빈 곳을 클릭해서 하나씩 채우는 느낌 · 클리어한 조각은 빛이 은은하게 ·
##   숨은 스테이지는 클리어 시 도장 · 클리어 시간과 데스 카운트를 잉크로 적은 느낌 · 검정 사진 대신 인게임 한 장면".
## ▣ 상태
##   잠김   : 앞 스테이지를 아직 못 깸 — 아주 어두운 조각 + 점선 테두리(번호만).
##   빈칸   : 열렸지만 아직 안 깸 — 빈 종이 조각이 천천히 숨 쉰다(눌러서 들어간다).
##   클리어 : 그 스테이지에서 찍힌 사진이 조각 모양으로 채워지고 · 잉크 테두리 · 은은한 빛 · 잉크 글씨(시간·사망) · 도장.
## ▣ 모양: 조각 id 로 정해지는 퍼즐 모양(네 변마다 볼록/오목/평평) — 코드로 그린다(어떤 그림이 와도 모양이 일정하게).
## ▣ 그림 칸(있으면 그것을 쓴다 · 없으면 코드 그림) — assets/ui/로비/보드/
##   조각_빈칸.png(빈 종이 결 · 조각 안에 깔림) · 조각_잠김.png · 도장_클리어.png · 도장_숨은.png · 빛무리.png
##   글꼴: assets/ui/글꼴/손글씨.ttf (잉크 글씨) — 없으면 NotoSerifKR.
## ============================================================================

signal 눌림(조각: Control)

const 그림_폴더 := "res://assets/ui/로비/보드/"
const 기본_글꼴 := "res://assets/fonts/NotoSerifKR/NotoSerifKR.ttf"
const 손글씨_글꼴 := "res://assets/ui/글꼴/손글씨.ttf"

enum 상태 { 잠김, 빈칸, 클리어 }

var 정보: Dictionary = {}
var 지금: 상태 = 상태.잠김
var 사진: Texture2D = null
var 기록: Dictionary = {}
var 숨은: bool = false
## 채워지는 연출 진행(0 = 아직 · 1 = 다 채워짐). 보드가 트윈으로 올린다.
var 채움: float = 1.0
## 도장 찍힘 연출(0 → 1)
var 도장: float = 1.0

var _변 := PackedInt32Array([0, 0, 0, 0])     ## 위 · 오른 · 아래 · 왼 — 1 볼록 · −1 오목 · 0 평평
var _점 := PackedVector2Array()
var _t := 0.0
var _위에 := false
var _그림: Dictionary = {}
var _글꼴: Font
var _잉크: Font


func 준비(p_정보: Dictionary, p_상태: int, p_사진: Texture2D, p_기록: Dictionary) -> void:
	정보 = p_정보
	지금 = p_상태 as 상태
	사진 = p_사진
	기록 = p_기록
	숨은 = bool(정보.get("숨김", false))
	# 모양 — id 로 씨앗(늘 같은 모양)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(정보.get("id", "0"))) & 0x7fffffff
	for i in 4:
		_변[i] = [1, -1, 1, -1, 0][rng.randi_range(0, 4)]
	_점 = _모양(size)
	queue_redraw()


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	for k in ["조각_빈칸", "조각_잠김", "도장_클리어", "도장_숨은", "빛무리"]:
		var 경로: String = 그림_폴더 + k + ".png"
		_그림[k] = load(경로) if ResourceLoader.exists(경로) else null
	_글꼴 = load(기본_글꼴) if ResourceLoader.exists(기본_글꼴) else ThemeDB.fallback_font
	_잉크 = load(손글씨_글꼴) if ResourceLoader.exists(손글씨_글꼴) else _글꼴
	mouse_entered.connect(func(): _위에 = true; queue_redraw())
	mouse_exited.connect(func(): _위에 = false; queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	resized.connect(func(): _점 = _모양(size); queue_redraw())


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		눌림.emit(self)
		accept_event()
	elif e.is_action_pressed("ui_accept"):
		눌림.emit(self)
		accept_event()


func _process(delta: float) -> void:
	_t += delta
	if 지금 != 상태.잠김:
		queue_redraw()                 # 숨 쉬는 빈칸 · 은은한 빛(잠긴 조각은 멈춰 있다)


## 조각 모양 — 정사각형 네 변에 퍼즐 혹(볼록/오목). 화면 기준 시계방향 점들.
func _모양(크기: Vector2) -> PackedVector2Array:
	var S := minf(크기.x, 크기.y) * 0.72
	var c := 크기 * 0.5
	var 모서리 := [c + Vector2(-S, -S) * 0.5, c + Vector2(S, -S) * 0.5, c + Vector2(S, S) * 0.5, c + Vector2(-S, S) * 0.5]
	var out := PackedVector2Array()
	for i in 4:
		var a: Vector2 = 모서리[i]
		var b: Vector2 = 모서리[(i + 1) % 4]
		var 방향 := (b - a) / S
		var 바깥 := Vector2(방향.y, -방향.x)            # 시계방향이면 바깥 법선
		out.append(a)
		if _변[i] == 0:
			continue
		var d := float(_변[i])
		# 목(0.40~0.60) → 혹(반지름 0.13S 원) — 목은 살짝 좁게
		out.append(a + 방향 * S * 0.38)
		out.append(a + 방향 * S * 0.42 + 바깥 * d * S * 0.08)
		var 중심 := a + 방향 * S * 0.5 + 바깥 * d * S * 0.19
		var r := S * 0.13
		for k in range(0, 13):
			# 혹 원 둘레를 왼쪽 목(1.15π) → 바깥 끝(π/2) → 오른쪽 목(−0.15π) 으로 돈다. d 가 음수면 안쪽(오목)으로 뒤집힌다
			var 각 := lerpf(PI * 1.15, -PI * 0.15, float(k) / 12.0)
			out.append(중심 + 방향 * cos(각) * r + 바깥 * d * sin(각) * r)
		out.append(a + 방향 * S * 0.58 + 바깥 * d * S * 0.08)
		out.append(a + 방향 * S * 0.62)
	return out


func _draw() -> void:
	if _점.size() < 3:
		return
	var 강조 := _위에 or has_focus()
	var 숨 := 0.5 + 0.5 * sin(_t * 1.6 + float(hash(String(정보.get("id", "")))) * 0.001)
	var 테 := _점.duplicate()
	테.append(_점[0])
	match 지금:
		상태.잠김:
			draw_colored_polygon(_점, Color(0.05, 0.05, 0.055, 0.85))
			if _그림["조각_잠김"]:
				_결_채우기(_그림["조각_잠김"], Color(1, 1, 1, 0.35))
			draw_polyline(테, Color(0.45, 0.45, 0.45, 0.32), 1.5, true)     # 잠김 = 옅은 실선(점선은 숨은 길 실에만)
		상태.빈칸:
			draw_colored_polygon(_점, Color(0.11, 0.105, 0.10, 0.95))
			if _그림["조각_빈칸"]:
				_결_채우기(_그림["조각_빈칸"], Color(1, 1, 1, 0.8))
			var 밝 := 0.45 + 0.35 * 숨 + (0.2 if 강조 else 0.0)
			_잉크_테(테, Color(0.9, 0.88, 0.84, 밝), 2.0)
		상태.클리어:
			_빛무리(숨, 강조)
			if 사진 and 채움 > 0.0:
				_사진_채우기(채움)
			else:
				draw_colored_polygon(_점, Color(0.75, 0.74, 0.70, 0.9 * 채움))
			_잉크_테(테, Color(0.95, 0.94, 0.90, 0.9), 2.6 if 강조 else 2.0)
	# 번호(잠김 · 빈칸) — 조각 가운데
	if 지금 != 상태.클리어:
		var 번호 := String(정보.get("id", ""))
		var 글크기 := 30
		var w := _잉크.get_string_size(번호, HORIZONTAL_ALIGNMENT_CENTER, -1, 글크기).x
		var 색 := Color(0.5, 0.5, 0.5, 0.5) if 지금 == 상태.잠김 else Color(0.92, 0.9, 0.86, 0.85)
		draw_string(_잉크, size * 0.5 + Vector2(-w * 0.5, 글크기 * 0.35), 번호, HORIZONTAL_ALIGNMENT_LEFT, -1, 글크기, 색)
	else:
		_잉크_기록()
		if 도장 > 0.0:
			_도장_찍기()


## 조각 모양 그대로 사진을 채운다 — 사진(16:9)의 가운데를 조각 정사각형에 맞춰 자른다
func _사진_채우기(k: float) -> void:
	var c := size * 0.5
	var S := minf(size.x, size.y) * 0.72 * 1.3
	var 비 := float(사진.get_height()) / float(사진.get_width())
	var uv := PackedVector2Array()
	var 색 := PackedColorArray()
	for p in _점:
		var d := (p - c) / S
		uv.append(Vector2(0.5 + d.x * 비, 0.5 + d.y))
		색.append(Color(1, 1, 1, k))
	draw_polygon(_점, 색, uv, 사진)
	# 흑백 게임 — 사진 위에 아주 옅은 종이빛(바랜 사진 느낌)
	draw_colored_polygon(_점, Color(0.85, 0.82, 0.75, 0.08 * k))


func _결_채우기(t: Texture2D, 색: Color) -> void:
	var c := size * 0.5
	var S := minf(size.x, size.y)
	var uv := PackedVector2Array()
	var cs := PackedColorArray()
	for p in _점:
		uv.append(Vector2(0.5, 0.5) + (p - c) / S)
		cs.append(색)
	draw_polygon(_점, cs, uv, t)


## 잉크 테두리 — 두 번 살짝 어긋나게 그어 붓 느낌
func _잉크_테(선: PackedVector2Array, 색: Color, 굵기: float) -> void:
	draw_polyline(선, 색, 굵기, true)
	var 어긋 := PackedVector2Array()
	for i in 선.size():
		어긋.append(선[i] + Vector2(sin(i * 1.7) * 0.9, cos(i * 2.3) * 0.9))
	draw_polyline(어긋, Color(색.r, 색.g, 색.b, 색.a * 0.45), 굵기 * 0.6, true)


func _점선(선: PackedVector2Array, 색: Color, 굵기: float) -> void:
	for i in range(0, 선.size() - 1, 2):
		draw_line(선[i], 선[i + 1], 색, 굵기, true)


## 은은한 빛 — 클리어한 조각 둘레가 천천히 숨 쉬듯
func _빛무리(숨: float, 강조: bool) -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * (0.62 + 0.03 * 숨)
	var a := (0.10 + 0.08 * 숨 + (0.08 if 강조 else 0.0)) * 채움
	if _그림["빛무리"]:
		var t: Texture2D = _그림["빛무리"]
		draw_texture_rect(t, Rect2(c - Vector2(r, r) * 1.3, Vector2(r, r) * 2.6), false, Color(1, 1, 1, a * 3.0))
		return
	for i in 6:
		draw_circle(c, r * (1.0 - i * 0.12), Color(1.0, 0.97, 0.9, a * 0.35))


## 잉크 글씨 — 조각 아래에 시간 · 사망(살짝 기울여 손으로 적은 듯)
func _잉크_기록() -> void:
	if 기록.is_empty():
		return
	var 기록형 = load("res://scripts/ui/실행_기록.gd")
	var 줄1 := String(기록형.시간_문자(float(기록.get("초", 0.0))))
	var 줄2 := "사망 %d" % int(기록.get("사망", 0))
	# 조각의 가장 아랫점(아래 혹 포함) 밑에 적는다 — 혹과 글씨가 겹치지 않게
	var 아래 := 0.0
	for q in _점:
		아래 = maxf(아래, q.y)
	아래 += 20.0
	draw_set_transform(Vector2(size.x * 0.5, 아래), -0.05, Vector2.ONE)
	var 색 := Color(0.93, 0.91, 0.86, 0.9 * 채움)
	var w1 := _잉크.get_string_size(줄1, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(_잉크, Vector2(-w1 * 0.5, 0), 줄1, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 색)
	var w2 := _잉크.get_string_size(줄2, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(_잉크, Vector2(-w2 * 0.5 + 6, 20), 줄2, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(색.r, 색.g, 색.b, 색.a * 0.8))
	draw_set_transform(Vector2.ZERO)


## 도장 — 조각 오른쪽 아래에 비스듬히(찍히는 순간 크게 → 제자리)
func _도장_찍기() -> void:
	var c := size * 0.5 + Vector2(minf(size.x, size.y) * 0.28, minf(size.x, size.y) * 0.22)
	var 배 := lerpf(2.2, 1.0, ease(도장, 0.4))
	var 알 := clampf(도장 * 1.5, 0.0, 1.0)
	var 각 := -0.22 if not 숨은 else 0.18
	var t: Texture2D = _그림["도장_숨은"] if 숨은 else _그림["도장_클리어"]
	draw_set_transform(c, 각, Vector2(배, 배))
	if t:
		var s := Vector2(64, 64)
		draw_texture_rect(t, Rect2(-s * 0.5, s), false, Color(1, 1, 1, 0.9 * 알))
	else:
		var 잉크 := Color(0.86, 0.84, 0.80, 0.85 * 알)
		draw_arc(Vector2.ZERO, 26, 0, TAU, 32, 잉크, 2.5, true)
		draw_arc(Vector2.ZERO, 21, 0, TAU, 32, Color(잉크.r, 잉크.g, 잉크.b, 잉크.a * 0.7), 1.2, true)
		var 글 := "발견" if 숨은 else "통과"
		var w := _글꼴.get_string_size(글, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(_글꼴, Vector2(-w * 0.5, 5), 글, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 잉크)
	draw_set_transform(Vector2.ZERO)
