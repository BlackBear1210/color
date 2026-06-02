extends Control
## 스테이지 선택 화면.
## 각 스테이지 버튼을 누르면 해당 스테이지로 이동하고,
## 메인 메뉴 버튼으로 타이틀로 돌아간다.

func _ready() -> void:
	# 버튼 시그널 연결 (씬에 버튼이 있을 경우)
	var main_btn := get_node_or_null("Panel/MainMenuButton") as Button
	if main_btn:
		main_btn.pressed.connect(_on_main_menu)

	var s1 := get_node_or_null("Panel/Stage1Button") as Button
	if s1:
		s1.pressed.connect(func(): SceneManager.load_stage(1))

	var s2 := get_node_or_null("Panel/Stage2Button") as Button
	if s2:
		s2.pressed.connect(func(): SceneManager.load_stage(2))

	var s3 := get_node_or_null("Panel/Stage3Button") as Button
	if s3:
		s3.pressed.connect(func(): SceneManager.load_stage(3))


func _on_main_menu() -> void:
	SceneManager.go_to_main_menu()
