extends CanvasLayer
## 좌상단 플레이 기록 HUD (가로 배치).
## [ STAGE n ]  [ TIME 00:00 ]  [해골]  [ x0 ]
## 실제 값은 SceneManager(autoload)에 저장 → 스테이지를 넘어가도 유지된다.

@onready var _time_label: Label  = $Bar/Time
@onready var _death_label: Label = $Bar/Deaths
@onready var _stage_label: Label = $Bar/Stage

# ▼ 2026-06-28: 좌상단 '배터리형' 색 에너지 게이지(칸 분할, 손그림 느낌).
#   플레이어 색(흑/백)으로 채워지고, 색깔총을 쏠수록(빛과 함께) 칸이 줄었다가 시간이 지나면 회복.
#   값은 player.get_energy_ratio()/get_player_color() 에서 읽음(스테이지 넘어가도 새 플레이어로 자동 연결).
var _battery: BatteryGauge = null

func _ready() -> void:
	_build_battery()
	_layout_bar()
	# ▼ 2026-06-22 추가: 스테이지 진입 시 화면 중앙에 "STAGE n" 배너를 잠깐 띄움(장르 표준 연출)
	_show_stage_intro()

## ▼ 2026-06-28: 배터리형 게이지를 좌상단에 생성.
func _build_battery() -> void:
	_battery = BatteryGauge.new()
	_battery.position = Vector2(22, 14)
	_battery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_battery)

## ▼ 2026-06-28: 시간/스테이지/데스 바를 배터리 아래로 정렬(좌상단 클러스터, 게임 느낌).
func _layout_bar() -> void:
	var bar := get_node_or_null("Bar") as Control
	if bar:
		bar.position = Vector2(24, 84)

## 매 프레임 플레이어를 찾아 배터리 잔량·색을 갱신.
func _update_color_gauge() -> void:
	if _battery == null:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("get_energy_ratio"):
		return
	var is_white: bool = player.get_player_color() == ColorDefs.WHITE
	_battery.set_state(player.get_energy_ratio(), is_white)

func _process(_delta: float) -> void:
	# 경과 시간(초)을 분:초로 변환
	var t: int = int(SceneManager.run_time)
	_time_label.text  = "TIME  %02d:%02d" % [t / 60, t % 60]
	# 해골 아이콘 옆 "x죽은횟수"
	_death_label.text = "x%d" % SceneManager.death_count
	# ▼ 2026-06-22: 현재 스테이지 번호
	_stage_label.text = "STAGE %d" % _current_stage_num()
	# ▼ 2026-06-28: 색 에너지 게이지 갱신
	_update_color_gauge()

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
