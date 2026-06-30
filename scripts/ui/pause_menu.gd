extends CanvasLayer
## ▼ 2026-06-22 신규: 전역 일시정지 메뉴 (Autoload).
##   - 스테이지 플레이 중 Esc(ui_cancel)로 열고 닫음. 열리면 get_tree().paused = true.
##   - 버튼: 계속하기 / 재시작 / 스테이지 선택 / 메인 메뉴.
##   - UI 는 코드로 구성(별도 씬 불필요). process_mode = ALWAYS 라 멈춘 상태에서도 동작.
## ▼ 2026-06-30 버그수정(Claude): 재시작/스테이지선택/메인메뉴 버튼이 visible=false 를 안 해서
##   화면 전환 후에도 일시정지 오버레이가 남고(=다음 화면 위에 떠 있음), 그 상태에선 _open 이 false 라
##   Esc 가 '닫기'가 아니라 '열기' 시도로 동작 → 안 닫혔다.
##   해결: ①모든 종료 경로에서 _close()(visible=false) 호출 ②Esc/배경 클릭은 '보이면 무조건 닫기'.

var _open: bool = false
var _dim: ColorRect = null


func _ready() -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	# 보이는 상태(정상 open 이든, 어떤 이유로 남아있든)면 무조건 닫는다.
	if _open or visible:
		_resume()
	elif _can_pause():
		_open = true
		get_tree().paused = true
		visible = true
		AudioManager.play_sfx("click")


## 스테이지 씬에서만 일시정지 허용(메뉴/클리어팝업 중에는 무시).
func _can_pause() -> bool:
	var s := get_tree().current_scene
	if s == null:
		return false
	return str(s.name).begins_with("stage_") and not get_tree().paused


func _resume() -> void:
	_close()
	AudioManager.play_sfx("click")


## 오버레이를 완전히 닫고 게임을 재개(공통).
func _close() -> void:
	_open = false
	visible = false
	get_tree().paused = false


## 종료 버튼 공통: 닫고(visible=false 포함) → 동작 실행. 이게 빠져서 오버레이가 남던 버그였음.
func _close_then(action: Callable) -> void:
	AudioManager.play_sfx("click")
	_close()
	action.call()


# ── UI 구성 ───────────────────────────────────────────────────────
func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.06, 0.06, 0.1, 0.6)
	_dim.anchor_right = 1.0
	_dim.anchor_bottom = 1.0
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	# ▼ 2026-06-30: 배경(어두운 영역) 클릭 시에도 닫히게(흔한 UX).
	_dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_resume())

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# 메뉴 카드 패널(라운드 + 마젠타 림)
	var panel := PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.09, 0.09, 0.11, 0.98)
	psb.set_corner_radius_all(18)
	psb.set_border_width_all(2)
	psb.border_color = Color(0.45, 0.47, 0.52, 0.7)   # ▼ 2026-06-30: 마젠타 → 회색 림
	psb.content_margin_left = 28
	psb.content_margin_right = 28
	psb.content_margin_top = 22
	psb.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", psb)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(320, 0)
	panel.add_child(box)

	var title := Label.new()
	title.text = "일시정지"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 8)
	box.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	box.add_child(spacer)

	_add_button(box, "계속하기", _resume)
	_add_button(box, "재시작", func() -> void: _close_then(SceneManager.restart_stage))
	_add_button(box, "스테이지 선택", func() -> void: _close_then(SceneManager.go_to_stage_select))
	_add_button(box, "메인 메뉴", func() -> void: _close_then(SceneManager.go_to_main_menu))


func _add_button(parent: Node, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", 24)
	b.focus_mode = Control.FOCUS_NONE
	# 카드형 스타일(스테이지 선택 화면과 톤 일치)
	# ▼ 2026-06-30: 마젠타 → 어두운 회색 톤
	b.add_theme_stylebox_override("normal", _btn_style(Color(0.14, 0.14, 0.16, 1), Color(0.30, 0.31, 0.35, 1)))
	b.add_theme_stylebox_override("hover", _btn_style(Color(0.22, 0.22, 0.25, 1), Color(0.62, 0.64, 0.70, 1)))
	b.add_theme_stylebox_override("pressed", _btn_style(Color(0.09, 0.09, 0.10, 1), Color(0.62, 0.64, 0.70, 1)))
	b.pressed.connect(cb)
	parent.add_child(b)


func _btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(10)
	s.set_border_width_all(2)
	s.border_color = border
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s
