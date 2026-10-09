extends Control
## ============================================================================
## [2026-10-09 Claude 신규] 타이틀 — 게임을 처음 켜면 나오는 화면(새 로비)
## ----------------------------------------------------------------------------
## [2026-10-09 Codex] 상세 원화의 왼쪽 여백에 제목·물감 메뉴를 놓아 캐릭터와 겹치지 않게 한다.
## ▣ 도형님(10-09): "로비 화면을 다시 만들 건데 게임을 처음 실행했을 때 나오는 화면 — 넌 버튼과 기능적인 부분을 담당하고
##   새로 이미지만 넣으면 사용할 수 있게. 이미지는 GPT 로 만들어 볼게." (참고: 할로우 나이트 타이틀 — 가운데 로고 · 아래 글 메뉴 ·
##   고른 항목 양옆 장식 · 은은한 빛줄기와 떠다니는 먼지)
## ▣ 그림 칸 — assets/ui/로비/타이틀/ (파일을 넣기만 하면 쓴다 · 없으면 코드 그림 · 크기·모양은 assets/ui/로비/_이미지_목록.md)
##   배경.png(1920×1080 · 화면을 덮는다) · 배경_안개.png(가로로 천천히 흐르는 안개 · 투명) · 로고.png(투명 · 가운데 위)
##   메뉴_붓.png(고른 메뉴 뒤 붓 자국 · 투명) · 장식_왼.png · 장식_오른.png(고른 메뉴 양옆 장식) · 먼지.png(작은 입자)
##   소리: 타이틀_음악.ogg(있으면 반복 재생)
## ▣ 메뉴: 이어하기(진행이 있을 때) · 처음부터 · 스테이지(퍼즐 보드) · 설정 · 나가기 / F12 = 예전 개발 로비
## ▣ 기능: 이어하기 = 아직 안 깬 첫 조각으로(이야기 모드) · 처음부터 = 진행을 지우고 01(확인 창 · 기록은 남긴다)
##   설정 = 소리 크기 · 전체 화면(user://settings.cfg — 예전 로비와 같은 키).
## ============================================================================

const 그림_폴더 := "res://assets/ui/로비/타이틀/"
const 글꼴_경로 := "res://assets/fonts/NotoSerifKR/NotoSerifKR.ttf"
const 설정_경로 := "user://settings.cfg"
const 개발_로비 := "res://scenes/lobby/lobby.tscn"
const 보드표 := preload("res://scripts/진행/쳅터1_보드표.gd")

var _캔버스: Control
var _그림: Dictionary = {}
var _글꼴: Font
var _메뉴: VBoxContainer
var _표시: Control                  ## 고른 메뉴 뒤 붓 자국 + 양옆 장식(고른 버튼을 따라 미끄러진다)
var _표시_목표 := Rect2()
var _안개: TextureRect = null
var _빛판: Control
var _t := 0.0
var _창: Control = null
var _이동중 := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_캔버스 = Control.new()
	_캔버스.name = "화면"
	_캔버스.size = Vector2(1920, 1080)
	_캔버스.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_캔버스)
	get_viewport().size_changed.connect(_화면_맞춤)
	_화면_맞춤()
	게임진행.선택_쳅터 = 1
	for k in ["배경", "배경_안개", "로고", "메뉴_붓", "장식_왼", "장식_오른", "먼지"]:
		var 경로: String = 그림_폴더 + k + ".png"
		_그림[k] = load(경로) if ResourceLoader.exists(경로) else null
	# 원본 파일은 보존하고 사용자가 요청한 물감 원화만 새 버전으로 연결한다.
	_그림["배경"] = load(그림_폴더 + "배경_물감_v02.png")
	_그림["메뉴_붓"] = load(그림_폴더 + "메뉴_붓_물감_v02.png")
	_글꼴 = load(글꼴_경로) if ResourceLoader.exists(글꼴_경로) else ThemeDB.fallback_font
	_설정_적용()
	_바탕()
	_로고()
	_메뉴_만들기()
	_음악()
	# 처음 켤 때 검은 화면에서 천천히 밝아진다
	var 막 := ColorRect.new()
	막.color = Color.BLACK
	막.set_anchors_preset(Control.PRESET_FULL_RECT)
	막.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_캔버스.add_child(막)
	create_tween().tween_property(막, "modulate:a", 0.0, 1.2).finished.connect(막.queue_free)


