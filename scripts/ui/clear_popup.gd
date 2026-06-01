extends CanvasLayer
## 스테이지 클리어 팝업.
## - 포탈이 이 팝업을 생성하고 next_stage_path 를 주입한다.
## - [다음 스테이지] : next_stage_path 가 있으면 해당 씬으로, 없으면 SceneManager.next_stage()
## - [스테이지 선택] : 스테이지 선택 화면으로 이동
##
## ※ process_mode = ALWAYS 라서 게임이 멈춰도 버튼이 동작한다.

@onready var _info:       Label  = $Panel/Info
@onready var _next_btn:   Button = $Panel/NextButton
@onready var _select_btn: Button = $Panel/SelectButton

## portal.gd 에서 주입. 비어 있으면 SceneManager 자동 처리.
var next_stage_path: String = ""

func _ready() -> void:
	# 클리어 순간 타이머 정지 + 게임 일시정지
	SceneManager.timing_active = false
	get_tree().paused = true

	# 클리어 기록 표시
	var t: int = int(SceneManager.run_time)
	_info.text = "클리어 시간 : %02d:%02d\n죽은 횟수 : %d" % [t / 60, t % 60, SceneManager.death_count]

	_next_btn.pressed.connect(_on_next)
	_select_btn.pressed.connect(_on_select)

func _on_next() -> void:
	get_tree().paused = false
	if not next_stage_path.is_empty():
		# 인스펙터에서 지정한 경로로 직접 이동
		SceneManager.timing_active = true
		get_tree().change_scene_to_file(next_stage_path)
	else:
		# SceneManager 가 current_stage + 1 로 자동 이동
		SceneManager.next_stage()

func _on_select() -> void:
	get_tree().paused = false
	SceneManager.go_to_stage_select()
