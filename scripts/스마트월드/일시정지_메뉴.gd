extends CanvasLayer
## ============================================================================
## [2026-08-02 신규] ESC 일시정지 메뉴
## ----------------------------------------------------------------------------
## ▣ 기능
##   · 계속하기        — 메뉴를 닫고 게임 재개
##   · 설정            — 밝기 슬라이더 (바꾸는 즉시 화면에 반영 + user:// 에 저장)
##   · 로비로 돌아가기 — scenes/lobby/lobby.tscn 으로 이동
##
## ▣ 왜 CanvasLayer 인가
##   카메라가 움직여도 UI 는 화면에 고정돼야 한다. CanvasLayer 안의 Control 은
##   월드 좌표가 아니라 화면 좌표를 쓴다.
##
## ▣ 일시정지 처리
##   `get_tree().paused = true` 는 트리 전체를 멈춘다. 그러면 메뉴 자신도 멈춰서
##   버튼이 안 눌린다. → 이 노드만 `PROCESS_MODE_ALWAYS` 로 둔다.
##
##   ⚠[2026-08-02 버그] 처음엔 `PROCESS_MODE_WHEN_PAUSED` 를 썼는데,
##      그건 "**멈춰 있을 때만** 동작"이라 평소엔 _input 조차 안 불린다.
##      → ESC 를 눌러도 메뉴가 절대 안 열렸다(자동 테스트가 잡아냄).
##      ALWAYS = 멈추든 안 멈추든 항상 동작. 여는 것도 닫는 것도 가능해진다.
##
## ▣ 입력을 왜 _input 에서 먹는가
##   ESC(ui_cancel)를 _unhandled_input 에서 받으면, 버튼이 포커스를 가진 상태에서
##   UI 가 먼저 소비해 버려 메뉴가 안 닫힌다. _input 에서 받고 즉시
##   set_input_as_handled() 로 아래로 안 흘려보낸다.
##
## ▣ 쓰는 법 (코드로 붙이기)
##   var 메뉴 := preload("res://scripts/스마트월드/일시정지_메뉴.gd").new()
##   add_child(메뉴)
##   메뉴.연결(어둠_CanvasModulate, 기준색)
## ============================================================================
class_name 일시정지메뉴

const 로비_경로 := "res://scenes/lobby/lobby.tscn"

var _모듈레이트: CanvasModulate = null
var _기준색: Color = Color.WHITE
var _밝기: float = 1.0

var _배경: ColorRect
var _판: PanelContainer
var _설정판: VBoxContainer
var _밝기_라벨: Label
var _전체화면: CheckBox        ## [2026-08-07] 인게임에서도 창/전체화면을 바꿀 수 있게
var _종료확인: ConfirmationDialog = null
var _열림: bool = false


func 연결(모듈레이트: CanvasModulate, 기준색: Color) -> void:
	_모듈레이트 = 모듈레이트
	_기준색 = 기준색
	_밝기 = 게임설정.밝기_불러오기()
	게임설정.밝기_적용(_모듈레이트, _기준색, _밝기)
	if _밝기_라벨:
		_밝기_라벨.text = _밝기_문구()


func _ready() -> void:
	layer = 100                                   # HUD(기본 1)보다 위
	process_mode = Node.PROCESS_MODE_ALWAYS       # 멈추든 안 멈추든 항상 입력을 받는다
	_UI_만들기()
	visible = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_토글()
		get_viewport().set_input_as_handled()


func _토글() -> void:
	_열림 = not _열림
	visible = _열림
	get_tree().paused = _열림
	if _열림:
		# 마우스를 보이게 — 게임 중에 커서를 숨기는 씬이 생겨도 메뉴에서는 보여야 한다
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_설정판.visible = false
	# 슬라이더가 포커스를 잡고 있으면 ESC 가 먹히지 않을 수 있어 포커스를 푼다
	var f := get_viewport().gui_get_focus_owner()
	if f:
		f.release_focus()


