extends Control
## ▼ 2026-06-22 신규: 메인 타이틀 메뉴.
##   COLOR 타이틀 + [시작하기 / 스테이지 선택 / 종료]. UI 는 코드로 구성.

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.10)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.custom_minimum_size = Vector2(360, 0)
	center.add_child(box)

	var title := Label.new()
	title.text = "COLOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 12)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "색을 바꿔 살아남아라"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	box.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	box.add_child(spacer)

	_btn(box, "시작하기", func() -> void:
		AudioManager.play_sfx("click")
		SceneManager.load_stage(1))
	_btn(box, "스테이지 선택", func() -> void:
		AudioManager.play_sfx("click")
		SceneManager.go_to_stage_select())
	_btn(box, "종료", func() -> void:
		AudioManager.play_sfx("click")
		get_tree().quit())

func _btn(parent: Node, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(cb)
	parent.add_child(b)
