extends CanvasLayer
## ▼ 2026-06-22 신규: 전역 일시정지 메뉴 (Autoload).
##   - 스테이지 플레이 중 Esc(ui_cancel)로 열고 닫음. 열리면 get_tree().paused = true.
##   - 버튼: 계속하기 / 재시작 / 스테이지 선택 / 메인 메뉴.
##   - UI 는 코드로 구성(별도 씬 불필요). process_mode = ALWAYS 라 멈춘 상태에서도 동작.

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
	if _open:
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
	_open = false
	visible = false
	get_tree().paused = false
	AudioManager.play_sfx("click")


# ── UI 구성 ───────────────────────────────────────────────────────
func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.anchor_right = 1.0
	_dim.anchor_bottom = 1.0
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(320, 0)
	center.add_child(box)

	var title := Label.new()
	title.text = "일시정지"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 10)
	box.add_child(title)

	_add_button(box, "계속하기", _resume)
	_add_button(box, "재시작", func() -> void:
		AudioManager.play_sfx("click")
		_open = false
		get_tree().paused = false
		SceneManager.restart_stage())
	_add_button(box, "스테이지 선택", func() -> void:
		AudioManager.play_sfx("click")
		_open = false
		get_tree().paused = false
		SceneManager.go_to_stage_select())
	_add_button(box, "메인 메뉴", func() -> void:
		AudioManager.play_sfx("click")
		_open = false
		get_tree().paused = false
		SceneManager.go_to_main_menu())


func _add_button(parent: Node, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(cb)
	parent.add_child(b)