# ============================================================================
# UI 구성 — 씬 파일 없이 코드로 만든다
# ----------------------------------------------------------------------------
# .tscn 으로 만들면 디자이너가 고치기 쉽지만, 지금은 "어느 스테이지에나 한 줄로
# 붙는 것"이 더 중요해서 코드로 만들었다. 나중에 씬으로 옮겨도 연결() 규약만
# 지키면 스테이지 쪽 코드는 안 바뀐다.
# ============================================================================
func _UI_만들기() -> void:
	# 반투명 암막 — 뒤의 게임 화면을 눌러 메뉴에 집중시킨다
	_배경 = ColorRect.new()
	_배경.color = Color(0, 0, 0, 0.62)
	_배경.set_anchors_preset(Control.PRESET_FULL_RECT)
	_배경.mouse_filter = Control.MOUSE_FILTER_STOP   # 뒤쪽 클릭 차단
	add_child(_배경)

	var 가운데 := CenterContainer.new()
	가운데.set_anchors_preset(Control.PRESET_FULL_RECT)
	가운데.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(가운데)

	_판 = PanelContainer.new()
	가운데.add_child(_판)

	var 여백 := MarginContainer.new()
	for 변 in ["left", "right", "top", "bottom"]:
		여백.add_theme_constant_override("margin_" + 변, 34)
	_판.add_child(여백)

	var 세로 := VBoxContainer.new()
	세로.add_theme_constant_override("separation", 14)
	세로.custom_minimum_size = Vector2(360, 0)
	여백.add_child(세로)

	var 제목 := Label.new()
	제목.text = "일시정지"
	제목.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	제목.add_theme_font_size_override("font_size", 30)
	세로.add_child(제목)

	세로.add_child(HSeparator.new())

	세로.add_child(_버튼("계속하기", _토글))
	세로.add_child(_버튼("설정", _설정_토글))
	세로.add_child(_버튼("로비로 돌아가기", _로비로))
	# ★[2026-08-07 도형 요청] "esc를 누르면 설정이 나와서 끌 수 있게"
	#   게임을 끄는 길이 로비를 거쳐야만 있었다(로비 → 나가기). 두 번 이동해야 해서
	#   "끄고 싶은데 못 끄는" 상태였다. 여기서 바로 끌 수 있게 한다.
	세로.add_child(HSeparator.new())
	var 종료버튼 := _버튼("게임 종료", _종료_확인)
	# 실수로 누르면 작업이 날아가므로 색으로 구분한다 (한 번 더 묻기도 한다)
	종료버튼.add_theme_color_override("font_color", Color(1.0, 0.72, 0.72))
	세로.add_child(종료버튼)

	# ── 설정 패널 (평소엔 접혀 있음) ──
	_설정판 = VBoxContainer.new()
	_설정판.visible = false
	_설정판.add_theme_constant_override("separation", 8)
	세로.add_child(_설정판)

	_설정판.add_child(HSeparator.new())

	_밝기_라벨 = Label.new()
	_밝기_라벨.text = _밝기_문구()
	_설정판.add_child(_밝기_라벨)

	var 슬라이더 := HSlider.new()
	슬라이더.min_value = 게임설정.밝기_최소
	슬라이더.max_value = 게임설정.밝기_최대
	슬라이더.step = 0.05
	슬라이더.value = _밝기
	슬라이더.custom_minimum_size = Vector2(0, 26)
	슬라이더.value_changed.connect(_밝기_바뀜)
	_설정판.add_child(슬라이더)

	# ── [2026-08-07] 전체화면 토글 ──
	# 로비 설정에만 있던 항목이라, 인게임에서 창 모드를 바꾸려면 로비까지 나가야 했다.
	# 로비와 **같은 파일**(user://settings.cfg)을 읽고 쓰므로 설정이 서로 어긋나지 않는다.
	_전체화면 = CheckBox.new()
	_전체화면.text = "전체화면"
	_전체화면.set_pressed_no_signal(게임설정.전체화면_불러오기())
	_전체화면.toggled.connect(_전체화면_바뀜)
	_설정판.add_child(_전체화면)

	var 안내 := Label.new()
	안내.text = "설정은 자동 저장됩니다 · ESC 로 닫기"
	안내.add_theme_font_size_override("font_size", 13)
	안내.modulate = Color(1, 1, 1, 0.6)
	_설정판.add_child(안내)


func _버튼(글자: String, 콜백: Callable) -> Button:
	var b := Button.new()
	b.text = 글자
	b.custom_minimum_size = Vector2(0, 42)
	b.pressed.connect(콜백)
	return b


func _설정_토글() -> void:
	_설정판.visible = not _설정판.visible


func _밝기_문구() -> String:
	return "밝기   %d%%" % int(round(_밝기 * 100.0))


func _밝기_바뀜(값: float) -> void:
	_밝기 = 값
	_밝기_라벨.text = _밝기_문구()
	# 항상 **기준색에서 다시 계산**한다. 현재 색에 곱하면 슬라이더를 움직일 때마다
	# 값이 누적돼 화면이 점점 어두워진다.
	게임설정.밝기_적용(_모듈레이트, _기준색, _밝기)
	게임설정.밝기_저장(_밝기)


## [2026-08-07] 전체화면 토글 — 즉시 반영 + 저장.
func _전체화면_바뀜(켬: bool) -> void:
	게임설정.전체화면_적용(켬)
	게임설정.전체화면_저장(켬)


## [2026-08-07] 게임 종료 — 한 번 더 묻는다.
## 실수로 눌러 진행 상황이 날아가는 게 가장 흔한 불만이라 확인 창을 둔다.
## ⚠ 다이얼로그도 `PROCESS_MODE_ALWAYS` 여야 한다. 트리가 멈춰 있어서
##   기본 모드면 버튼이 안 눌린다(메뉴 자신과 같은 함정 — 2026-08-02 기록).
func _종료_확인() -> void:
	if _종료확인 == null:
		_종료확인 = ConfirmationDialog.new()
		_종료확인.title = "게임 종료"
		_종료확인.dialog_text = "게임을 종료할까요?\n저장되지 않은 진행은 사라집니다."
		_종료확인.ok_button_text = "종료"
		_종료확인.cancel_button_text = "취소"
		_종료확인.process_mode = Node.PROCESS_MODE_ALWAYS
		_종료확인.confirmed.connect(_정말_종료)
		add_child(_종료확인)
	_종료확인.popup_centered()


func _정말_종료() -> void:
	# 종료 전에 일시정지를 푼다. 안 풀면 종료 처리 중 트리가 멈춰 있어
	# 정리 콜백(_notification NOTIFICATION_WM_CLOSE_REQUEST 등)이 안 도는 경우가 있다.
	get_tree().paused = false
	get_tree().quit()


func _로비로() -> void:
	# 씬을 바꾸기 전에 반드시 일시정지를 풀어야 한다. 안 그러면 로비도 멈춘 채로 뜬다.
	get_tree().paused = false
	if not ResourceLoader.exists(로비_경로):
		push_error("로비 씬을 찾을 수 없다: %s" % 로비_경로)
		return
	get_tree().change_scene_to_file(로비_경로)
