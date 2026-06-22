extends Node
## 씬 전환 전담 싱글톤 (Autoload).
## 어디서든 SceneManager.load_stage(1) 처럼 호출해서 씬을 바꿀 수 있음.
##
## ▼ 2026-06-22 보강:
##   - 화면 '페이드' 전환(검은 화면으로 부드럽게 전환).
##   - 진행상황 저장: 클리어한 스테이지 / 잠금해제 / 스테이지별 베스트 타임 (user://progress.json).
##   - process_mode = ALWAYS: 일시정지 중에도 페이드/전환이 동작.

# ── 스테이지 번호 → 씬 경로 테이블 ──────────────────────────────
const STAGES: Dictionary = {
	1:  "res://scenes/world_1/stage_1/stage_1.tscn",
	2:  "res://scenes/world_1/stage_2/stage_2.tscn",
	3:  "res://scenes/world_1/stage_3/stage_3.tscn",
}
const MAIN_MENU := "res://scenes/ui/MainMenu.tscn"
const STAGE_SELECT := "res://scenes/ui/StageSelect.tscn"
const SAVE_PATH := "user://progress.json"

# 현재 플레이 중인 스테이지 번호
var current_stage: int = 0

# ── 플레이 기록 (HUD 표시용) ──────────────────────────────────────
var run_time: float    = 0.0     # 경과 시간(초, 런 누적)
var death_count: int   = 0       # 죽은 횟수
var timing_active: bool = false  # true 일 때만 시간이 흐름

# ── 진행상황(저장됨) ──────────────────────────────────────────────
var max_unlocked: int = 1            # 선택 가능한 최고 스테이지
var cleared: Dictionary = {}         # {스테이지번호: true}
var best_times: Dictionary = {}      # {스테이지번호: 최단시간(초)}
var _stage_start_time: float = 0.0   # 현재 스테이지 시작 시점의 run_time

# ── 페이드 전환용 ─────────────────────────────────────────────────
var _fade: ColorRect = null
var _transitioning: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 일시정지 중에도 전환/페이드 동작
	_setup_fade()
	_load_progress()

## 검은 페이드 오버레이(최상단 CanvasLayer)를 코드로 생성.
func _setup_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 200
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.anchor_right = 1.0
	_fade.anchor_bottom = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)

func reset_run_stats() -> void:
	run_time    = 0.0
	death_count = 0

func add_death() -> void:
	death_count += 1

func _process(delta: float) -> void:
	if timing_active and not get_tree().paused:
		run_time += delta

# ── 스테이지 로드(페이드 포함) ────────────────────────────────────
func load_stage(n: int) -> void:
	var path: String = STAGES.get(n, "")
	if path.is_empty():
		push_error("SceneManager: stage %d 경로 없음." % n)
		return
	current_stage = n
	if n == 1:
		reset_run_stats()       # 1스테이지 진입 = 새 게임
	max_unlocked = maxi(max_unlocked, n)
	timing_active = true
	_stage_start_time = run_time
	_change_with_fade(path)

func next_stage() -> void:
	load_stage(current_stage + 1)

## 현재 스테이지를 다시 로드(일시정지 메뉴 '재시작'용)
func restart_stage() -> void:
	if current_stage > 0:
		load_stage(current_stage)

func go_to_main_menu() -> void:
	timing_active = false
	current_stage = 0
	_change_with_fade(MAIN_MENU)

func go_to_stage_select() -> void:
	timing_active = false
	_change_with_fade(STAGE_SELECT)

# ── 클리어 기록 ──────────────────────────────────────────────────
## 스테이지 클리어 시 호출. 반환 = {time, best, is_record}
func record_clear(n: int) -> Dictionary:
	var stage_time: float = run_time - _stage_start_time
	cleared[n] = true
	max_unlocked = maxi(max_unlocked, n + 1)
	var is_record := false
	if not best_times.has(n) or stage_time < float(best_times[n]):
		best_times[n] = stage_time
		is_record = true
	_save_progress()
	return {"time": stage_time, "best": float(best_times[n]), "is_record": is_record}

func is_unlocked(n: int) -> bool:
	return n <= max_unlocked

func is_cleared(n: int) -> bool:
	return cleared.get(n, false)

func best_time(n: int) -> float:
	return float(best_times.get(n, 0.0))

# ── 저장 / 불러오기 ──────────────────────────────────────────────
func _save_progress() -> void:
	var data := {
		"max_unlocked": max_unlocked,
		"cleared": cleared,
		"best_times": best_times,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func _load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var data = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		return
	max_unlocked = int(data.get("max_unlocked", 1))
	# JSON 키는 문자열이므로 정수 키로 복원
	cleared = _intkeys(data.get("cleared", {}))
	best_times = _intkeys(data.get("best_times", {}))

func _intkeys(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d.keys():
		out[int(k)] = d[k]
	return out

# ── 페이드 전환 ──────────────────────────────────────────────────
func _change_with_fade(path: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	# 페이드 아웃(검게) → 씬 전환 → 페이드 인(밝게)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.25)
	await tw.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.25)
	await tw2.finished
	_transitioning = false
