extends Node
## 씬 전환 전담 싱글톤 (Autoload).
## 어디서든 SceneManager.load_stage(1) 처럼 호출해서 씬을 바꿀 수 있음.

# ── 스테이지 번호 → 씬 경로 테이블 ──────────────────────────────
# 스테이지가 늘어나면 여기에만 추가하면 됨.
const STAGES: Dictionary = {
	1:  "res://scenes/world_1/stage_1/stage_1.tscn",
	2:  "res://scenes/world_1/stage_2/stage_2.tscn",
	3:  "res://scenes/world_1/stage_3/stage_3.tscn",
	# ... 30개까지 추가 예정
}

# 현재 플레이 중인 스테이지 번호 (next_stage() 에서 사용)
var current_stage: int = 0

# ── 플레이 기록 (HUD 표시용) ──────────────────────────────────────
# autoload 라서 씬을 바꿔도 값이 유지됨 → 스테이지를 넘어가도 시간/죽음이 누적됨.
var run_time: float    = 0.0     # 경과 시간(초). _process 에서 매 프레임 증가
var death_count: int   = 0       # 죽은 횟수
var timing_active: bool = false  # true 일 때만 시간이 흐름(메뉴에선 멈춤)

## 기록을 0으로 초기화 (새 게임 시작 시)
func reset_run_stats() -> void:
	run_time    = 0.0
	death_count = 0

## 플레이어가 죽을 때마다 호출 (player.gd die() 에서 호출)
func add_death() -> void:
	death_count += 1

func _process(delta: float) -> void:
	# 스테이지 플레이 중일 때만 시간 누적
	if timing_active:
		run_time += delta

# ── 스테이지 로드 ─────────────────────────────────────────────────
func load_stage(n: int) -> void:
	current_stage = n
	var path: String = STAGES.get(n, "")
	if path.is_empty():
		push_error("SceneManager: stage %d 에 해당하는 씬 경로가 없습니다." % n)
		return
	# 1스테이지로 들어가는 건 "새 게임 시작" → 기록 초기화
	if n == 1:
		reset_run_stats()
	timing_active = true   # 스테이지 진입 → 타이머 시작(누적)
	get_tree().change_scene_to_file(path)

## 현재 스테이지 다음 번호로 이동
func next_stage() -> void:
	load_stage(current_stage + 1)

# ── UI 씬 이동 ────────────────────────────────────────────────────
func go_to_main_menu() -> void:
	timing_active = false   # 메뉴에선 타이머 멈춤
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func go_to_stage_select() -> void:
	timing_active = false   # 스테이지 선택 화면에선 타이머 멈춤
	get_tree().change_scene_to_file("res://scenes/ui/StageSelect.tscn")
