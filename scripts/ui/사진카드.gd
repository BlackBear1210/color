extends Control
## 퍼즐 돌기 대신 실제 플레이 사진을 붙인다. 테두리 원화와 사진·기록을 분리해 새 스테이지도 같은 카드를 쓴다.
signal 눌림(카드: Control)
var 정보: Dictionary = {}
var 지금: int = 0
var 사진: Texture2D
var 기록: Dictionary = {}
var 채움: float = 1.0:
	set(v): 채움 = v; queue_redraw()
var 도장: float = 1.0:
	set(v): 도장 = v; queue_redraw()
## [2026-10-10 Claude] 열쇠 스테이지 표시(도형님 10-10) — 보드표.열쇠_진행() 결과. 빈 사전 = 열쇠 스테이지 아님.
##   {"왼쪽": 검정 조각 주움, "오른쪽": 흰 조각 주움, "열림": 문을 열었나, "주인": 다른 스테이지 문 열쇠면 그 씬}
var 열쇠: Dictionary = {}:
	set(v): 열쇠 = v; queue_redraw()
const 열쇠_폴더 := "res://assets/textures/props/신규기믹_v02/게임용/열쇠/"
static var _열쇠그림: Dictionary = {}      ## 카드끼리 같이 쓴다(실루엣 · 반쪽 HUD · 완성 원화)
var _틀: Texture2D
var _글꼴: Font
var _시각 := 0.0

func _ready() -> void:
	_틀 = load("res://assets/ui/로비/조각/사진_틀_v02.png")
	_글꼴 = load("res://assets/fonts/NotoSerifKR/NotoSerifKR.ttf")
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)

func 준비(c: Dictionary, 상태값: int, 이미지: Texture2D, r: Dictionary) -> void:
	정보 = c
	지금 = 상태값
	사진 = 이미지
	기록 = r
	tooltip_text = String(c.get("이름", ""))
	queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed) or e.is_action_pressed("ui_accept"):
		눌림.emit(self)
		accept_event()

func _process(delta: float) -> void:
	if 지금 != 0:
		_시각 += delta
		queue_redraw()

