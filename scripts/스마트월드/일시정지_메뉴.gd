extends CanvasLayer
class_name 일시정지메뉴
## 메뉴만 계속 처리해 게임 시간과 HUD 애니메이션을 함께 멈춘다.
const 설정 := preload("res://scripts/스마트월드/게임설정.gd")
const 장목록 := preload("res://scripts/스마트월드/챕터.gd")
const 기록형 := preload("res://scripts/ui/실행_기록.gd")
const 폰트 := preload("res://assets/fonts/NotoSerifKR/NotoSerifKR.ttf")
var _모듈레이트: CanvasModulate
var _기준색 := Color.WHITE
var _밝기: float = 1.0
var _열림: bool = false
var _화면: String = "메인"
var _루트: Control
var _영역: VBoxContainer
var _목록: VBoxContainer
var _제목: Label
var _오류: Label
var _뒤로버튼: Button
var _종료확인: ConfirmationDialog
var _이전_마우스: int
var _이동중: bool = false

func 연결(모듈레이트: CanvasModulate, 기준색: Color) -> void:
	_모듈레이트 = 모듈레이트
	_기준색 = 기준색
	_밝기 = 설정.밝기_불러오기()
	설정.밝기_적용(_모듈레이트, _기준색, _밝기)

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_UI_만들기()
	visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if _종료확인 and _종료확인.visible:
			_종료확인.hide()
		elif _열림 and _화면 != "메인":
			_보이기("메인")
		else:
			_토글()
		get_viewport().set_input_as_handled()

func _토글() -> void:
	if _이동중:
		return
	_열림 = not _열림
	visible = _열림
	get_tree().paused = _열림
	if _열림:
		_이전_마우스 = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_보이기("메인")
	else:
		Input.mouse_mode = _이전_마우스

func _UI_만들기() -> void:
	_루트 = Control.new()
	_루트.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_루트)
	var 테마 := Theme.new()
	# 메뉴도 가변 폰트의 가장 얇은 기본값 대신 읽기 쉬운 보통 굵기를 쓴다.
	var 메뉴폰트 := FontVariation.new()
	메뉴폰트.base_font = 폰트
	메뉴폰트.variation_opentype = {"wght": 500.0}
	테마.default_font = 메뉴폰트
	테마.default_font_size = 22
	for 상태 in ["normal", "hover", "pressed", "focus", "disabled"]:
		var 모양 := StyleBoxFlat.new()
		모양.bg_color = Color(1, 1, 1, 0.07) if 상태 in ["hover", "focus"] else Color(0, 0, 0, 0)
		모양.content_margin_left = 20
		모양.content_margin_right = 20
		모양.content_margin_top = 8
		모양.content_margin_bottom = 8
		if 상태 == "focus":
			모양.set_border_width_all(1)
			모양.border_color = Color(0.7, 0.7, 0.7, 0.8)
		테마.set_stylebox(상태, "Button", 모양)
	_루트.theme = 테마
	var 암막 := ColorRect.new()
	암막.color = Color(0.015, 0.015, 0.018, 0.94)
	암막.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_루트.add_child(암막)
	_영역 = VBoxContainer.new()
	_영역.add_theme_constant_override("separation", 18)
	_루트.add_child(_영역)
	_제목 = Label.new()
	_제목.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_제목.add_theme_font_size_override("font_size", 32)
	_영역.add_child(_제목)
	var 스크롤 := ScrollContainer.new()
	스크롤.size_flags_vertical = Control.SIZE_EXPAND_FILL
	스크롤.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_영역.add_child(스크롤)
	_목록 = VBoxContainer.new()
	_목록.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_목록.add_theme_constant_override("separation", 10)
	스크롤.add_child(_목록)
	_오류 = Label.new()
	_오류.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_오류.add_theme_font_size_override("font_size", 17)
	_영역.add_child(_오류)
	_뒤로버튼 = _버튼("뒤로", func(): _보이기("메인"))
	_영역.add_child(_뒤로버튼)
	get_viewport().size_changed.connect(_배치)
	_배치()