# ── 바탕: 그림(있으면) · 안개 · 빛줄기 · 먼지 ───────────────────────────────
func _바탕() -> void:
	if _그림["배경"]:
		var t := TextureRect.new()
		t.name = "배경"
		t.texture = _그림["배경"]
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_캔버스.add_child(t)
	else:
		var c := ColorRect.new()
		c.name = "배경"
		c.color = Color(0.035, 0.035, 0.04)
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_캔버스.add_child(c)
	if _그림["배경_안개"]:
		_안개 = TextureRect.new()
		_안개.texture = _그림["배경_안개"]
		_안개.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_안개.stretch_mode = TextureRect.STRETCH_TILE
		_안개.size = Vector2(1920 * 2, 1080)
		_안개.modulate.a = 0.55
		_안개.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_캔버스.add_child(_안개)
	# 빛줄기 — 위에서 비스듬히 내려오는 옅은 띠 셋(그림 없이도 분위기 · 할로우 나이트 타이틀처럼)
	_빛판 = Control.new()
	_빛판.set_anchors_preset(Control.PRESET_FULL_RECT)
	_빛판.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_빛판.draw.connect(_빛줄기_그리기)
	_캔버스.add_child(_빛판)
	# 떠다니는 먼지
	var 먼지 := CPUParticles2D.new()
	먼지.position = Vector2(960, 540)
	먼지.amount = 70
	먼지.lifetime = 9.0
	먼지.preprocess = 9.0
	먼지.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	먼지.emission_rect_extents = Vector2(1000, 560)
	먼지.direction = Vector2(0.3, -1)
	먼지.spread = 40.0
	먼지.gravity = Vector2.ZERO
	먼지.initial_velocity_min = 4.0
	먼지.initial_velocity_max = 18.0
	먼지.scale_amount_min = 1.0
	먼지.scale_amount_max = 3.0
	먼지.color = Color(0.92, 0.9, 0.85, 0.35)
	if _그림["먼지"]:
		먼지.texture = _그림["먼지"]
		먼지.scale_amount_min = 0.2
		먼지.scale_amount_max = 0.6
	_캔버스.add_child(먼지)


func _빛줄기_그리기() -> void:
	# 원화 안에 조명이 이미 그려져 있어 네모 빛 띠를 덧씌우면 배경이 겹쳐 보인다.
	if _그림["배경"]:
		return
	var 흔 := 0.5 + 0.5 * sin(_t * 0.35)
	for i in 3:
		var x := 700.0 + i * 260.0
		var a := (0.035 + 0.02 * 흔) * (1.0 - i * 0.25)
		_빛판.draw_colored_polygon(PackedVector2Array([Vector2(x, -20), Vector2(x + 90, -20), Vector2(x + 420, 1100), Vector2(x + 180, 1100)]),
			Color(0.95, 0.93, 0.88, a))


func _process(delta: float) -> void:
	_t += delta
	if _안개:
		_안개.position.x = -fmod(_t * 12.0, 1920.0)
	_빛판.queue_redraw()
	# 고른 메뉴 표시가 부드럽게 따라간다
	if _표시:
		var r := Rect2(_표시.position, _표시.size)
		var 새 := Rect2(r.position.lerp(_표시_목표.position, minf(delta * 14.0, 1.0)), r.size.lerp(_표시_목표.size, minf(delta * 14.0, 1.0)))
		if not 새.is_equal_approx(r):
			_표시.position = 새.position
			_표시.size = 새.size
			_표시.queue_redraw()


