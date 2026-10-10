extends Control
## ============================================================================
## [2026-10-09 Claude 신규] 퍼즐 보드 — 쳅터1 스테이지 선택 화면
## ----------------------------------------------------------------------------
## ▣ 도형님(10-09)
##   "스테이지 선택창을 퍼즐 이미지처럼 — 한 스테이지를 클리어하면 퍼즐이 채워지고 빈 곳을 클릭해서 하나씩 채우는 느낌.
##    퍼즐이 이어지는 게 아니라 퍼즐 조각이 **실로 이어져서** 앞 스테이지를 클리어해야 뒤 스테이지를 깰 수 있게.
##    그 길의 스테이지를 다 깨면 창을 띄우고, 클리어한 조각은 빛이 은은하게.
##    숨겨진 스테이지는 입구를 찾아내면 히든 길이 점선으로, 클리어 시 도장.
##    클리어 시간과 데스 카운트를 잉크로 적은 느낌 + 인게임 해당 스테이지의 한 장면 사진."
## ▣ 흐름
##   · 조각 = 스테이지(표 = scenes/lobby/퍼즐보드_쳅터1.json · 규칙 = scripts/진행/쳅터1_보드표.gd).
##   · 열린 조각을 누르면 그 스테이지로(보드 모드) → 출구를 지나면 클리어가 적히고 **실제 다음 스테이지로 걸어간다**
##     → 선택창을 직접 열면 막 깬 사진이 채워지는 연출(사진이 번지고 · 빛이 일고 · 도장이 쾅) → 그 길(2층 · 1층 …)을 다 깼으면 창.
##   · 잠긴 조각을 누르면 덜컥(앞 스테이지를 먼저).
## ▣ 그림 칸(없으면 코드 그림) — assets/ui/로비/보드/: 배경.png · 실.png(가로로 늘이는 실 결) · 핀.png · 창_틀.png · 제목_붓.png
##   조각 쪽 그림은 퍼즐조각.gd 머리말. 이미지 목록·크기는 assets/ui/로비/_이미지_목록.md.
## ▣ 조작: 마우스 · 방향키(가장 가까운 조각으로) · Enter/Space 들어가기 · Esc 뒤로.
## ============================================================================

const 보드표 := preload("res://scripts/진행/쳅터1_보드표.gd")
const 조각_스크립트 := preload("res://scripts/ui/사진카드.gd")
const 그림_폴더 := "res://assets/ui/로비/보드/"
const 글꼴_경로 := "res://assets/fonts/NotoSerifKR/NotoSerifKR.ttf"
const 조각_크기 := Vector2(160, 160)   ## [10-09 Claude] 144 → 160: 카드 이름(13px)이 1080p 창에서 거의 안 읽혀서. 줄 간격(세로 205px)에 맞춘 최대치 근처

var _조각들: Dictionary = {}        ## id → 퍼즐조각 Control
var _실판: Control
var _핀판: Control                  ## 핀은 조각 위에(실은 조각 뒤)
var _정보: Label
var _정보_기록: Label
var _창: Control = null
var _창_확인: Button = null       ## 창의 확인 버튼 — Esc 도 이 버튼을 누른 것으로(연출 순서가 이어지게)
var _연출중 := false
var _캔버스: Control
var _그림: Dictionary = {}
var _글꼴: Font
var _다음쳅터: Button
var _지도내용: Control
var _지도스크롤: ScrollContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_캔버스 = Control.new()
	_캔버스.name = "화면"
	_캔버스.size = Vector2(1920, 1080)
	_캔버스.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_캔버스)
	get_viewport().size_changed.connect(_화면_맞춤)
	_화면_맞춤()
	for k in ["배경", "실", "핀", "창_틀", "제목_붓"]:
		var 경로: String = 그림_폴더 + k + ".png"
		_그림[k] = load(경로) if ResourceLoader.exists(경로) else null
	# 퍼즐 대신 사진·물감 원화를 사용한다. 실제 기록과 사진은 기존 진행 데이터에서 읽는다.
	_그림["배경"] = load(그림_폴더 + "배경_물감_v02.png")
	_그림["제목_붓"] = load("res://assets/ui/로비/타이틀/메뉴_붓_물감_v02.png")
	_글꼴 = load(글꼴_경로) if ResourceLoader.exists(글꼴_경로) else ThemeDB.fallback_font
	_바탕()
	_지도영역_만들기()
	_실판 = Control.new()
	_실판.name = "실"
	_실판.set_anchors_preset(Control.PRESET_FULL_RECT)
	_실판.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_실판.draw.connect(_실_그리기)
	_지도내용.add_child(_실판)
	_조각_놓기()
	_핀판 = Control.new()
	_핀판.name = "핀"
	_핀판.set_anchors_preset(Control.PRESET_FULL_RECT)
	_핀판.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_핀판.draw.connect(func():
		for b in _조각들.values():
			_핀(_핀_자리(b)))
	_지도내용.add_child(_핀판)
	_머리와_정보()
	call_deferred("_돌아옴_연출")