func _배치() -> void:
	# [2026-10-09 Codex] 씬 교체 후 옛 메뉴는 트리에서 빠진다. size_changed/화면 전환의 남은 호출은 배치하지 않는다.
	if _이동중 or not is_inside_tree() or not is_instance_valid(_영역) or not is_instance_valid(_목록):
		return
	var 뷰 := get_viewport()
	if 뷰 == null:
		return
	var 화면크기 := 뷰.get_visible_rect().size
	var 폭 := minf(720.0 if _화면 != "메인" else 360.0, 화면크기.x - 48.0)
	var 높이 := minf(640.0, 화면크기.y - 48.0)
	_영역.position = (화면크기 - Vector2(폭, 높이)) * 0.5
	_영역.size = Vector2(폭, 높이)
	var 그리드 := _목록.get_node_or_null("그리드") as GridContainer
	if 그리드:
		그리드.columns = 2 if 폭 >= 560 else 1

func _버튼(문구: String, 콜백: Callable) -> Button:
	var b := Button.new()
	b.text = 문구
	b.custom_minimum_size.y = 52
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(콜백)
	return b

func _보이기(화면: String) -> void:
	_화면 = 화면
	for 자식 in _목록.get_children():
		_목록.remove_child(자식)
		자식.queue_free()
	_오류.text = ""
	_뒤로버튼.visible = 화면 != "메인"
	_제목.text = "일시정지" if 화면 == "메인" else 화면
	match 화면:
		"메인":
			_목록.add_child(_버튼("계속", _토글))
			for 이름 in ["스테이지 선택", "설정", "시간 기록", "사망 기록"]:
				_목록.add_child(_버튼(이름, _보이기.bind(이름)))
			_목록.add_child(_버튼("게임 종료", _종료_확인))
		# [2026-10-09 Claude] 스테이지 선택 = 퍼즐 보드(조각이 실로 이어진 화면) — 예전 칸 목록(_스테이지_만들기)은 남겨 둔다
		"스테이지 선택":
			# 같은 사진 지도에서 현재 플레이하는 챕터를 연다.
			게임진행.선택_쳅터 = 2 if get_parent().scene_file_path.contains("world_2_클로드") else 1
			# [2026-10-09 Codex] 선택창으로 이동하면 이전 메뉴의 배치·예약 포커스가 더 이상 유효하지 않다.
			var 경로 := 게임진행.지도_씬 if get_parent().scene_file_path.contains("world_2_클로드") else 게임진행.보드_씬
			_스테이지_이동(경로)
			return
		"설정": _설정_만들기()
		"시간 기록", "사망 기록": _기록_만들기(화면 == "시간 기록")
	_배치()
	# 화면 교체 뒤 첫 활성 버튼에 포커스를 주어 키보드로 계속 탐색한다.
	call_deferred("_첫_포커스")

func _첫_포커스() -> void:
	# 씬 교체는 즉시 기존 메뉴를 트리에서 빼므로 예약된 포커스 작업을 중단한다.
	if not is_inside_tree() or _이동중:
		return
	for 버튼 in _목록.find_children("*", "BaseButton", true, false):
		if not 버튼.disabled:
			버튼.grab_focus()
			return
	_뒤로버튼.grab_focus()

func _스테이지_만들기() -> void:
	var 그리드 := GridContainer.new()
	그리드.name = "그리드"
	그리드.columns = 2
	그리드.add_theme_constant_override("h_separation", 16)
	그리드.add_theme_constant_override("v_separation", 16)
	_목록.add_child(그리드)
	for 항목 in 장목록.스테이지표:
		var 경로 := String(항목["씬"])
		var b := _버튼(String(항목["이름"]), _스테이지_이동.bind(경로))
		b.custom_minimum_size.y = 96
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.disabled = not ResourceLoader.exists(경로, "PackedScene")
		if b.disabled:
			b.text += "\n준비 중"
		그리드.add_child(b)

func _스테이지_이동(경로: String) -> void:
	if _이동중:
		return
	# 교체 전에 리소스를 검증하고 실패하면 메뉴와 일시정지를 그대로 유지한다.
	if not ResourceLoader.exists(경로, "PackedScene"):
		_오류.text = "스테이지를 찾을 수 없습니다."
		return
	var 씬 := load(경로) as PackedScene
	if 씬 == null:
		_오류.text = "스테이지를 불러오지 못했습니다."
		return
	_이동중 = true
	# 성공하면 이 노드는 즉시 트리에서 빠진다. 교체 전에 SceneTree 참조를 잡아 둔다.
	var 트리 := get_tree()
	var 결과 := 트리.change_scene_to_packed(씬)
	if 결과 != OK:
		_이동중 = false
		_오류.text = "이동 실패: " + error_string(결과)
		return
	# 메뉴 이동은 완료가 아니다. 새 스테이지에서 새 실행을 시작한다.
	트리.paused = false
	Input.mouse_mode = _이전_마우스