# ── 로고 ────────────────────────────────────────────────────────────────────
func _로고() -> void:
	if _그림["로고"]:
		var t := TextureRect.new()
		t.name = "로고"
		t.texture = _그림["로고"]
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.position = Vector2(80, 140)
		t.size = Vector2(650, 260)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_캔버스.add_child(t)
		return
	var 제목 := Label.new()
	제목.name = "로고"
	제목.text = "G R A Y"
	제목.add_theme_font_override("font", _글꼴)
	제목.add_theme_font_size_override("font_size", 120)
	제목.add_theme_color_override("font_color", Color(0.95, 0.94, 0.9))
	제목.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	제목.position = Vector2(80, 175)
	제목.size = Vector2(650, 160)
	_캔버스.add_child(제목)
	var 부제 := Label.new()
	부제.text = "— 흑과 백, 반전의 플랫포머 —"
	부제.add_theme_font_override("font", _글꼴)
	부제.add_theme_font_size_override("font_size", 26)
	부제.add_theme_color_override("font_color", Color(0.7, 0.69, 0.66))
	부제.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	부제.position = Vector2(80, 342)
	부제.size = Vector2(650, 40)
	_캔버스.add_child(부제)


# ── 메뉴 ────────────────────────────────────────────────────────────────────
func _메뉴_만들기() -> void:
	_표시 = Control.new()
	_표시.name = "고른표시"
	_표시.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_표시.draw.connect(_표시_그리기)
	_캔버스.add_child(_표시)
	_메뉴 = VBoxContainer.new()
	_메뉴.name = "메뉴"
	_메뉴.position = Vector2(180, 505)
	_메뉴.size = Vector2(440, 400)
	_메뉴.add_theme_constant_override("separation", 14)
	_캔버스.add_child(_메뉴)
	var 있음 := 게임진행.진행_있나()
	if 있음:
		_항목("이어하기", _이어하기)
	_항목("처음부터", _처음부터)
	_항목("스테이지", func(): _가기(게임진행.보드_씬))
	_항목("설정", _설정_창)
	_항목("나가기", func(): get_tree().quit())
	var 첫: Button = _메뉴.get_child(0)
	첫.call_deferred("grab_focus")
	var 판 := Label.new()
	판.text = "흑과 백 사이, 잃어버린 집을 찾아서"
	판.add_theme_font_override("font", _글꼴)
	판.add_theme_font_size_override("font_size", 16)
	판.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	판.position = Vector2(180, 976)
	_캔버스.add_child(판)


