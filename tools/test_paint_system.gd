extends SceneTree
## [2026-07-13 도형 · 신규] PaintSystem 규칙 자동 검증 (헤드리스).
## 실행: Godot --headless --path . -s res://tools/test_paint_system.gd
## 사용자 확정 사양 그대로 시나리오를 돌리고 PASS/FAIL 을 출력한다:
##   1~3발 정상 칠하기 → 4·5발이 같은 발판에 흑+백 → 회색(회수 불가) →
##   회수는 앞(먼저 쏜 것)부터 순차 진행, 회색은 건너뜀(큐에서 이미 제외),
##   회색 발생 시 흑·백 최대 칸이 각각 1칸씩 영구 파괴.

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

	var A  := Vector2i(0, 0)
	var Bc := Vector2i(1, 0)
	var Cc := Vector2i(2, 0)
	for c: Vector2i in [A, Bc, Cc]:
		layer.set_cell(c, 0, Vector2i(3, 0))          # 무색 발판 3개

	# ── 초기 상태 ─────────────────────────────────────────────
	check("초기: 흑 5/5, 백 5/5", ps.current_of(B) == 5 and ps.max_of(B) == 5
		and ps.current_of(W) == 5 and ps.max_of(W) == 5)

	# ── 1~3발: 정상 칠하기 (1발=백A, 2발=흑B, 3발=흑C) ────────
	check("1발(백→A) 칠해짐", ps.consume(W) and ps.on_hit(layer, A, W) == "painted")
	check("2발(흑→B) 칠해짐", ps.consume(B) and ps.on_hit(layer, Bc, B) == "painted")
	check("3발(흑→C) 칠해짐", ps.consume(B) and ps.on_hit(layer, Cc, B) == "painted")
	check("게이지: 흑 3/5, 백 4/5", ps.current_of(B) == 3 and ps.current_of(W) == 4)
	check("FIFO 큐 3개", ps.queue_size() == 3)

	# ── 4+5발 상황: B(흑칠) 위에 백을 덧쏨 → 회색 ─────────────
	check("4발(백→흑B) = 회색 혼합", ps.consume(W) and ps.on_hit(layer, Bc, W) == "mixed_gray")
	check("B 타일이 회색으로 변함", layer.get_cell_atlas_coords(Bc) == Vector2i(2, 0))
	check("회색은 큐에서 제외 (2개)", ps.queue_size() == 2)
	check("페널티: 흑·백 최대 4칸으로 영구 감소", ps.max_of(B) == 4 and ps.max_of(W) == 4)
	check("잔량 유지: 흑 3/4, 백 3/4", ps.current_of(B) == 3 and ps.current_of(W) == 3)

	# ── 회수: 색과 무관, 먼저 쏜 것(1발=백A)부터 ──────────────
	check("회수1 성공", ps.recover(layer))
	check("회수1 = A(백, 가장 먼저) → 무색 복구", layer.get_cell_atlas_coords(A) == Vector2i(3, 0))
	check("백 게이지 +1 (4/4)", ps.current_of(W) == 4)
	check("회수2 = C(흑) → 무색 + 흑 +1 (4/4)",
		ps.recover(layer) and layer.get_cell_atlas_coords(Cc) == Vector2i(3, 0)
		and ps.current_of(B) == 4)
	check("회수3 = 큐 비어서 실패 (회색 B는 영원히 복구 불가)", not ps.recover(layer))
	check("회색 B는 여전히 회색", layer.get_cell_atlas_coords(Bc) == Vector2i(2, 0))

	# ── 같은 색 덧칠 = 변화 없음 ──────────────────────────────
	check("흑→A 칠하기", ps.consume(B) and ps.on_hit(layer, A, B) == "painted")
	check("흑→A 또 쏘면 낭비(wasted)", ps.consume(B) and ps.on_hit(layer, A, B) == "wasted")

	# ── 잔량 0 발사 거부 ──────────────────────────────────────
	while ps.can_fire(B):
		ps.consume(B)
	check("흑 잔량 0 → 발사 거부", not ps.consume(B))

	# ── 회수 시 "먼저 비워진 칸(낮은 번호)부터" 차오름 ─────────
	var slots: Array[bool] = ps.slots_of(B)      # 전부 false 인 상태
	ps.recover(layer)                             # A(흑) 회수 → 흑 1칸 복귀
	check("흑 1번 칸부터 차오름", slots[0] == true and slots.count(true) == 1)

	print("---")
	print("결과: %d개 실패" % fails if fails > 0 else "결과: 전부 통과 ✅")
	layer.free()
	ps.free()
	quit(1 if fails > 0 else 0)
