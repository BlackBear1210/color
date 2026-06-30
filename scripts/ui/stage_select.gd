extends Control
## 스테이지 선택 화면.
## ▼ 2026-06-22 보강: 잠금/클리어 표시 + 베스트 타임 + 잠긴 스테이지 비활성화.
## ▼ 2026-06-28 수정: SceneManager.STAGES 전체에서 버튼 '동적 생성'.
## ▼ 2026-06-30 보강(Claude): 페이지네이션(페이지당 10개 = 2열×5행) + ◀이전/다음▶ + UI 스타일 개선.
##   스테이지가 15개로 늘며 화면 아래로 넘쳤던 문제 해결. 코드 생성 StyleBox 로 카드형 버튼·호버·잠금 표현.

const PER_PAGE: int = 10        # 한 페이지에 보일 스테이지 수(2열 × 5행)
const COLS: int = 2

# ▼ 2026-06-30 색 변경(Claude): 마젠타 강조 → 어두운 회색 톤(사용자 요청 "어두운 분위기").
const C_BG       := Color(0.14, 0.14, 0.16, 1.0)
const C_BG_HOVER := Color(0.22, 0.22, 0.25, 1.0)
const C_BG_PRESS := Color(0.09, 0.09, 0.10, 1.0)
const C_BORDER   := Color(0.30, 0.31, 0.35, 1.0)
const C_ACCENT   := Color(0.62, 0.64, 0.70, 1.0)   # 밝은 스틸 그레이(호버/강조)
const C_CLEAR    := Color(0.80, 0.82, 0.87, 1.0)   # 클리어=밝은 회색(흰빛)
const C_LOCK_BG  := Color(0.10, 0.10, 0.12, 0.7)

var _panel: Panel = null
var _page: int = 0
var _page_count: int = 1
var _nums: Array = []

func _ready() -> void:
	_panel = get_node_or_null("Panel")
	if _panel == null:
		return
	# 패널을 조금 키워 페이지 컨트롤 공간 확보
	_panel.offset_left = -340.0
	_panel.offset_right = 340.0
	_panel.offset_top = -300.0
	_panel.offset_bottom = 300.0
	_panel.add_theme_stylebox_override("panel", _mk_style(Color(0.12, 0.12, 0.17, 0.96), Color(0.3, 0.3, 0.4, 1), 2, 16))

	# tscn 의 고정 버튼들은 전부 제거(동적 생성으로 대체)
	for nm in ["Stage1Button", "Stage2Button", "Stage3Button", "MainMenuButton"]:
		var old := _panel.get_node_or_null(nm)
		if old:
			old.queue_free()

	# 타이틀 위치 보정
	var title := _panel.get_node_or_null("Title") as Label
	if title:
		title.offset_left = 0.0
		title.offset_right = 680.0
		title.offset_top = 24.0
		title.offset_bottom = 84.0
		title.add_theme_color_override("font_color", Color(1, 1, 1))
		title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		title.add_theme_constant_override("outline_size", 6)

	_nums = SceneManager.STAGES.keys()
	_nums.sort()
	_page_count = max(1, int(ceil(float(_nums.size()) / float(PER_PAGE))))
	# 마지막으로 해금된 스테이지가 있는 페이지에서 시작(편의)
	_page = clampi((SceneManager.max_unlocked - 1) / PER_PAGE, 0, _page_count - 1)
	_build_page()

## 현재 페이지의 버튼/네비게이션을 다시 그린다.
func _build_page() -> void:
	# Title 외 동적 노드 제거
	for c in _panel.get_children():
		if c.name != "Title":
			c.queue_free()

	var start := _page * PER_PAGE
	var end := mini(start + PER_PAGE, _nums.size())
	var grid_top := 104.0
	for idx in range(start, end):
		var n := int(_nums[idx])
		var slot := idx - start
		var col := slot % COLS
		var row := slot / COLS
		var btn := Button.new()
		btn.size = Vector2(286, 50)
		btn.position = Vector2(34 + col * 306, grid_top + row * 62)
		btn.focus_mode = Control.FOCUS_NONE
		_panel.add_child(btn)
		_setup_stage_button(btn, n)

	_build_nav()