# ── 바탕 · 제목 · 정보 ────────────────────────────────────────────────────────
func _지도영역_만들기() -> void:
	_지도내용 = _캔버스
	if 게임진행.선택_쳅터 != 2:
		return
	# 챕터2만 사진 지도 본문을 스크롤한다. 제목·뒤로·선택 정보는 항상 화면에 남는다.
	_지도스크롤 = ScrollContainer.new()
	_지도스크롤.name = "하수도지도스크롤"
	_지도스크롤.position = Vector2(40, 145)
	_지도스크롤.size = Vector2(1840, 775)
	_지도스크롤.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_지도스크롤.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_지도스크롤.follow_focus = true
	_캔버스.add_child(_지도스크롤)
	_지도내용 = Control.new()
	_지도내용.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var 폭 := 1840.0
	for c in 보드표.조각들():
		폭 = maxf(폭, float(c["위치"][0]) * 1920.0 + 100.0)
	_지도내용.custom_minimum_size = Vector2(폭, 750)
	_지도스크롤.add_child(_지도내용)


func _바탕() -> void:
	if _그림["배경"]:
		var t := TextureRect.new()
		t.texture = _그림["배경"]
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_캔버스.add_child(t)
	else:
		var c := ColorRect.new()
		c.color = Color(0.045, 0.045, 0.05)
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_캔버스.add_child(c)
		# 코드 바탕 — 가장자리가 어두운 비네트 + 옅은 종이 얼룩(그림이 오기 전 자리 맞춤용)
		var 비네트 := Control.new()
		비네트.set_anchors_preset(Control.PRESET_FULL_RECT)
		비네트.mouse_filter = Control.MOUSE_FILTER_IGNORE
		비네트.draw.connect(func():
			var s := 비네트.size
			for i in 8:
				var r := s.length() * (0.65 - i * 0.04)
				비네트.draw_circle(s * 0.5, r, Color(0.09, 0.09, 0.1, 0.06)))
		_캔버스.add_child(비네트)


