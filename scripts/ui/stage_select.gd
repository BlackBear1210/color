extends Control
## 스테이지 선택 화면.
## ▼ 2026-06-22 보강: 잠금/클리어 표시 + 베스트 타임 + 잠긴 스테이지 비활성화.
## ▼ 2026-06-28 수정: 버튼을 [1,2,3] 하드코딩이 아니라 SceneManager.STAGES 전체에서 '동적 생성'.
##   → 스테이지 4~10 을 추가해도 선택 화면에 자동으로 나타난다(이전엔 4스테이지 선택 불가 버그).

func _ready() -> void:
	var panel := get_node_or_null("Panel")
	if panel == null:
		return

	# 기존 고정 버튼(Stage1~3Button)은 제거하고 아래에서 동적 생성
	for nm in ["Stage1Button", "Stage2Button", "Stage3Button"]:
		var old := panel.get_node_or_null(nm)
		if old:
			old.queue_free()

	# 모든 스테이지 버튼을 2열 그리드로 동적 생성(정렬된 STAGES 키)
	var nums: Array = SceneManager.STAGES.keys()
	nums.sort()
	var i := 0
	for n in nums:
		var btn := Button.new()
		btn.add_theme_font_size_override("font_size", 24)
		var col := i % 2
		var row := i / 2
		btn.position = Vector2(60 + col * 300, 100 + row * 64)
		btn.size = Vector2(260, 54)
		panel.add_child(btn)
		_setup_stage_button(btn, int(n))
		i += 1

	# 메인 메뉴 버튼: 그리드 아래로 재배치
	var main_btn := panel.get_node_or_null("MainMenuButton") as Button
	if main_btn:
		var rows := int((nums.size() + 1) / 2)
		main_btn.position = Vector2(200, 100 + rows * 64 + 20)
		main_btn.pressed.connect(func() -> void:
			AudioManager.play_sfx("click")
			SceneManager.go_to_main_menu())

func _setup_stage_button(btn: Button, n: int) -> void:
	var unlocked := SceneManager.is_unlocked(n)
	btn.disabled = not unlocked
	if not unlocked:
		btn.text = "Stage %d  (잠김)" % n
		return
	# 클리어 여부 + 베스트 타임 표기
	var label := "Stage %d" % n
	if SceneManager.is_cleared(n):
		var bt: int = int(SceneManager.best_time(n))
		label += "  ✓ %02d:%02d" % [bt / 60, bt % 60]
	btn.text = label
	btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		SceneManager.load_stage(n))
