extends Node
## [2026-08-24 코덱스] 구형 타일맵에서도 현재 페인트 규칙을 똑같이 적용한다.
##
## ── v2 확정 규칙 (2026-07-14 도형 결정, 근거: docs/기획서_규칙_플로우차트.md v1.2) ──
##  1. 물감 게이지 폐지. 발사는 횟수 제한 없이 무제한.
##  2. 대신 "무색 발판"마다 필요 명중 횟수(1~3발)가 있다 — 타일 커스텀 데이터 "paint_hits".
##     같은 색 페인트를 필요 횟수만큼 맞히면 그 색 발판으로 변한다.
##     붓 커서를 발판에 올리면 남은 횟수가 숫자로 표시된다 (brush_cursor_ui.gd).
##  3. 흑·백 부분칠은 따로 남고, 두 색이 함께 있으면 어느 쪽도 전체칠이 되지 않는다.
##     부분칠은 4초 유지 + 1초 감쇠 뒤 색별로 사라진다.
##  4. 회수(E)는 유지: 색과 무관하게 "가장 먼저 칠해진 발판"부터 전역 FIFO 로 무색 복구.
##     게이지가 없으므로 회수는 자원 회수가 아니라 "칠한 길을 되돌리는 지형 조작" 도구다.
##  5. 완성된 발판에 반대색을 쏘면 회색 혼합 없이 마지막 색이 그대로 덮어쓴다.
class_name PaintSystem

signal paint_changed                                        ## 지형 칠 상태가 바뀔 때 (UI 갱신용)
signal hit_feedback(cell: Vector2i, result: String, remaining: int)  ## 탄착 피드백 (UI 팝업용)

const 페인트진행_S := preload("res://scripts/페인트_진행.gd")

# ── 타일 아틀라스 좌표 (assets/tilesets/terrain_tileset.tres 기준) ──────
const TILE_SOURCE: int = 0
const ATLAS_BLACK: Vector2i = Vector2i(0, 0)
const ATLAS_WHITE: Vector2i = Vector2i(1, 0)
## 무색(칠 가능) 발판 3종 — x좌표 3/4/5 = 필요 명중 횟수 1/2/3
const ATLAS_UNPAINTED_1: Vector2i = Vector2i(3, 0)
const ATLAS_UNPAINTED_2: Vector2i = Vector2i(4, 0)
const ATLAS_UNPAINTED_3: Vector2i = Vector2i(5, 0)

## 셀별 칠 진행 상태. 흑·백 횟수와 수명은 공용 규칙 객체가 각각 관리한다.
## layer/original 은 자동 회수 뒤 완성 여부를 처리할 때 필요하다.
var _progress: Dictionary = {}

## 전역 FIFO 회수 큐. 원소 = { "cell": Vector2i, "color": int, "original": Vector2i }
## original = 칠해지기 전의 무색 아틀라스 좌표 (회수 시 원래 내구도로 복구하기 위함)
var _queue: Array[Dictionary] = []

# ── 조회 (UI·테스트용) ──────────────────────────────────────────────────
static func is_unpainted(atlas: Vector2i) -> bool:
	return atlas == ATLAS_UNPAINTED_1 or atlas == ATLAS_UNPAINTED_2 or atlas == ATLAS_UNPAINTED_3

## 이 발판의 총 필요 명중 횟수. 타일 커스텀 데이터 "paint_hits"를 우선 읽고,
## (테스트 등에서 타일 데이터가 없으면) 아틀라스 좌표로 폴백.
static func hits_required(layer: TileMapLayer, cell: Vector2i) -> int:
	# 구형 테스트 타일셋처럼 source 리소스가 빠진 경우 get_cell_tile_data() 자체가
	# 오류를 찍으므로, 실제 source가 있을 때만 커스텀 데이터를 읽는다.
	var source_id := layer.get_cell_source_id(cell)
	var data: TileData = null
	if layer.tile_set != null and source_id >= 0 and layer.tile_set.has_source(source_id):
		data = layer.get_cell_tile_data(cell)
	if data != null:
		var v = data.get_custom_data("paint_hits")
		if v is int and v > 0:
			return v
	match layer.get_cell_atlas_coords(cell):
		ATLAS_UNPAINTED_1: return 1
		ATLAS_UNPAINTED_2: return 2
		ATLAS_UNPAINTED_3: return 3
	return 0

## "이 색으로 쏘면 몇 발 더 필요한가" — 붓 커서 숫자 표시용.
## 무색이 아니면 -1 (칠 대상 아님).
func remaining_hits(layer: TileMapLayer, cell: Vector2i, color: int) -> int:
	var atlas := layer.get_cell_atlas_coords(cell)
	if not is_unpainted(atlas):
		return -1
	var req := hits_required(layer, cell)
	if _progress.has(cell):
		var 진행 = _progress[cell]["진행"]
		return 진행.남은횟수(color, req)
	return req