func _머리와_정보() -> void:
	var 제목 := Label.new()
	제목.text = String(보드표.표().get("제목", "쳅터 1"))
	제목.add_theme_font_override("font", _글꼴)
	제목.add_theme_font_size_override("font_size", 44)
	제목.add_theme_color_override("font_color", Color(0.92, 0.9, 0.86))
	제목.position = Vector2(64, 40)
	_캔버스.add_child(제목)
	if _그림["제목_붓"]:
		var 붓 := TextureRect.new()
		붓.texture = _그림["제목_붓"]
		# [10-09 Claude 수정] expand_mode 를 size 보다 **먼저** 바꾼다.
		#   기본(EXPAND_KEEP_SIZE)일 때 size 를 넣으면 최소 크기 = 원화 크기(2172×724)로 막혀
		#   붓칠이 원본 크기 그대로 커져 위쪽 사진 카드를 통째로 덮었다(도형님 10-09: "스테이지 선택이 안 보여").
		붓.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		붓.stretch_mode = TextureRect.STRETCH_SCALE
		붓.position = Vector2(30, 30)
		붓.size = Vector2(580, 110)
		붓.modulate = Color(0.12, 0.12, 0.12)
		붓.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_캔버스.add_child(붓)
		# 제목 바로 뒤가 아니라 바탕 바로 위(실·카드보다 뒤)에 둔다 — 크기가 또 틀어져도 카드를 가리지 않게.
		_캔버스.move_child(붓, 1)
	# 아래 정보 띠 — 고른 조각 이름 · 상태 · 기록
	_정보 = Label.new()
	_정보.add_theme_font_override("font", _글꼴)
	_정보.add_theme_font_size_override("font_size", 30)
	_정보.add_theme_color_override("font_color", Color(0.93, 0.91, 0.87))
	_정보.position = Vector2(64, 960)
	_캔버스.add_child(_정보)
	_정보_기록 = Label.new()
	_정보_기록.add_theme_font_override("font", _글꼴)
	_정보_기록.add_theme_font_size_override("font_size", 20)
	_정보_기록.add_theme_color_override("font_color", Color(0.7, 0.69, 0.66))
	_정보_기록.position = Vector2(66, 1006)
	_캔버스.add_child(_정보_기록)
	if 게임진행.선택_쳅터 == 2:
		_글_버튼("← 집의 기억", Vector2(1410, 990)).pressed.connect(func():
			게임진행.선택_쳅터 = 1
			StageTransition.change_scene(self, 게임진행.보드_씬))
	var 뒤로 := _글_버튼("뒤로", Vector2(1720, 990))
	뒤로.pressed.connect(_뒤로)


func _글_버튼(글: String, 자리: Vector2) -> Button:
	var b := Button.new()
	b.text = 글
	b.flat = true
	b.add_theme_font_override("font", _글꼴)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", Color(0.75, 0.74, 0.71))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	preload("res://scripts/ui/물감버튼.gd").꾸미기(b, _그림["제목_붓"])
	b.position = 자리
	_캔버스.add_child(b)
	return b


# ── 조각 ─────────────────────────────────────────────────────────────────────
func _조각_놓기() -> void:
	var 화면 := Vector2(1920, 1080)
	for c in 보드표.조각들():
		var 열 := 보드표.열림(c)
		var 깸 := 보드표.클리어함(c)
		if bool(c.get("숨김", false)) and not 보드표.발견함(c):
			continue                       # 숨은 조각 — 입구를 찾기 전엔 조각도 실도 없다
		var 조각 := Control.new()
		조각.set_script(조각_스크립트)
		조각.name = "조각_" + String(c["id"])
		조각.size = 조각_크기
		var 위치: Array = c["위치"]
		조각.position = Vector2(float(위치[0]), float(위치[1])) * 화면 - 조각_크기 * 0.5
		if _지도스크롤:
			조각.position -= _지도스크롤.position
		_지도내용.add_child(조각)
		var 상태값: int = 2 if 깸 else (1 if 열 else 0)
		var 새로 := 깸 and not 게임진행.보드_본("본_" + 보드표.씬경로(c))
		조각.call("준비", c, 상태값, 보드표.사진(c) if 깸 else null, 보드표.기록(c) if 깸 else {})
		조각.set("열쇠", 보드표.열쇠_진행(c))          # [10-10 Claude] 열쇠 스테이지 표시(카드 오른쪽 위 열쇠)
		if 새로:
			조각.set("채움", 0.0)
			조각.set("도장", 0.0)
		조각.connect("눌림", _조각_눌림)
		조각.focus_entered.connect(_고름.bind(c))
		조각.mouse_entered.connect(func(): 조각.grab_focus())
		_조각들[String(c["id"])] = 조각
	# 챕터 선택 입구 — 개별 맵의 클리어 해금과 챕터 지도 열기는 별개다.
	var 다음: Dictionary = 보드표.표().get("다음_쳅터", {})
	if not 다음.is_empty():
		var 위치2: Array = 다음["위치"]
		_다음쳅터 = _글_버튼(String(다음["이름"]) + "  ▸", Vector2(float(위치2[0]), float(위치2[1])) * 화면 - Vector2(40, 20))
		_다음쳅터.add_theme_font_size_override("font_size", 28)
		# [2026-10-10 Codex] 집 15번 미클리어 때문에 버튼이 먹통처럼 보였다. 로비와 동일하게 하수도 지도는 바로 연다.
		_다음쳅터.disabled = not ResourceLoader.exists(게임진행.지도_씬, "PackedScene")
		_다음쳅터.pressed.connect(func():
			게임진행.보드_모드 = false
			게임진행.선택_쳅터 = 2
			StageTransition.change_scene(self, 게임진행.지도_씬))
	_이웃_잇기()
	var 처음: Control = _조각들.get(게임진행.마지막_칸 if 게임진행.선택_쳅터 == 2 else 게임진행.마지막_조각, null)
	if 처음 == null:
		var 이어: Dictionary = 보드표.이어할_조각()
		처음 = _조각들.get(String(이어.get("id", "")), null)
	if 처음:
		처음.call_deferred("grab_focus")