## ◀이전 / 페이지표시 / 다음▶ + 메인메뉴
func _build_nav() -> void:
	var nav_y := 104.0 + 5 * 62 + 14.0   # 그리드(최대 5행) 아래

	var prev := Button.new()
	prev.text = "◀ 이전"
	prev.size = Vector2(120, 46)
	prev.position = Vector2(34, nav_y)
	prev.focus_mode = Control.FOCUS_NONE
	prev.disabled = _page <= 0
	_style_button(prev, C_BG, C_BORDER, Color(1, 1, 1))
	prev.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		_page = maxi(0, _page - 1)
		_build_page())
	_panel.add_child(prev)

	var page_lbl := Label.new()
	page_lbl.text = "%d / %d" % [_page + 1, _page_count]
	page_lbl.size = Vector2(200, 46)
	page_lbl.position = Vector2(240, nav_y)
	page_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	page_lbl.add_theme_font_size_override("font_size", 24)
	page_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	_panel.add_child(page_lbl)

	var nxt := Button.new()
	nxt.text = "다음 ▶"
	nxt.size = Vector2(120, 46)
	nxt.position = Vector2(526, nav_y)
	nxt.focus_mode = Control.FOCUS_NONE
	nxt.disabled = _page >= _page_count - 1
	_style_button(nxt, C_BG, C_BORDER, Color(1, 1, 1))
	nxt.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		_page = mini(_page_count - 1, _page + 1)
		_build_page())
	_panel.add_child(nxt)

	var main_btn := Button.new()
	main_btn.text = "메인 메뉴로"
	main_btn.size = Vector2(240, 46)
	main_btn.position = Vector2(220, nav_y + 56)
	main_btn.focus_mode = Control.FOCUS_NONE
	_style_button(main_btn, C_BG, C_BORDER, Color(1, 1, 1))
	main_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		SceneManager.go_to_main_menu())
	_panel.add_child(main_btn)

func _setup_stage_button(btn: Button, n: int) -> void:
	btn.add_theme_font_size_override("font_size", 24)
	var unlocked := SceneManager.is_unlocked(n)
	if not unlocked:
		btn.disabled = true
		btn.text = "Stage %d   🔒" % n
		_style_button(btn, C_LOCK_BG, Color(0.25, 0.25, 0.3, 1), Color(0.5, 0.5, 0.58))
		return
	# 클리어 여부 + 베스트 타임 표기
	var cleared := SceneManager.is_cleared(n)
	var label := "Stage %d" % n
	if cleared:
		var bt: int = int(SceneManager.best_time(n))
		label += "   ✓ %02d:%02d" % [bt / 60, bt % 60]
	btn.text = label
	# 클리어=청록 테두리 강조, 미클리어=마젠타 호버
	var border := C_CLEAR if cleared else C_BORDER
	_style_button(btn, C_BG, border, Color(1, 1, 1))
	btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		SceneManager.load_stage(n))

## 버튼에 카드형 스타일(노멀/호버/프레스/비활성) 일괄 적용.
func _style_button(btn: Button, bg: Color, border: Color, fg: Color) -> void:
	btn.add_theme_stylebox_override("normal", _mk_style(bg, border))
	btn.add_theme_stylebox_override("hover", _mk_style(C_BG_HOVER, C_ACCENT))
	btn.add_theme_stylebox_override("pressed", _mk_style(C_BG_PRESS, C_ACCENT))
	btn.add_theme_stylebox_override("disabled", _mk_style(C_LOCK_BG, Color(0.25, 0.25, 0.3, 1)))
	btn.add_theme_stylebox_override("focus", _mk_style(Color(0, 0, 0, 0), C_ACCENT))
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.58))

func _mk_style(bg: Color, border: Color, bw: int = 2, radius: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(bw)
	s.border_color = border
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s