func _항목(글: String, 할일: Callable) -> Button:
	var b := Button.new()
	b.name = 글
	b.text = 글
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(440, 62)
	b.add_theme_font_override("font", _글꼴)
	b.add_theme_font_size_override("font_size", 32)
	b.add_theme_color_override("font_color", Color(0.78, 0.77, 0.74))
	b.add_theme_color_override("font_hover_color", Color(0.08, 0.08, 0.08))
	b.add_theme_color_override("font_focus_color", Color(0.08, 0.08, 0.08))
	b.add_theme_color_override("font_pressed_color", Color(0, 0, 0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# 검정 칠은 기본 항목, 회백색 칠은 선택 항목이다. 설정 창 버튼도 같은 재질을 쓴다.
	preload("res://scripts/ui/물감버튼.gd").꾸미기(b, _그림["메뉴_붓"])
	b.pressed.connect(func():
		if not _이동중 and _창 == null:
			할일.call())
	b.focus_entered.connect(_고름.bind(b))
	b.mouse_entered.connect(b.grab_focus)
	_메뉴.add_child(b)
	return b


func _고름(b: Button) -> void:
	# 글자 폭에 맞춘 붓 자국 자리(양옆 장식 자리까지 포함)
	var w := _글꼴.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	var 가운데 := _메뉴.position + b.position + b.size * 0.5
	_표시_목표 = Rect2(가운데 - Vector2(w * 0.5 + 90, 52), Vector2(w + 180, 104))
	if _표시.size == Vector2.ZERO:
		_표시.position = _표시_목표.position
		_표시.size = _표시_목표.size
	_표시.queue_redraw()


## 고른 메뉴 표시 — 붓 자국(밝은 회백 · 거친 가장자리) + 양옆 장식
func _표시_그리기() -> void:
	var s := _표시.size
	if s.x < 1.0:
		return
	var 붓 := Rect2(Vector2(70, 2), Vector2(s.x - 140, s.y - 4))
	if _그림["메뉴_붓"]:
		_표시.draw_texture_rect(_그림["메뉴_붓"], 붓, false)
	else:
		var 점 := PackedVector2Array()
		var n := 24
		for i in n + 1:
			var x := 붓.position.x + 붓.size.x * float(i) / n
			점.append(Vector2(x, 붓.position.y + 6 + sin(i * 2.7) * 3.0))
		for i in range(n, -1, -1):
			var x := 붓.position.x + 붓.size.x * float(i) / n
			점.append(Vector2(x, 붓.end.y - 6 + cos(i * 1.9) * 3.0))
		_표시.draw_colored_polygon(점, Color(0.86, 0.85, 0.81, 0.92))
		_표시.draw_colored_polygon(PackedVector2Array([붓.position + Vector2(-14, 18), 붓.position + Vector2(4, 8), 붓.position + Vector2(2, 34)]), Color(0.86, 0.85, 0.81, 0.7))
	var 장식크기 := Vector2(56, 40)
	var 왼 := Rect2(Vector2(4, s.y * 0.5 - 20), 장식크기)
	var 오른 := Rect2(Vector2(s.x - 60, s.y * 0.5 - 20), 장식크기)
	if _그림["장식_왼"] and _그림["장식_오른"]:
		_표시.draw_texture_rect(_그림["장식_왼"], 왼, false)
		_표시.draw_texture_rect(_그림["장식_오른"], 오른, false)
	else:
		for r in [왼, 오른]:
			var c: Vector2 = (r as Rect2).get_center()
			_표시.draw_colored_polygon(PackedVector2Array([c + Vector2(-14, 0), c + Vector2(0, -9), c + Vector2(14, 0), c + Vector2(0, 9)]), Color(0.92, 0.9, 0.86, 0.9))
			_표시.draw_line(c + Vector2(-26, 0), c + Vector2(26, 0), Color(0.92, 0.9, 0.86, 0.5), 1.5, true)


# ── 동작 ────────────────────────────────────────────────────────────────────
func _가기(경로: String) -> void:
	if _이동중:
		return
	_이동중 = true
	StageTransition.change_scene(self, 경로)


func _이어하기() -> void:
	# 사진 지도의 잔가지를 방문했거나 하수도까지 갔을 때도 실제 마지막 장소에서 이어간다.
	var 마지막 := 게임진행.이어할_씬()
	if not 마지막.is_empty() and ResourceLoader.exists(마지막, "PackedScene"):
		_이동중 = true
		게임진행.보드_모드 = false
		load("res://scripts/쳅터1/전경전환.gd").씬으로_들어가기(self, 마지막, "")
		return
	var c: Dictionary = 보드표.이어할_조각()
	if c.is_empty():
		return
	_이동중 = true
	게임진행.보드_모드 = false
	load("res://scripts/쳅터1/전경전환.gd").씬으로_들어가기(self, 보드표.씬경로(c), String(c.get("입구", "")))


func _처음부터() -> void:
	if 게임진행.진행_있나():
		_확인_창("진행을 지우고 처음부터 시작할까요?\n(시간·사망 기록은 남습니다)", func():
			게임진행.진행_지우기()
			_새로_시작())
	else:
		_새로_시작()


func _새로_시작() -> void:
	_이동중 = true
	게임진행.보드_모드 = false
	var 첫: Dictionary = 보드표.조각들()[0]
	load("res://scripts/쳅터1/전경전환.gd").씬으로_들어가기(self, 보드표.씬경로(첫), String(첫.get("입구", "")))


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_F12:
		_가기(개발_로비)                  # 예전 개발 로비(하수도 지도·스테이지 바로가기)
	elif e.is_action_pressed("ui_cancel") and _창:
		_창_닫기()
		get_viewport().set_input_as_handled()


# ── 창(확인 · 설정) ──────────────────────────────────────────────────────────
func _창_틀(크기: Vector2) -> Control:
	_창 = Control.new()
	_창.set_anchors_preset(Control.PRESET_FULL_RECT)
	_캔버스.add_child(_창)
	var 어둠 := ColorRect.new()
	어둠.color = Color(0, 0, 0, 0.7)
	어둠.set_anchors_preset(Control.PRESET_FULL_RECT)
	_창.add_child(어둠)
	var 판 := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.075, 0.97)
	sb.border_color = Color(0.6, 0.59, 0.56)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(36)
	판.add_theme_stylebox_override("panel", sb)
	판.custom_minimum_size = 크기
	판.position = Vector2(960, 540) - 크기 * 0.5
	_창.add_child(판)
	var 안 := VBoxContainer.new()
	안.add_theme_constant_override("separation", 18)
	판.add_child(안)
	return 안


func _글(부모: Control, 글: String, 크기: int = 26) -> Label:
	var l := Label.new()
	l.text = 글
	l.add_theme_font_override("font", _글꼴)
	l.add_theme_font_size_override("font_size", 크기)
	l.add_theme_color_override("font_color", Color(0.92, 0.9, 0.86))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	부모.add_child(l)
	return l


func _창_버튼(부모: Control, 글: String, 할일: Callable) -> Button:
	var b := Button.new()
	b.text = 글
	b.add_theme_font_override("font", _글꼴)
	b.add_theme_font_size_override("font_size", 24)
	preload("res://scripts/ui/물감버튼.gd").꾸미기(b, _그림["메뉴_붓"])
	b.pressed.connect(할일)
	부모.add_child(b)
	return b


func _확인_창(물음: String, 예: Callable) -> void:
	var 안 := _창_틀(Vector2(720, 300))
	_글(안, 물음)
	var 줄 := HBoxContainer.new()
	줄.alignment = BoxContainer.ALIGNMENT_CENTER
	줄.add_theme_constant_override("separation", 40)
	안.add_child(줄)
	var 아니 := _창_버튼(줄, "아니요", _창_닫기)
	_창_버튼(줄, "예", func(): _창_닫기(); 예.call())
	아니.grab_focus()


func _설정_창() -> void:
	var 안 := _창_틀(Vector2(720, 380))
	_글(안, "설정", 34)
	var cfg := ConfigFile.new()
	cfg.load(설정_경로)
	_글(안, "소리 크기", 22)
	var 소리 := HSlider.new()
	소리.min_value = 0.0
	소리.max_value = 1.0
	소리.step = 0.05
	소리.value = float(cfg.get_value("audio", "master", 1.0))
	소리.custom_minimum_size = Vector2(500, 30)
	소리.value_changed.connect(func(v: float):
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))
		_설정_저장("audio", "master", v))
	안.add_child(소리)
	var 전체 := CheckBox.new()
	전체.text = "전체 화면"
	전체.add_theme_font_override("font", _글꼴)
	전체.add_theme_font_size_override("font_size", 22)
	전체.button_pressed = bool(cfg.get_value("video", "fullscreen", false))
	전체.toggled.connect(func(on: bool):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
		_설정_저장("video", "fullscreen", on))
	안.add_child(전체)
	_창_버튼(안, "닫기", _창_닫기).grab_focus()