## 방향키 이웃 — 각 방향으로 가장 가까운 조각(화면 거리 + 방향 벗어남 벌점)
func _이웃_잇기() -> void:
	var 다 := _조각들.values()
	for a in 다:
		var 가운데: Vector2 = a.position + a.size * 0.5
		var 방향들 := {"focus_neighbor_left": Vector2.LEFT, "focus_neighbor_right": Vector2.RIGHT,
			"focus_neighbor_top": Vector2.UP, "focus_neighbor_bottom": Vector2.DOWN}
		for 키 in 방향들:
			var 최선: Control = null
			var 점수 := INF
			for b in 다:
				if b == a:
					continue
				var d: Vector2 = (b.position + b.size * 0.5) - 가운데
				var 앞 := d.dot(방향들[키])
				if 앞 <= 10.0:
					continue
				var s := d.length() + absf(d.cross(방향들[키])) * 1.5
				if s < 점수:
					점수 = s
					최선 = b
			if 최선:
				a.set(키, a.get_path_to(최선))


func _고름(c: Dictionary) -> void:
	# 방향키와 클리어 채움 연출로 고른 새 열도 스크롤 안에 보이게 한다.
	if _지도스크롤:
		var 카드: Control = _조각들.get(String(c["id"]), null)
		if 카드:
			_지도스크롤.ensure_control_visible(카드)
	var 깸 := 보드표.클리어함(c)
	var 열 := 보드표.열림(c)
	_정보.text = "%s · %s" % [String(c["id"]), String(c["이름"])]
	if 깸:
		var r := 보드표.기록(c)
		var 기록형 = load("res://scripts/ui/실행_기록.gd")
		_정보_기록.text = "클리어 · 최단 %s · 최소 사망 %d · %d번 통과" % [기록형.시간_문자(float(r.get("초", 0.0))), int(r.get("사망", 0)), int(r.get("횟수", 1))] if not r.is_empty() else "클리어"
	elif 열:
		_정보_기록.text = "아직 찍지 않은 장면 · 눌러서 들어가기"
	else:
		_정보_기록.text = "잠김 · 이어진 앞 스테이지를 클리어하세요"
	_정보_기록.text += _열쇠_글(c)


