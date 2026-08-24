extends SceneTree
## [2026-08-24 코덱스] 구형 PaintSystem 에도 현재 덮어쓰기·부분칠 규칙이 유지되는지 검증한다.
## 실행: Godot --headless --path . -s res://tools/test_paint_system.gd
## v2 확정 사양 (게이지 폐지 + 횟수제):
##   무제한 발사 / 무색 발판은 필요 횟수(1~3발)를 채워야 칠해짐 /
##   흑·백 부분칠 공존 시 전체칠 차단 / 회수(E)는 전역 FIFO·원래 내구도로 복구 /
##   완성된 발판에 반대색 → 마지막 색으로 덮어쓰기

var fails := 0

func check(name: String, cond: bool) -> void:
	print(("PASS  " if cond else "FAIL  ") + name)
	if not cond:
		fails += 1

func _init() -> void:
	const B := 0   # ColorDefs.BLACK
	const W := 1   # ColorDefs.WHITE
	var ps: Node = load("res://scripts/proto/paint_system.gd").new()
	var layer := TileMapLayer.new()
	layer.tile_set = load("res://assets/tilesets/terrain_tileset.tres")

	var U1  := Vector2i(0, 0)    # 1발 발판
	var U2  := Vector2i(1, 0)    # 2발 발판
	var U3  := Vector2i(2, 0)    # 3발 발판
	var U1b := Vector2i(3, 0)    # 1발 발판 (두 번째)
	layer.set_cell(U1,  0, Vector2i(3, 0))
	layer.set_cell(U2,  0, Vector2i(4, 0))
	layer.set_cell(U3,  0, Vector2i(5, 0))
	layer.set_cell(U1b, 0, Vector2i(3, 0))

	# ── 필요 횟수 조회 (붓 커서 숫자) ─────────────────────────────
	check("U1 남은 횟수 = 1", ps.remaining_hits(layer, U1, B) == 1)
	check("U2 남은 횟수 = 2", ps.remaining_hits(layer, U2, B) == 2)
	check("U3 남은 횟수 = 3", ps.remaining_hits(layer, U3, B) == 3)

	# ── 1발 발판: 한 발에 칠해짐 ──────────────────────────────────
	check("U1 흑 1발 → painted", ps.on_hit(layer, U1, B) == "painted")
	check("U1 타일 = 흑", layer.get_cell_atlas_coords(U1) == Vector2i(0, 0))
	check("FIFO 큐 1개", ps.queue_size() == 1)

	# ── 2발 발판: 1발째 progress, 2발째 painted ───────────────────
	check("U2 백 1발 → progress", ps.on_hit(layer, U2, W) == "progress")
	check("U2 아직 무색(2발 타일)", layer.get_cell_atlas_coords(U2) == Vector2i(4, 0))
	check("U2 백 기준 남은 횟수 = 1", ps.remaining_hits(layer, U2, W) == 1)
	check("U2 흑 기준 남은 횟수 = 2 (색별 진행 독립)", ps.remaining_hits(layer, U2, B) == 2)
	check("U2 백 2발 → painted", ps.on_hit(layer, U2, W) == "painted")
	check("U2 타일 = 백", layer.get_cell_atlas_coords(U2) == Vector2i(1, 0))

	# ── 3발 발판 + 두 색 부분칠 충돌 ───────────────────────────────
	check("U3 흑 1발 → progress", ps.on_hit(layer, U3, B) == "progress")
	check("U3 흑 2발 → progress", ps.on_hit(layer, U3, B) == "progress")
	# 흑 부분칠의 수명을 먼저 흘려 두면, 나중에 쏜 백색만 남는 순간 자동 완성을 검사할 수 있다.
	ps._process(2.0)
	check("U3 백 1발 → progress (흑 진행도 함께 유지)", ps.on_hit(layer, U3, W) == "progress")
	check("U3 백 기준 남은 횟수 = 2", ps.remaining_hits(layer, U3, W) == 2)
	check("U3 백 2발 → progress", ps.on_hit(layer, U3, W) == "progress")
	check("U3 백 3발도 흑 부분칠 때문에 progress", ps.on_hit(layer, U3, W) == "progress")
	check("양색 부분칠 중에는 아직 무색", layer.get_cell_atlas_coords(U3) == Vector2i(5, 0))
	ps._process(3.1)
	check("먼저 맞은 흑이 사라지면 백으로 자동 완성", layer.get_cell_atlas_coords(U3) == Vector2i(1, 0))
	check("FIFO 큐 3개 (U1→U2→U3 순)", ps.queue_size() == 3)

	# ── 같은 색 덧칠 = 낭비 ──────────────────────────────────────
	check("U1(흑) 에 흑 → wasted", ps.on_hit(layer, U1, B) == "wasted")

	# ── 완성된 색 위에 반대색 = 회색 없이 덮어쓰기 ─────────────────
	check("U2(백) 에 흑 → painted", ps.on_hit(layer, U2, B) == "painted")
	check("U2 타일 = 흑", layer.get_cell_atlas_coords(U2) == Vector2i(0, 0))
	check("덮어써도 FIFO 자리는 유지", ps.queue_size() == 3)
	check("U2 에 백을 다시 쏘면 또 덮어쓴다", ps.on_hit(layer, U2, W) == "painted")
	check("U2 타일 = 백", layer.get_cell_atlas_coords(U2) == Vector2i(1, 0))

	# ── 회수: 먼저 칠한 것(U1)부터, 원래 내구도로 복구 ────────────
	check("다음 회수 대상 = U1", ps.next_recover_cell() == U1)
	check("회수1 성공", ps.recover(layer))
	check("회수1 = U1 → 무색 1발 타일로 복구", layer.get_cell_atlas_coords(U1) == Vector2i(3, 0))
	check("회수2 = U2 → 무색 '2발' 타일로 복구 (원래 내구도 유지)",
		ps.recover(layer) and layer.get_cell_atlas_coords(U2) == Vector2i(4, 0))
	check("회수3 = U3 → 무색 3발 타일", ps.recover(layer) and layer.get_cell_atlas_coords(U3) == Vector2i(5, 0))
	check("회수4 = 큐 비어서 실패", not ps.recover(layer))

	# ── 회수 후 재칠하기 (무제한 발사 확인) ───────────────────────
	check("복구된 U1 다시 칠하기 가능", ps.on_hit(layer, U1, W) == "painted")
	check("U1b 도 제한 없이 칠하기 가능", ps.on_hit(layer, U1b, W) == "painted")

	print("---")
	print("결과: %d개 실패" % fails if fails > 0 else "결과: 전부 통과 ✅")
	layer.free()
	ps.free()
	quit(1 if fails > 0 else 0)
