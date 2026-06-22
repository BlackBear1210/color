extends CanvasLayer
## 좌상단 플레이 기록 HUD (가로 배치).
## [ STAGE n ]  [ TIME 00:00 ]  [해골]  [ x0 ]
## 실제 값은 SceneManager(autoload)에 저장 → 스테이지를 넘어가도 유지된다.

@onready var _time_label: Label  = $Bar/Time
@onready var _death_label: Label = $Bar/Deaths
@onready var _stage_label: Label = $Bar/Stage

func _ready() -> void:
	# ▼ 2026-06-22 추가: 스테이지 진입 시 화면 중앙에 "STAGE n" 배너를 잠깐 띄움(장르 표준 연출)
	_show_stage_intro()

func _process(_delta: float) -> void:
	# 경과 시간(초)을 분:초로 변환
	var t: int = int(SceneManager.run_time)
	_time_label.text  = "TIME  %02d:%02d" % [t / 60, t % 60]
	# 해골 아이콘 옆 "x죽은횟수"
	_death_label.text = "x%d" % SceneManager.death_count
	# ▼ 2026-06-22: 현재 스테이지 번호
	_stage_label.text = "STAGE %d" % _current_stage_num()

## 현재 스테이지 번호. SceneManager 값이 있으면 사용, 없으면(직접 실행 등) 씬 이름에서 추출.
func _current_stage_num() -> int:
	if SceneManager.current_stage > 0:
		return SceneManager.current_stage
	var scene := get_tree().current_scene
	if scene:
		var digits := ""
		for c in str(scene.name):
			if c >= "0" and c <= "9":
				digits += c
		if digits != "":
			return int(digits)
	return 1

## ▼ 2026-06-22 신규: 스테이지 진입 배너("STAGE n") — 팝 인 → 잠깐 유지 → 페이드 아웃 후 제거.
func _show_stage_intro() -> void:
	var n := _current_stage_num()
	var lbl := Label.new()
	lbl.text = "STAGE %d" % n
	# 화면 전체에 깔고 가운데 정렬
	lbl.anchor_right = 1.0
	lbl.anchor_bottom = 1.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 96)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 14)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)

	# 팝 인 → 유지 → 페이드 아웃
	lbl.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.9)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(lbl.queue_free)