## [10-10 Claude] 아래 정보 띠의 열쇠 한 마디 — 열쇠 스테이지가 아니면 빈 글
func _열쇠_글(c: Dictionary) -> String:
	var k := 보드표.열쇠_진행(c)
	if k.is_empty():
		return ""
	var 개 := int(bool(k["왼쪽"])) + int(bool(k["오른쪽"]))
	if String(k["주인"]) != "":
		var 주인: Dictionary = 보드표.경로로_찾기(String(k["주인"]))
		return "   ·   열쇠 조각이 있는 방 — %s 문을 연다 (%d/2)" % [String(주인.get("이름", "다른 방")), 개]
	if bool(k["열림"]):
		return "   ·   열쇠 스테이지 — 문을 열었다"
	return "   ·   열쇠 스테이지 — 검정·흰 조각을 모아야 출구가 열린다 (%d/2)" % 개


func _조각_눌림(조각: Control) -> void:
	if _연출중 or _창:
		return
	var c: Dictionary = 조각.get("정보")
	if not 보드표.열림(c):
		var tw := create_tween()
		var 원 := 조각.position
		tw.tween_property(조각, "position", 원 + Vector2(6, 0), 0.04)
		tw.tween_property(조각, "position", 원 - Vector2(6, 0), 0.06)
		tw.tween_property(조각, "position", 원, 0.04)
		return
	게임진행.보드_모드 = false
	게임진행.지도_모드 = 2 if 게임진행.선택_쳅터 == 2 else 0
	게임진행.마지막_조각 = String(c["id"])
	_연출중 = true
	# 쳅터1 방식 입장 — 짧은 암전 뒤 입구 길목 안에서 걸어 나온다(입구가 없으면 시작 위치)
	load("res://scripts/쳅터1/전경전환.gd").씬으로_들어가기(self, 보드표.씬경로(c), String(c.get("입구", "")))


func _뒤로() -> void:
	게임진행.보드_모드 = false
	StageTransition.change_scene(self, 게임진행.타이틀_씬)


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		if _창 and _창_확인:
			_창_확인.pressed.emit()
		else:
			_뒤로()
		get_viewport().set_input_as_handled()


# ── 실(앞 조각과 이어진 끈) ─────────────────────────────────────────────────
func _실_그리기() -> void:
	for c in 보드표.조각들():
		var b: Control = _조각들.get(String(c["id"]), null)
		if b == null:
			continue
		for id in c.get("앞", []):
			var a: Control = _조각들.get(String(id), null)
			if a == null:
				continue
			var 깸a := 보드표.클리어함(보드표.찾기(String(id)))
			var 깸b := 보드표.클리어함(c)
			var 색 := Color(0.95, 0.93, 0.88, 0.75) if (깸a and 깸b) else (Color(0.8, 0.78, 0.74, 0.5) if 깸a else Color(0.5, 0.5, 0.5, 0.22))
			# 큰 줄기는 굵게, 옆방은 가늘게 그려 주 이야기와 선택 경로를 구별한다.
			var 주선 := bool(c.get("주경로", false)) and bool(보드표.찾기(String(id)).get("주경로", false))
			_실(_핀_자리(a), _핀_자리(b), 색, bool(c.get("숨김", false)), 4.0 if 주선 else 2.0)
	# 다음 쳅터
	if _다음쳅터:
		var 다음: Dictionary = 보드표.표().get("다음_쳅터", {})
		for id in 다음.get("앞", []):
			var a2: Control = _조각들.get(String(id), null)
			if a2:
				var 열 := 보드표.클리어함(보드표.찾기(String(id)))
				_실(_핀_자리(a2), _다음쳅터.position + Vector2(0, 20), Color(0.8, 0.78, 0.74, 0.5 if 열 else 0.18), false)


func _핀_자리(조각: Control) -> Vector2:
	return 조각.position + Vector2(조각.size.x * 0.5, 조각.size.y * 0.5 - minf(조각.size.x, 조각.size.y) * 0.43)