func _설정_저장(구역: String, 키: String, 값: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.load(설정_경로)
	cfg.set_value(구역, 키, 값)
	cfg.save(설정_경로)


func _설정_적용() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(설정_경로) != OK:
		return
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(cfg.get_value("audio", "master", 1.0)), 0.0001)))
	if bool(cfg.get_value("video", "fullscreen", false)) and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _창_닫기() -> void:
	if _창:
		_창.queue_free()
		_창 = null
	var 첫: Button = _메뉴.get_child(0)
	첫.grab_focus()


func _음악() -> void:
	var 경로 := 그림_폴더 + "타이틀_음악.ogg"
	if not ResourceLoader.exists(경로):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(경로)
	p.autoplay = true
	if p.stream is AudioStreamOggVorbis:
		(p.stream as AudioStreamOggVorbis).loop = true
	_캔버스.add_child(p)


func _화면_맞춤() -> void:
	# 글씨·사진·클릭 영역을 같은 비율로 맞춰 작은 창에서도 UI가 잘리지 않게 한다.
	if not is_inside_tree() or not is_instance_valid(_캔버스):
		return
	var 화면 := get_viewport_rect().size
	var 비율 := minf(화면.x / 1920.0, 화면.y / 1080.0)
	_캔버스.scale = Vector2.ONE * 비율
	_캔버스.position = (화면 - Vector2(1920, 1080) * 비율) * 0.5
