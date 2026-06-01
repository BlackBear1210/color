extends Node
## 프로젝트 진입점. Main Scene 으로 설정된 씬(main.tscn)에 부착.
##
## ┌─ DEBUG_STAGE > 0  →  해당 스테이지로 바로 진입  (개발/테스트 중)
## └─ DEBUG_STAGE = 0  →  MainMenu 부터 정식 흐름    (출시 전에 0으로 변경)

const DEBUG_STAGE: int = 1   # ← 테스트할 스테이지 번호. 0 이면 MainMenu 시작.

func _ready() -> void:
	# _ready() 는 씬 트리에 추가되는 도중 호출되므로
	# 이 안에서 change_scene 을 바로 쓰면 remove_child 충돌 발생.
	# call_deferred 로 한 프레임 뒤에 실행해서 트리가 안정된 후 씬 전환.
	call_deferred("_start")

func _start() -> void:
	if DEBUG_STAGE > 0:
		SceneManager.load_stage(DEBUG_STAGE)
	else:
		SceneManager.go_to_main_menu()