## 실 — 살짝 처진 줄(현수선 근사) · 숨은 길은 점선
func _실(a: Vector2, b: Vector2, 색: Color, 점선: bool, 굵기: float = 2.8) -> void:
	var 점 := PackedVector2Array()
	var 처짐 := clampf(a.distance_to(b) * 0.055, 6.0, 22.0)
	for i in 25:
		var t := float(i) / 24.0
		점.append(a.lerp(b, t) + Vector2(0, sin(t * PI) * 처짐))
	if 점선:
		for i in range(0, 점.size() - 1, 2):
			_실판.draw_line(점[i], 점[i + 1], 색, 2.0, true)
	elif _그림["실"]:
		for i in 점.size() - 1:
			var 길이 := 점[i].distance_to(점[i + 1])
			_실판.draw_set_transform(점[i], (점[i + 1] - 점[i]).angle(), Vector2.ONE)
			_실판.draw_texture_rect(_그림["실"], Rect2(0, -3, 길이, 6), true, 색)
		_실판.draw_set_transform(Vector2.ZERO)
	else:
		# 서로 이어지는 경로는 가지처럼 굵어졌다 가늘어진다. 미세 먹선은 자로 그은 느낌을 줄인다.
		_실판.draw_polyline(점, Color(색.r, 색.g, 색.b, 색.a * 0.22), 7.0, true)
		_실판.draw_polyline(점, 색, 굵기, true)
		var 결 := PackedVector2Array()
		for i in 점.size():
			결.append(점[i] + Vector2(sin(i * 1.7) * 1.0, cos(i * 2.2) * 1.4))
		_실판.draw_polyline(결, Color(색.r, 색.g, 색.b, 색.a * 0.45), 1.0, true)


func _핀(자리: Vector2) -> void:
	if _그림["핀"]:
		var t: Texture2D = _그림["핀"]
		_핀판.draw_texture_rect(t, Rect2(자리 - Vector2(14, 14), Vector2(28, 28)), false)
		return
	_핀판.draw_circle(자리 + Vector2(1.5, 2), 7.0, Color(0, 0, 0, 0.5))
	_핀판.draw_circle(자리, 7.0, Color(0.62, 0.6, 0.56))
	_핀판.draw_circle(자리 - Vector2(2, 2), 2.5, Color(0.95, 0.94, 0.9))


# ── 돌아왔을 때 연출 ────────────────────────────────────────────────────────
## 막 깬 조각을 하나씩 채운다(사진이 번지고 · 빛 · 도장 쾅) → 다 깬 길이 있으면 창
func _돌아옴_연출() -> void:
	_실판.queue_redraw()
	var 새로들: Array = []
	for c in 보드표.조각들():
		var 조각: Control = _조각들.get(String(c["id"]), null)
		if 조각 and float(조각.get("채움")) < 1.0:
			새로들.append([c, 조각])
	if not 새로들.is_empty():
		_연출중 = true
		for 쌍 in 새로들:
			var c: Dictionary = 쌍[0]
			var 조각: Control = 쌍[1]
			조각.pivot_offset = 조각.size * 0.5
			조각.grab_focus()
			var tw := create_tween()
			tw.tween_property(조각, "scale", Vector2(1.04, 1.04), 0.12).from(Vector2(0.98, 0.98))
			tw.parallel().tween_property(조각, "채움", 1.0, 0.28)
			tw.tween_property(조각, "scale", Vector2.ONE, 0.10)
			tw.tween_property(조각, "도장", 1.0, 0.18)
			await tw.finished
			var 카 := get_viewport().get_camera_2d()
			if 카 and 카.has_method("add_trauma"):
				카.add_trauma(0.1)
			게임진행.보드_봄_기록("본_" + 보드표.씬경로(c))
			await get_tree().create_timer(0.15).timeout
		_연출중 = false
	# 길 완료 창 — 아직 안 띄운 것만, 하나씩
	for 길 in 보드표.길들():
		if 보드표.길_완료(길) and not 게임진행.보드_본("길_" + String(길["이름"])):
			게임진행.보드_봄_기록("길_" + String(길["이름"]))
			await _창_띄우기(길)


