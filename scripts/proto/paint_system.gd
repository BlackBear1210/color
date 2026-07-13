extends Node
## [2026-07-13 도형 · 신규] 물감 게이지·FIFO 회수·회색 혼합 규칙의 "검증용 프로토타입".
## ⚠ 기존 스크립트(player.gd / gun.gd / bullet.gd)는 한 줄도 수정하지 않았다.
##   zone_01 테스트 맵 + proto_* 스크립트만으로 규칙이 실제로 작동하는지 확인하는 용도이며,
##   정식 구현은 P-A 담당 (근거: docs/기획서_규칙_플로우차트.md 1장·3장).
##
## 구현한 규칙 (2026-07-13 도형 확정 사양):
##  1. 흑/백 게이지 분리, 각 5칸. 발사한 색의 게이지만 1칸 소모.
##  2. 회수(E): 색과 무관하게 "먼저 쏜 것부터" 전역 FIFO. 지형도 함께 원상복구.
##  3. 회수된 물감은 그 색의 게이지로 복귀. 칸은 "먼저 비워진 칸(낮은 번호)"부터 차오름.
##  4. 회색(흑+백 혼합)은 회수 불가 — FIFO 큐에서 빠지고, 앞뒤 순서는 그대로 유지.
##  5. 회색이 생기면 흑·백 게이지 '최대 칸'을 각각 1칸씩 영구 파괴 (칸 자체가 사라짐).
class_name PaintSystem

signal gauge_changed                    ## 게이지/칸 상태가 바뀔 때 (UI 갱신용)
signal gray_created(cell: Vector2i)     ## 회색 혼합이 일어났을 때
signal fire_denied(color: int)          ## 잔량 0으로 발사가 거부됐을 때

# ── 타일 아틀라스 좌표 (assets/tilesets/terrain_tileset.tres 기준) ──────
const TILE_SOURCE: int = 0
const ATLAS_BLACK:     Vector2i = Vector2i(0, 0)
const ATLAS_WHITE:     Vector2i = Vector2i(1, 0)
const ATLAS_GRAY:      Vector2i = Vector2i(2, 0)
const ATLAS_UNPAINTED: Vector2i = Vector2i(3, 0)

const START_MAX: int = 5   ## 시작 게이지 칸 수 (색마다 5칸)

## 칸 배열: 인덱스 = 칸 번호-1. true=차 있음.
## 발사 = 낮은 번호부터 비우고, 회수 = 낮은 번호부터 채움 → "먼저 비워진 칸부터 차오름".
## 회색 페널티 = 배열에서 빈 칸 하나를 아예 제거 (최대치 영구 -1).
## (_init 대신 멤버 초기화: set_script 로 부착해도 확실히 초기화되도록)
var _slots: Dictionary = {
	ColorDefs.BLACK: _make_slots(START_MAX),
	ColorDefs.WHITE: _make_slots(START_MAX),
}

## 전역 FIFO 회수 큐. 원소 = { "cell": Vector2i, "color": int }. 앞 = 가장 먼저 칠한 것.
var _queue: Array[Dictionary] = []

static func _make_slots(n: int) -> Array[bool]:
	var a: Array[bool] = []
	a.resize(n)
	a.fill(true)
	return a

# ── 조회 (UI·테스트용) ──────────────────────────────────────────────────
func slots_of(color: int) -> Array[bool]:
	return _slots[color]

func max_of(color: int) -> int:
	return _slots[color].size()

func current_of(color: int) -> int:
	return _slots[color].count(true)

func queue_size() -> int:
	return _queue.size()

func can_fire(color: int) -> bool:
	return current_of(color) > 0

# ── 발사 시 소모 (proto_gun 이 발사 직전에 호출) ─────────────────────────
func consume(color: int) -> bool:
	var slots: Array[bool] = _slots[color]
	var idx := slots.find(true)          # 낮은 번호 칸부터 비움
	if idx == -1:
		fire_denied.emit(color)
		return false
	slots[idx] = false
	gauge_changed.emit()
	return true

# ── 탄착 처리 (proto_bullet 이 지형 명중 시 호출) ────────────────────────
## 반환값(문자열)은 테스트/로그용: painted / wasted / mixed_gray / blocked / miss
func on_hit(layer: TileMapLayer, cell: Vector2i, color: int) -> String:
	if layer.get_cell_source_id(cell) == -1:
		return "miss"                                    # 빈 셀 (안전장치)
	var atlas := layer.get_cell_atlas_coords(cell)
	var my_atlas    := ATLAS_BLACK if color == ColorDefs.BLACK else ATLAS_WHITE
	var other_atlas := ATLAS_WHITE if color == ColorDefs.BLACK else ATLAS_BLACK

	if atlas == ATLAS_UNPAINTED:
		# 무색 → 쏜 색으로 칠하고 FIFO 큐 등록
		layer.set_cell(cell, TILE_SOURCE, my_atlas)
		_queue.append({ "cell": cell, "color": color })
		gauge_changed.emit()
		return "painted"

	if atlas == my_atlas:
		return "wasted"                                  # 같은 색 덧칠: 변화 없음 (물감만 낭비)

	if atlas == other_atlas:
		# 흑+백 혼합 → 회색. 회수 불가 + 양쪽 최대 칸 1칸씩 영구 파괴.
		layer.set_cell(cell, TILE_SOURCE, ATLAS_GRAY)
		for i in _queue.size():
			if _queue[i]["cell"] == cell:
				_queue.remove_at(i)                      # 큐에서 제거 → 앞뒤 순서는 유지
				break
		_destroy_one_slot(ColorDefs.BLACK)
		_destroy_one_slot(ColorDefs.WHITE)
		gauge_changed.emit()
		gray_created.emit(cell)
		return "mixed_gray"

	return "blocked"                                     # 회색 등: 아무 일도 없음

## 빈 칸 하나를 배열에서 아예 제거 = 최대치 영구 -1.
## 혼합 시점에는 양쪽 색 모두 "그 발판에 들어간 물감" 만큼 빈 칸이 반드시 1개 이상 있으므로
## (그 물감이 곧 사라지는 칸이다) 뒤에서부터 빈 칸을 찾아 없앤다.
func _destroy_one_slot(color: int) -> void:
	var slots: Array[bool] = _slots[color]
	for i in range(slots.size() - 1, -1, -1):
		if not slots[i]:
			slots.remove_at(i)
			return
	if not slots.is_empty():
		slots.pop_back()                                 # 예외 상황 안전장치

# ── 회수 (E 키) ─────────────────────────────────────────────────────────
## 가장 먼저 칠한 발판부터: 지형을 무색으로 되돌리고 그 색 게이지 +1.
func recover(layer: TileMapLayer) -> bool:
	if _queue.is_empty():
		return false
	var entry: Dictionary = _queue.pop_front()
	layer.set_cell(entry["cell"], TILE_SOURCE, ATLAS_UNPAINTED)
	var slots: Array[bool] = _slots[entry["color"]]
	var idx := slots.find(false)         # 먼저 비워진(낮은 번호) 칸부터 채움
	if idx != -1:
		slots[idx] = true
	gauge_changed.emit()
	return true