func _draw() -> void:
	if _글꼴 == null:
		return
	var 앞면 := Rect2(Vector2(size.x * 0.106, size.y * 0.220), Vector2(size.x * 0.788, size.y * 0.515))
	var 고름 := has_focus()
	if 지금 == 2 or 고름:
		# 은은한 빛은 카드 가장자리만 밝힌다. 다음 플레이로 이동할 때 강제 도장 연출을 넣지 않는다.
		var 세기 := 0.035 + sin(_시각 * 1.4) * 0.012
		for i in range(4, 0, -1):
			draw_rect(Rect2(size * 0.04, size * 0.91).grow(float(i * 3)), Color(0.9, 0.9, 0.9, 세기), false, 3.0)
	draw_rect(앞면, Color(0.035, 0.035, 0.035))
	if 지금 == 2 and 사진 != null:
		# 종횡비를 늘이지 않고 중앙을 잘라 사진 구멍 안에 넣는다. HUD 제외는 스냅 컴포넌트가 한다.
		var 원 := 사진.get_size()
		var 비 := 앞면.size.x / 앞면.size.y
		var 자름 := Vector2(minf(원.x, 원.y * 비), minf(원.y, 원.x / 비))
		draw_texture_rect_region(사진, 앞면, Rect2((원 - 자름) * 0.5, 자름), Color(1, 1, 1, 채움))
	else:
		var 안내 := "잠김" if 지금 == 0 else ("사진 기록 없음" if 지금 == 2 else "아직 찍지 않은 장면")
		draw_string(_글꼴, 앞면.position + Vector2(3, 앞면.size.y * 0.58), 안내, HORIZONTAL_ALIGNMENT_CENTER, 앞면.size.x - 6, 12, Color(0.6, 0.6, 0.6))
	if _틀:
		var 명도 := 0.40 if 지금 == 0 else (0.91 if 고름 else 0.77)
		draw_texture_rect(_틀, Rect2(Vector2.ZERO, size), false, Color(명도, 명도, 명도))
	else:
		draw_rect(앞면.grow(5), Color(0.8, 0.8, 0.8), false, 5)
	var 먹 := Color(0.06, 0.06, 0.06, 0.9)
	# [10-09 Claude] 글씨 크기를 카드 크기에 맞춰 키운다(144px 기준 13 · 11 · 12) — 카드를 키워도 글씨만 작게 남지 않게.
	var 배 := size.x / 144.0
	var 글13 := int(round(13 * 배))
	var 글11 := int(round(11 * 배))
	var 이름 := String(정보.get("id", "")) + " · " + String(정보.get("이름", ""))
	# 작은 카드에서도 이름이 이웃 카드로 넘치지 않게 실제 글꼴 폭으로 줄인다.
	while 이름.length() > 2 and _글꼴.get_string_size(이름, HORIZONTAL_ALIGNMENT_LEFT, -1, 글13).x > size.x * 0.77:
		이름 = 이름.left(이름.length() - 2) + "…"
	draw_string(_글꼴, Vector2(size.x * 0.115, size.y * 0.825), 이름, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.77, 글13, 먹)
	if 지금 == 2 and not 기록.is_empty():
		var 기록형 = load("res://scripts/ui/실행_기록.gd")
		var 글 := "%s / 사망 %d" % [기록형.시간_문자(float(기록.get("초", 0))), int(기록.get("사망", 0))]
		draw_string(_글꼴, Vector2(size.x * 0.115, size.y * 0.90), 글, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.77, 글11, 먹)
	if 지금 == 2 and 도장 > 0.0:
		# 실제 한국어 글꼴로 도장을 찍는다. 생성 이미지에 문자를 굽지 않아 해상도·기록이 바뀌어도 또렷하다.
		var c := Vector2(size.x * 0.74, size.y * 0.62)
		var 잉크 := Color(0.88, 0.88, 0.88, 도장 * 0.78)
		draw_arc(c, 20, 0.15, TAU - 0.15, 40, 잉크, 1.6, true)
		draw_arc(c, 17, 0.25, TAU - 0.25, 36, 잉크, 0.8, true)
		draw_string(_글꼴, c + Vector2(-17, 4), "발견" if bool(정보.get("숨김", false)) else "통과", HORIZONTAL_ALIGNMENT_CENTER, 34, 12, 잉크)
	if not 열쇠.is_empty():
		_열쇠_그리기()
	if 고름:
		draw_rect(Rect2(size * 0.034, size * 0.916), Color(0.94, 0.94, 0.94, 0.82), false, 1.2)


## 카드 오른쪽 위 모서리에 비스듬히 꽂은 반반 열쇠 — 게임 HUD 열쇠 칸과 같은 그림·같은 말을 쓴다(같은 물건으로 읽히게).
##   빈 칸 = 어두운 실루엣 + **점선 윤곽** · 주운 조각 = 그 반쪽(검정 / 흰) · 두 조각 다 = 실선 윤곽 · 문을 열었으면 완성 열쇠 원화.
##   잠긴 카드도 흐리게 보여 준다 — "이 앞에 열쇠 스테이지가 있다" 를 미리 알게.
##   (첫 판은 실루엣만 그렸더니 이 크기에선 둥근 머리만 보여 검은 풍선처럼 읽혔다 → 윤곽선으로 열쇠 모양을 살린다)
static var _열쇠윤곽 := PackedVector2Array()     ## 실루엣 바깥 윤곽(그림 px) — 열쇠_HUD.gd 와 같은 방법으로 뽑는다