func queue_size() -> int:
	return _queue.size()

## 다음에 회수될(가장 먼저 칠한) 발판 셀. 없으면 null. — HUD "다음 회수" 표시용
func next_recover_cell():
	return null if _queue.is_empty() else _queue.front()["cell"]

# ── 탄착 처리 (proto_bullet 이 지형 명중 시 호출) ────────────────────────
## 반환값(문자열)은 테스트/로그용:
##   progress    = 무색 발판에 명중했지만 아직 횟수가 남음
##   painted     = 필요 횟수를 채워 쏜 색으로 칠해짐 (FIFO 큐 등록)
##   wasted      = 이미 같은 색인 발판에 명중 (변화 없음)
##   blocked     = 칠할 수 없는 발판
##   miss        = 빈 셀
func on_hit(layer: TileMapLayer, cell: Vector2i, color: int) -> String:
	if layer.get_cell_source_id(cell) == -1:
		return "miss"                                    # 빈 셀 (안전장치)
	var atlas := layer.get_cell_atlas_coords(cell)
	var my_atlas    := ATLAS_BLACK if color == ColorDefs.BLACK else ATLAS_WHITE
	var other_atlas := ATLAS_WHITE if color == ColorDefs.BLACK else ATLAS_BLACK

	if is_unpainted(atlas):
		var req := hits_required(layer, cell)
		if not _progress.has(cell):
			_progress[cell] = {
				"진행": 페인트진행_S.new(),
				"layer": layer,
				"original": atlas,
			}
		var 진행 = _progress[cell]["진행"]
		if 진행.명중(color, req):
			_부분_완성(cell, color)
			return "painted"
		paint_changed.emit()
		hit_feedback.emit(cell, "progress", 진행.남은횟수(color, req))
		return "progress"

	if atlas == my_atlas:
		hit_feedback.emit(cell, "wasted", -1)
		return "wasted"                                  # 같은 색 덧칠: 변화 없음

	if atlas == other_atlas:
		# 플레이어 페인트끼리는 섞지 않는다. 회수 순서와 원래 지형은 그대로 둔다.
		layer.set_cell(cell, TILE_SOURCE, my_atlas)
		for i in _queue.size():
			if _queue[i]["cell"] == cell:
				_queue[i]["color"] = color
				break
		paint_changed.emit()
		hit_feedback.emit(cell, "painted", 0)
		return "painted"

	hit_feedback.emit(cell, "blocked", -1)
	return "blocked"                                     # 회색 등: 아무 일도 없음

# ── 회수 (E 키) ─────────────────────────────────────────────────────────
## 가장 먼저 칠해진 발판부터: 지형을 "원래 내구도의 무색"으로 되돌린다.
func recover(layer: TileMapLayer) -> bool:
	if _queue.is_empty():
		return false
	var entry: Dictionary = _queue.pop_front()
	layer.set_cell(entry["cell"], TILE_SOURCE, entry["original"])
	paint_changed.emit()
	hit_feedback.emit(entry["cell"], "recovered", -1)
	return true


func _process(delta: float) -> void:
	# 두 색은 별도 타이머로 흐려진다. 한쪽이 사라졌을 때 반대쪽이 필요 횟수를
	# 이미 채웠다면 그 순간 전체칠로 승격한다.
	for cell in _progress.keys():
		var 항목: Dictionary = _progress[cell]
		var layer: TileMapLayer = 항목["layer"]
		if not is_instance_valid(layer):
			_progress.erase(cell)
			continue
		var req := hits_required(layer, cell)
		var 진행 = 항목["진행"]
		var 결과: Dictionary = 진행.진행(delta, req)
		if not (결과["만료"] as Dictionary).is_empty():
			paint_changed.emit()
		if int(결과["완성색"]) >= 0:
			_부분_완성(cell, int(결과["완성색"]))
		elif 진행.전체횟수() == 0:
			_progress.erase(cell)


func _부분_완성(cell: Vector2i, color: int) -> void:
	if not _progress.has(cell):
		return
	var 항목: Dictionary = _progress[cell]
	var layer: TileMapLayer = 항목["layer"]
	var atlas := ATLAS_BLACK if color == ColorDefs.BLACK else ATLAS_WHITE
	layer.set_cell(cell, TILE_SOURCE, atlas)
	_queue.append({ "cell": cell, "color": color, "original": 항목["original"] })
	_progress.erase(cell)
	paint_changed.emit()
	hit_feedback.emit(cell, "painted", 0)
