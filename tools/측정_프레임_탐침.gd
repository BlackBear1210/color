extends Node
## [2026-09-30 Claude] 프레임 한 장 안에서 스크립트 _process / _physics_process 가 쓴 시간을 직접 잰다.
## Performance.TIME_PROCESS 는 1 초마다 갱신되는 평균이라 튀는 한 프레임을 못 잡는다.
## 쓰는 법: 탐침.new() 두 개를 만들어 하나는 처음(priority 최소), 하나는 끝(최대)에 둔다.
var 끝쪽 := false
var 짝: Node
var 처리_시작 := 0
var 물리_시작 := 0
var 처리_ms := 0.0
var 물리_ms := 0.0   ## 이 프레임에 돈 물리 틱 전부의 합

func _ready() -> void:
	process_priority = 2147483647 if 끝쪽 else -2147483648
	process_physics_priority = process_priority
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_d: float) -> void:
	if 끝쪽:
		짝.처리_ms = float(Time.get_ticks_usec() - 짝.처리_시작) / 1000.0
	else:
		처리_시작 = Time.get_ticks_usec()

func _physics_process(_d: float) -> void:
	if 끝쪽:
		짝.물리_ms += float(Time.get_ticks_usec() - 짝.물리_시작) / 1000.0
	else:
		물리_시작 = Time.get_ticks_usec()