func _열쇠_그리기() -> void:
	if _열쇠그림.is_empty():
		for k in ["실루엣", "왼쪽_HUD", "오른쪽_HUD", "왼쪽", "오른쪽"]:
			_열쇠그림[k] = load(열쇠_폴더 + k + ".png")
		var 실0: Texture2D = _열쇠그림["실루엣"]
		if 실0:
			var img := 실0.get_image()
			var bm := BitMap.new()
			bm.create_from_image_alpha(img, 0.5)
			for 폴리 in bm.opaque_to_polygons(Rect2i(Vector2i.ZERO, img.get_size()), 0.8):
				if 폴리.size() > _열쇠윤곽.size():
					_열쇠윤곽 = 폴리
	var 실: Texture2D = _열쇠그림["실루엣"]
	if 실 == null:
		return
	var 키 := size.y * 0.36
	var 배 := 키 / float(실.get_height())
	var 폭 := 실.get_width() * 배
	var 판 := Rect2(-폭 * 0.5, -키 * 0.5, 폭, 키)
	var 가운데 := Vector2(size.x * 0.86, size.y * 0.25)
	var 기울기 := -0.55
	var 잠김 := 지금 == 0
	var 열림 := bool(열쇠.get("열림", false))
	var 왼 := 열림 or bool(열쇠.get("왼쪽", false))
	var 오 := 열림 or bool(열쇠.get("오른쪽", false))
	var 알파 := 0.45 if 잠김 else 1.0
	draw_set_transform(가운데 + Vector2(2, 3), 기울기, Vector2.ONE)
	draw_texture_rect(실, 판, false, Color(0, 0, 0, 0.5 * 알파))                 # 그림자
	draw_set_transform(가운데, 기울기, Vector2.ONE)
	draw_texture_rect(실, 판, false, Color(0.32, 0.32, 0.31, 0.88 * 알파))       # 빈 열쇠 칸 — 중간 회색(검정 반쪽 · 흰 반쪽이 둘 다 도드라지게)
	if not 잠김:
		for 쪽 in ["왼쪽", "오른쪽"]:
			if (왼 if 쪽 == "왼쪽" else 오):
				var 그림: Texture2D = _열쇠그림[쪽 if 열림 else 쪽 + "_HUD"]
				if 그림:
					draw_texture_rect(그림, 판, false)
	if _열쇠윤곽.size() >= 3:
		var 점들 := PackedVector2Array()
		for p in _열쇠윤곽:
			점들.append(판.position + p * 배)
		점들.append(점들[0])
		var 밝은 := Color(0.86, 0.86, 0.84, 0.95 * 알파)
		var 어두운 := Color(0.02, 0.02, 0.02, 0.7 * 알파)
		if 왼 and 오:
			draw_polyline(점들, 어두운, 3.0, true)
			draw_polyline(점들, 밝은, 1.4, true)
		else:
			_점선(점들, 밝은, 어두운)
	draw_set_transform(Vector2.ZERO)


## 둘레를 따라 길이를 누적해 4px 그리고 3px 쉰다(열쇠_HUD 점선과 같은 방식 · 카드 크기에 맞춰 짧게)
func _점선(점들: PackedVector2Array, 밝은: Color, 어두운: Color) -> void:
	var 켬 := 4.0
	var 끔 := 3.0
	var 누적 := 0.0
	for i in 점들.size() - 1:
		var a := 점들[i]
		var b := 점들[i + 1]
		var 길이 := a.distance_to(b)
		var d := 0.0
		while d < 길이:
			var 주기안 := fmod(누적 + d, 켬 + 끔)
			var 남음 := (켬 - 주기안) if 주기안 < 켬 else (켬 + 끔 - 주기안)
			var 끝 := minf(d + 남음, 길이)
			if 주기안 < 켬:
				var p0 := a.lerp(b, d / 길이)
				var p1 := a.lerp(b, 끝 / 길이)
				draw_line(p0, p1, 어두운, 2.6)
				draw_line(p0, p1, 밝은, 1.3)
			d = 끝 + 0.0001
		누적 += 길이
