extends Control
## 스테이지 선택 화면.
## ▼ 2026-06-22 보강: 잠금/클리어 표시 + 베스트 타임 + 잠긴 스테이지 비활성화.

func _ready() -> void:
	var main_btn := get_node_or_null("Panel/MainMenuButton") as Button
	if main_btn:
		main_btn.pressed.connect(func() -> void:
			AudioManager.play_sfx("click")
			SceneManager.go_to_main_menu())

	for n in [1, 2, 3]:
		var btn := get_node_or_null("Panel/Stage%dButton" % n) as Button
		if btn == null:
			continue
		_setup_stage_button(btn, n)

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
