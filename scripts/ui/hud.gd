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

# ▼ 2026-06-30(Claude): 인트로 배너에 띄울 스테이지 이름표.
const STAGE_NAMES: Dictionary = {
	1: "첫 색", 2: "색을 바꿔라", 3: "미는 힘", 4: "내리막", 5: "그려진 발판",
	6: "떨어지는 천장", 7: "흔들다리", 8: "솟아오르는 바닥", 9: "거울 발판", 10: "빛의 복도",
	11: "회색의 늪", 12: "무너지는 길", 13: "천칭", 14: "빔 회랑", 15: "반사의 방",
}

func _ready() -> void:
	_build_backdrop()   # ▼ 2026-06-30: 좌상단 HUD 배경 칩(반투명 라운드 패널)
	_build_battery()
	_layout_bar()
	# ▼ 2026-06-22 추가: 스테이지 진입 시 화면 중앙에 "STAGE n" 배너를 잠깐 띄움(장르 표준 연출)
	_show_stage_intro()

## ▼ 2026-06-30(Claude): 배터리+바 클러스터 뒤에 깔리는 반투명 라운드 패널.
##   좌상단 정보가 배경과 섞여 안 보이던 걸 정리하고 '게임 HUD' 느낌을 준다.
func _build_backdrop() -> void:
	var bg := Panel.new()
	bg.position = Vector2(10, 8)
	bg.size = Vector2(360, 150)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.09, 0.6)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.45, 0.47, 0.52, 0.55)   # ▼ 2026-06-30: 마젠타 → 회색 림(어두운 톤)
	bg.add_theme_stylebox_override("panel", sb)
	add_child(bg)
	move_child(bg, 0)   # 배터리/바 뒤로 보내기

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

## ▼ 2026-06-22 신규 / 2026-06-30 개선(Claude): 스테이지 진입 배너.
##   "STAGE n" + 스테이지 이름 + 마젠타 밑줄. 스케일 팝 인 → 유지 → 페이드 아웃.
func _show_stage_intro() -> void:
	var n := _current_stage_num()

	# 중앙 컨테이너(스케일 팝의 기준이 되도록 pivot 중앙)
	var root := Control.new()
	root.anchor_left = 0.5
	root.anchor_top = 0.5
	root.anchor_right = 0.5
	root.anchor_bottom = 0.5
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var num := Label.new()
	num.text = "STAGE %d" % n
	num.position = Vector2(-400, -120)
	num.size = Vector2(800, 120)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.add_theme_font_size_override("font_size", 92)
	num.add_theme_color_override("font_color", Color(1, 1, 1))
	num.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	num.add_theme_constant_override("outline_size", 14)
	root.add_child(num)

	# ▼ 2026-06-30: 밑줄 마젠타 → 밝은 회색(어두운 톤 유지)
	var line := ColorRect.new()
	line.color = Color(0.7, 0.72, 0.78, 1)
	line.position = Vector2(-130, 8)
	line.size = Vector2(260, 5)
	root.add_child(line)

	var name_txt: String = STAGE_NAMES.get(n, "")
	if name_txt != "":
		var sub := Label.new()
		sub.text = name_txt
		sub.position = Vector2(-400, 18)
		sub.size = Vector2(800, 50)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_font_size_override("font_size", 38)
		sub.add_theme_color_override("font_color", Color(0.9, 0.9, 0.98))
		sub.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		sub.add_theme_constant_override("outline_size", 8)
		root.add_child(sub)

	# 스케일 팝 인 → 유지 → 페이드 아웃
	root.modulate.a = 0.0
	root.scale = Vector2(0.85, 0.85)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(root, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	tw.tween_interval(0.95)
	tw.tween_property(root, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(root.queue_free)