func _설정_만들기() -> void:
	var 밝기글 := Label.new()
	밝기글.text = "밝기  %d%%" % roundi(_밝기 * 100)
	_목록.add_child(밝기글)
	var 슬라이더 := HSlider.new()
	슬라이더.min_value = 설정.밝기_최소
	슬라이더.max_value = 설정.밝기_최대
	슬라이더.step = 0.05
	슬라이더.value = _밝기
	슬라이더.custom_minimum_size.y = 44
	슬라이더.value_changed.connect(func(값: float):
		_밝기 = 값
		밝기글.text = "밝기  %d%%" % roundi(값 * 100)
		설정.밝기_적용(_모듈레이트, _기준색, 값)
		설정.밝기_저장(값))
	_목록.add_child(슬라이더)
	var 전체 := CheckBox.new()
	전체.text = "전체화면"
	전체.button_pressed = 설정.전체화면_불러오기()
	전체.toggled.connect(func(켬: bool):
		설정.전체화면_적용(켬)
		설정.전체화면_저장(켬))
	_목록.add_child(전체)
	var 안내 := CheckBox.new()
	안내.text = "조작 안내 표시"
	안내.button_pressed = 설정.조작안내_불러오기()
	안내.toggled.connect(func(켬: bool):
		설정.조작안내_저장(켬)
		get_tree().set_group("조작안내", "visible", 켬))
	_목록.add_child(안내)
	# 각 숫자를 독립적으로 숨길 수 있어 구체와 기록 계산을 함께 꺼 버리지 않는다.
	var 표시 := 설정.HUD_표시_불러오기()
	for 항목 in [["탄수", "탄 수 표시"], ["사망수", "사망 수 표시"], ["시간", "플레이 시간 표시"]]:
		var 체크 := CheckBox.new()
		체크.name = "표시_" + 항목[0]
		체크.text = 항목[1]
		체크.button_pressed = 표시[항목[0]]
		체크.toggled.connect(_HUD_표시_바뀜.bind(항목[0]))
		_목록.add_child(체크)

func _HUD_표시_바뀜(켬: bool, 항목: String) -> void:
	var 결과 := 설정.HUD_표시_저장(항목, 켬)
	if 결과 != OK:
		_오류.text = "표시 설정을 저장하지 못했습니다."
		var 체크 := _목록.get_node_or_null("표시_" + 항목) as CheckBox
		if 체크:
			체크.set_pressed_no_signal(not 켬)
		return
	get_tree().call_group("페인트HUD_표시", "표시_적용", 설정.HUD_표시_불러오기())

func _기록_만들기(시간기록: bool) -> void:
	var cfg := 기록형.불러오기()
	var 키 := "최단시간" if 시간기록 else "최소사망"
	for 항목 in 장목록.스테이지표:
		var 행 := Label.new()
		var 기록: Dictionary = cfg.get_value(String(항목["씬"]), 키, {})
		var 값 := "완료 기록 없음"
		if not 기록.is_empty():
			값 = 기록형.시간_문자(float(기록["초"])) if 시간기록 else "%d회" % int(기록["사망"])
		행.text = "%s\n%s" % [항목["이름"], 값]
		행.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		행.custom_minimum_size.y = 86
		_목록.add_child(행)
	var 실행 := get_parent().get_node_or_null("실행기록")
	if 실행 and 실행.저장_오류 != OK:
		_오류.text = "최근 완료 기록을 저장하지 못했습니다."

func _종료_확인() -> void:
	if not _종료확인:
		_종료확인 = ConfirmationDialog.new()
		_종료확인.title = "게임 종료"
		_종료확인.dialog_text = "게임을 종료할까요?"
		_종료확인.ok_button_text = "종료"
		_종료확인.cancel_button_text = "취소"
		_종료확인.confirmed.connect(func(): get_tree().quit())
		add_child(_종료확인)
	_종료확인.popup_centered()
