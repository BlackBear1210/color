extends Node
## [2026-07-14 도형 · v2 전면 개정] 물감 규칙 프로토타입 — "게이지 폐지 + 횟수(내구도)제".
## ⚠ 기존 스크립트(player.gd / gun.gd / bullet.gd)는 여전히 한 줄도 수정하지 않는다.
##   zone_01 / zone_02 테스트 맵 + proto_* 스크립트에서만 사용. 정식 구현은 P-A 담당.
##
## ── v2 확정 규칙 (2026-07-14 도형 결정, 근거: docs/기획서_규칙_플로우차트.md v1.2) ──
##  1. 물감 게이지 폐지. 발사는 횟수 제한 없이 무제한.
##  2. 대신 "무색 발판"마다 필요 명중 횟수(1~3발)가 있다 — 타일 커스텀 데이터 "paint_hits".
##     같은 색 페인트를 필요 횟수만큼 맞히면 그 색 발판으로 변한다.
##     붓 커서를 발판에 올리면 남은 횟수가 숫자로 표시된다 (brush_cursor_ui.gd).
##  3. 진행 중(1발 이상 맞았지만 미완성) 발판에 다른 색을 쏘면 → 회색이 아니라
##     "새 색으로 진행 리셋"(1발부터 다시). 아직 칠해진 발판이 아니므로 혼합이 아니다. 🟡제안
##  4. 회수(E)는 유지: 색과 무관하게 "가장 먼저 칠해진 발판"부터 전역 FIFO 로 무색 복구.
##     게이지가 없으므로 회수는 자원 회수가 아니라 "칠한 길을 되돌리는 지형 조작" 도구다.
##  5. 회색(완성된 발판에 반대색 명중)은 그대로: 영구히 회색, 회수 큐에서 제외.
##     (게이지 칸 파괴 페널티는 게이지와 함께 폐지 — 회색 그 자체가 페널티)
class_name PaintSystem

signal paint_changed                                        ## 지형 칠 상태가 바뀔 때 (UI 갱신용)
signal gray_created(cell: Vector2i)                         ## 회색 혼합이 일어났을 때
signal hit_feedback(cell: Vector2i, result: String, remaining: int)  ## 탄착 피드백 (UI 팝업용)

# ── 타일 아틀라스 좌표 (assets/tilesets/terrain_tileset.tres 기준) ──────
const TILE_SOURCE: int = 0
const ATLAS_BLACK: Vector2i = Vector2i(0, 0)
const ATLAS_WHITE: Vector2i = Vector2i(1, 0)
const ATLAS_GRAY:  Vector2i = Vector2i(2, 0)
## 무색(칠 가능) 발판 3종 — x좌표 3/4/5 = 필요 명중 횟수 1/2/3
const ATLAS_UNPAINTED_1: Vector2i = Vector2i(3, 0)
const ATLAS_UNPAINTED_2: Vector2i = Vector2i(4, 0)
const ATLAS_UNPAINTED_3: Vector2i = Vector2i(5, 0)

## 셀별 칠 진행 상태. key = Vector2i(셀), value = { "color": int, "done": int }
## (무색 발판에 1발 이상 맞았지만 아직 필요 횟수를 못 채운 상태)
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
	var data := layer.get_cell_tile_data(cell)
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
	if _progress.has(cell) and _progress[cell]["color"] == color:
		return req - int(_progress[cell]["done"])   # 같은 색 진행 중이면 남은 만큼만
	return req                                      # 미진행 or 다른 색 진행(리셋될 것)이면 전체

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
##   mixed_gray  = 완성된 발판에 반대색 명중 → 회색 (영구)
##   blocked     = 회색 발판 등 아무 일도 없음
##   miss        = 빈 셀
func on_hit(layer: TileMapLayer, cell: Vector2i, color: int) -> String:
	if layer.get_cell_source_id(cell) == -1:
		return "miss"                                    # 빈 셀 (안전장치)
	var atlas := layer.get_cell_atlas_coords(cell)
	var my_atlas    := ATLAS_BLACK if color == ColorDefs.BLACK else ATLAS_WHITE
	var other_atlas := ATLAS_WHITE if color == ColorDefs.BLACK else ATLAS_BLACK

	if is_unpainted(atlas):
		var req := hits_required(layer, cell)
		var done := 0
		if _progress.has(cell) and _progress[cell]["color"] == color:
			done = _progress[cell]["done"]
		# 다른 색으로 진행 중이었으면 위에서 done=0 → 새 색으로 리셋 (규칙 3)
		done += 1
		if done >= req:
			# 필요 횟수 달성 → 칠 완성. 원래 내구도 타일을 기억해두고 FIFO 등록.
			layer.set_cell(cell, TILE_SOURCE, my_atlas)
			_progress.erase(cell)
			_queue.append({ "cell": cell, "color": color, "original": atlas })
			paint_changed.emit()
			hit_feedback.emit(cell, "painted", 0)
			return "painted"
		_progress[cell] = { "color": color, "done": done }
		paint_changed.emit()
		hit_feedback.emit(cell, "progress", req - done)
		return "progress"

	if atlas == my_atlas:
		hit_feedback.emit(cell, "wasted", -1)
		return "wasted"                                  # 같은 색 덧칠: 변화 없음

	if atlas == other_atlas:
		# 완성된 발판에 반대색 → 회색. 영구. 회수 큐에서 제거(앞뒤 순서는 유지).
		layer.set_cell(cell, TILE_SOURCE, ATLAS_GRAY)
		for i in _queue.size():
			if _queue[i]["cell"] == cell:
				_queue.remove_at(i)
				break
		paint_changed.emit()
		gray_created.emit(cell)
		hit_feedback.emit(cell, "mixed_gray", -1)
		return "mixed_gray"

	hit_feedback.emit(cell, "blocked", -1)
	return "blocked"                                     # 회색 등: 아무 일도 없음

# ── 회수 (E 키) ─────────────────────────────────────────────────────────
## 가장 먼저 칠해진 발판부터: 지형을 "원래 내구도의 무색"으로 되돌린다.
## 회색이 된 발판은 큐에 없으므로 영원히 돌아오지 않는다.
func recover(layer: TileMapLayer) -> bool:
	if _queue.is_empty():
		return false
	var entry: Dictionary = _queue.pop_front()
	layer.set_cell(entry["cell"], TILE_SOURCE, entry["original"])
	paint_changed.emit()
	hit_feedback.emit(entry["cell"], "recovered", -1)
	return true
