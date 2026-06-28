extends CanvasLayer
## 스테이지 클리어 팝업.
## - 포탈이 이 팝업을 생성하고 next_stage_path 를 주입한다.
## - [다음 스테이지] : next_stage_path 가 있으면 해당 씬으로, 없으면 SceneManager.next_stage()
## - [스테이지 선택] : 스테이지 선택 화면으로 이동
##
## ▼ 2026-06-22 보강: 클리어 기록 저장(record_clear) + 베스트타임/신기록/메달 표시 + 클리어 효과음.
## ※ process_mode = ALWAYS 라서 게임이 멈춰도 버튼이 동작한다.

@onready var _title:      Label  = $Panel/Title
@onready var _info:       Label  = $Panel/Info
@onready var _next_btn:   Button = $Panel/NextButton
@onready var _select_btn: Button = $Panel/SelectButton

## portal.gd 에서 주입. 비어 있으면 SceneManager 자동 처리.
var next_stage_path: String = ""

func _ready() -> void:
	# 클리어 순간 타이머 정지 + 게임 일시정지
	SceneManager.timing_active = false
	get_tree().paused = true
	AudioManager.play_sfx("portal")

	# ▼ 기록 저장 + 결과 계산
	var n: int = SceneManager.current_stage
	var r := SceneManager.record_clear(n) if n > 0 else {"time": SceneManager.run_time, "best": 0.0, "is_record": false}
	var ct: int = int(r["time"])
	var bt: int = int(r["best"])

	var medal := _medal(float(r["time"]))
	var record_line := "  ★ 신기록!" if r.get("is_record", false) else ""
	_info.text = "클리어 시간 : %02d:%02d%s\n베스트 : %02d:%02d   |   등급 : %s\n죽은 횟수 : %d" % [
		ct / 60, ct % 60, record_line, bt / 60, bt % 60, medal, SceneManager.death_count
	]

	# 다음 스테이지가 있는지 판단(명시 경로 or STAGES 에 current+1 존재)
	if next_stage_path.is_empty() and not SceneManager.STAGES.has(n + 1):
		_title.text = "ALL CLEAR!"
		_next_btn.text = "메인 메뉴"
		_next_btn.pressed.connect(func() -> void:
			AudioManager.play_sfx("click")
			get_tree().paused = false
			call_deferred("_do_main_menu"))
	else:
		_next_btn.pressed.connect(_on_next)
	_select_btn.pressed.connect(_on_select)

func _do_main_menu() -> void:
	SceneManager.go_to_main_menu()

## 클리어 타임으로 간단 등급 부여(연출용).
func _medal(t: float) -> String:
	if t <= 25.0:
		return "금"
	elif t <= 45.0:
		return "은"
	return "동"

func _on_next() -> void:
	AudioManager.play_sfx("click")
	get_tree().paused = false
	# ▼ 2026-06-28 (버그수정): 직접 change_scene_to_file 대신 SceneManager 경유로 이동.
	#   → current_stage 가 갱신되어 다음 스테이지 HUD('STAGE n')가 정상으로 바뀜 + 페이드 전환 일관성.
	if not next_stage_path.is_empty():
		call_deferred("_change_to", next_stage_path)
	else:
		call_deferred("_do_next_stage")

func _on_select() -> void:
	AudioManager.play_sfx("click")
	get_tree().paused = false
	call_deferred("_do_select")

# ── 씬 전환 헬퍼 (call_deferred 로만 호출) ──────────────────────
## ▼ 2026-06-28: SceneManager 경유(경로→스테이지번호 역추적)로 current_stage 갱신 + 페이드.
func _change_to(path: String) -> void:
	SceneManager.go_to_stage_by_path(path)

func _do_next_stage() -> void:
	SceneManager.next_stage()

func _do_select() -> void:
	SceneManager.go_to_stage_select()