func _창_띄우기(길: Dictionary) -> void:
	var 합초 := 0.0
	var 합사망 := 0
	for id in 길.get("조각", []):
		var r := 보드표.기록(보드표.찾기(String(id)))
		합초 += float(r.get("초", 0.0))
		합사망 += int(r.get("사망", 0))
	_창 = Control.new()
	_창.name = "길완료창"
	_창.set_anchors_preset(Control.PRESET_FULL_RECT)
	_캔버스.add_child(_창)
	var 어둠 := ColorRect.new()
	어둠.color = Color(0, 0, 0, 0.6)
	어둠.set_anchors_preset(Control.PRESET_FULL_RECT)
	_창.add_child(어둠)
	var 틀 := Control.new()
	틀.size = Vector2(760, 420)
	틀.position = Vector2(960, 540) - 틀.size * 0.5
	_창.add_child(틀)
	if _그림["창_틀"]:
		var t := TextureRect.new()
		t.texture = _그림["창_틀"]
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.size = 틀.size
		틀.add_child(t)
	else:
		틀.draw.connect(func():
			틀.draw_rect(Rect2(Vector2.ZERO, 틀.size), Color(0.86, 0.84, 0.79))
			틀.draw_rect(Rect2(Vector2(24, 24), 틀.size - Vector2(48, 120)), Color(0.07, 0.07, 0.075))
			틀.draw_rect(Rect2(Vector2.ZERO, 틀.size), Color(0.3, 0.29, 0.27), false, 2.0))
	var 기록형 = load("res://scripts/ui/실행_기록.gd")
	var 글들 := [[String(길["이름"]), 40, Vector2(60, 70), Color(0.95, 0.94, 0.9)],
		[String(길.get("문구", "")), 22, Vector2(60, 140), Color(0.85, 0.84, 0.8)],
		["걸린 시간 %s · 사망 %d" % [기록형.시간_문자(합초), 합사망], 22, Vector2(60, 200), Color(0.75, 0.74, 0.7)]]
	for g in 글들:
		var l := Label.new()
		l.text = g[0]
		l.add_theme_font_override("font", _글꼴)
		l.add_theme_font_size_override("font_size", g[1])
		l.add_theme_color_override("font_color", g[3])
		l.position = g[2]
		l.size.x = 640
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		틀.add_child(l)
	var 확인 := Button.new()
	확인.text = "확인"
	확인.flat = true
	확인.add_theme_font_override("font", _글꼴)
	확인.add_theme_font_size_override("font_size", 28)
	# 어두운 기본 칠과 밝은 포커스 칠 모두에서 글씨가 보이도록 공통 스타일을 한 번만 적용한다.
	preload("res://scripts/ui/물감버튼.gd").꾸미기(확인, _그림["제목_붓"])
	확인.position = Vector2(틀.size.x * 0.5 - 40, 틀.size.y - 80)
	틀.add_child(확인)
	확인.grab_focus()
	_창_확인 = 확인
	틀.pivot_offset = 틀.size * 0.5
	var tw := create_tween()
	tw.tween_property(틀, "scale", Vector2.ONE, 0.3).from(Vector2(0.8, 0.8)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await 확인.pressed
	_창_닫기()


func _창_닫기() -> void:
	if _창:
		_창.queue_free()
		_창 = null
		_창_확인 = null
	var 조각: Control = _조각들.get(게임진행.마지막_조각, null)
	if 조각:
		조각.grab_focus()


func _화면_맞춤() -> void:
	# 글씨·사진·클릭 영역을 같은 비율로 맞춰 작은 창에서도 UI가 잘리지 않게 한다.
	if not is_inside_tree() or not is_instance_valid(_캔버스):
		return
	var 화면 := get_viewport_rect().size
	var 비율 := minf(화면.x / 1920.0, 화면.y / 1080.0)
	_캔버스.scale = Vector2.ONE * 비율
	_캔버스.position = (화면 - Vector2(1920, 1080) * 비율) * 0.5
