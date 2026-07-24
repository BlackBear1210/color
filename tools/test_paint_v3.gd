extends SceneTree
## ============================================================================
## [2026-07-24 도형 · 신규] 페인트 v3(플랫폼 색칠) 규칙 자동 테스트
## 실행: Godot --headless --path . -s res://tools/test_paint_v3.gd
##
## v2 의 test_paint_system.gd(타일맵 33항목)를 대체하는 게 아니라 **추가**한다.
## v2 는 zone_01/02/world_1 이 아직 쓰고 있으므로 둘 다 살아 있어야 한다.
## ============================================================================

var _통과 := 0
var _실패 := 0

func _init() -> void:
	Engine.max_fps = 60
	_실행()

func _확인(설명: String, 조건: bool) -> void:
	if 조건:
		_통과 += 1
		print("  ✔ %s" % 설명)
	else:
		_실패 += 1
		printerr("  ✘ %s" % 설명)

func _같음(설명: String, 실제, 기대) -> void:
	_확인("%s  (실제 %s / 기대 %s)" % [설명, str(실제), str(기대)], 실제 == 기대)

## 테스트용 플랫폼 하나 만들기 (씬 트리에 붙여야 _ready 가 돌아 그림·충돌이 생긴다)
func _발판(칸: Vector2i, 상태: int = 0, 통과: bool = true, 수동: int = 0) -> PaintPlatform:
	var p := AnimatableBody2D.new()
	p.set_script(load("res://scripts/proto/paint_platform.gd"))
	p.set("재질", "벽돌")
	p.set("크기_칸", 칸)
	p.set("시작상태", 상태)
	p.set("무색일때_통과", 통과)
	p.set("필요횟수_수동", 수동)
	root.add_child(p)
	return p

func _실행() -> void:
	# ⚠ SceneTree 스크립트의 `_init()` 시점에는 트리가 아직 시작되지 않아,
	#   그때 add_child 한 노드는 **_ready 가 즉시 호출되지 않는다**(첫 프레임까지 보류).
	#   그러면 시작상태·그룹 등록이 안 된 채로 검사하게 되어 가짜 실패가 난다.
	#   (2026-07-24 실제로 [5]번 항목이 이 이유로 실패했다 — 7/18 의 max_fps 사건과 같은 계열)
	await process_frame
	print("\n=== 페인트 v3 규칙 테스트 ===")

	# ── 1. 필요 횟수 자동 계산 (7/24 회의: 8칸 플랫폼 = 4번) ──────────────
	print("\n[1] 필요 횟수 계산")
	_같음("8칸 플랫폼 = 4번", _발판(Vector2i(8, 1)).필요횟수(), 4)
	_같음("2칸 플랫폼 = 1번", _발판(Vector2i(2, 1)).필요횟수(), 1)
	_같음("4칸 플랫폼 = 2번", _발판(Vector2i(4, 1)).필요횟수(), 2)
	_같음("12칸 플랫폼 = 6번", _발판(Vector2i(12, 1)).필요횟수(), 6)
	_같음("5칸 플랫폼 = 3번(올림)", _발판(Vector2i(5, 1)).필요횟수(), 3)
	_같음("세로 9칸 기둥 = 5번", _발판(Vector2i(3, 9)).필요횟수(), 5)
	_같음("수동 지정이 우선", _발판(Vector2i(8, 1), 0, true, 2).필요횟수(), 2)

	# ── 2. 진행 → 완성 ──────────────────────────────────────────────────
	print("\n[2] 색칠 진행과 완성")
	var p := _발판(Vector2i(8, 1))
	_같음("1발 → progress", p.명중(ColorDefs.BLACK, p.global_position), "progress")
	_같음("남은 횟수 3", p.남은횟수(ColorDefs.BLACK), 3)
	p.명중(ColorDefs.BLACK, p.global_position)
	p.명중(ColorDefs.BLACK, p.global_position)
	_같음("4발째 → painted", p.명중(ColorDefs.BLACK, p.global_position), "painted")
	_같음("상태 = 검정", p.현재상태, PaintPlatform.상태.검정)
	_같음("완성 후엔 칠 대상 아님(-1)", p.남은횟수(ColorDefs.BLACK), -1)

	# ── 3. 진행 중 다른 색 = 리셋 (규칙 3) ───────────────────────────────
	print("\n[3] 진행 중 색 변경 = 회색이 아니라 리셋")
	var p2 := _발판(Vector2i(8, 1))
	p2.명중(ColorDefs.BLACK, p2.global_position)
	p2.명중(ColorDefs.BLACK, p2.global_position)
	_같음("검정 2발 후 남은 2", p2.남은횟수(ColorDefs.BLACK), 2)
	p2.명중(ColorDefs.WHITE, p2.global_position)
	_같음("흰색으로 리셋 → 남은 3", p2.남은횟수(ColorDefs.WHITE), 3)
	_같음("아직 무색", p2.현재상태, PaintPlatform.상태.무색)

	# ── 4. 낭비 · 회색 · 영구 ───────────────────────────────────────────
	print("\n[4] 덧칠 / 회색 혼합 / 영구성")
	var p3 := _발판(Vector2i(2, 1))
	p3.명중(ColorDefs.BLACK, p3.global_position)
	_같음("같은 색 덧칠 = wasted", p3.명중(ColorDefs.BLACK, p3.global_position), "wasted")
	_같음("반대색 = mixed_gray", p3.명중(ColorDefs.WHITE, p3.global_position), "mixed_gray")
	_같음("상태 = 회색", p3.현재상태, PaintPlatform.상태.회색)
	_같음("회색에 또 쏘면 blocked", p3.명중(ColorDefs.BLACK, p3.global_position), "blocked")
	_같음("회색은 되돌릴 수 없다", p3.되돌리기(), false)

	# ── 5. 밟기 판정 (규칙 v1.3) ────────────────────────────────────────
	print("\n[5] 밟기 / 사망 판정")
	var 검 := _발판(Vector2i(4, 1), PaintPlatform.상태.검정)
	_확인("검정 발판: 흰색 플레이어는 죽는다", 검.반대색인가(ColorDefs.WHITE))
	_확인("검정 발판: 검정 플레이어는 안전", not 검.반대색인가(ColorDefs.BLACK))
	var 회 := _발판(Vector2i(4, 1), PaintPlatform.상태.회색)
	_확인("회색 발판: 누구에게나 안전", not 회.반대색인가(ColorDefs.WHITE) and not 회.반대색인가(ColorDefs.BLACK))

	# ── 6. 유령 지형(무색일때_통과) ─────────────────────────────────────
	print("\n[6] 유령 지형 — 칠해야 밟을 수 있다 (레벨디자인 가이드 V1)")
	var 유 := _발판(Vector2i(4, 1), PaintPlatform.상태.무색, true)
	await process_frame                                   # collision_layer 는 deferred 로 바뀐다
	_확인("무색 유령은 밟을 수 없다", not 유.밟을_수_있나())
	_같음("유령 레이어 = 8(4번)", 유.collision_layer, PaintPlatform.유령_레이어비트)
	유.명중(ColorDefs.BLACK, 유.global_position)
	유.명중(ColorDefs.BLACK, 유.global_position)
	await process_frame
	_확인("칠하면 실체가 된다", 유.밟을_수_있나())
	_같음("실체 레이어 = 1", 유.collision_layer, 1)
	유.되돌리기()
	await process_frame
	_확인("되돌리면 다시 유령", not 유.밟을_수_있나())
	var 안전무색 := _발판(Vector2i(4, 1), PaintPlatform.상태.무색, false)
	await process_frame
	_확인("통과 끄면 무색이어도 밟을 수 있다(구 규칙 호환)", 안전무색.밟을_수_있나())

	# ── 7. 회수 FIFO (PaintManager) ─────────────────────────────────────
	print("\n[7] 회수 — 먼저 칠한 것부터 (FIFO)")
	var 매니저 := PaintManager.new()
	var a := _발판(Vector2i(2, 1))
	var b := _발판(Vector2i(2, 1))
	var c := _발판(Vector2i(2, 1))
	root.add_child(매니저)                                 # _ready 에서 그룹을 훑어 연결
	a.명중(ColorDefs.BLACK, a.global_position)
	b.명중(ColorDefs.WHITE, b.global_position)
	c.명중(ColorDefs.BLACK, c.global_position)
	_같음("3개 칠함 → 큐 3", 매니저.큐_크기(), 3)
	_같음("다음 회수 대상 = 가장 먼저 칠한 a", 매니저.다음_회수_대상(), a)
	매니저.되돌리기()
	_같음("a 가 무색으로", a.현재상태, PaintPlatform.상태.무색)
	_같음("다음은 b", 매니저.다음_회수_대상(), b)
	# 회색이 된 것은 큐에서 빠져 영원히 안 돌아온다
	b.명중(ColorDefs.BLACK, b.global_position)             # 흰색 완성판 + 검정 = 회색
	_같음("회색이 되면 큐에서 제외 → 다음은 c", 매니저.다음_회수_대상(), c)
	매니저.되돌리기()
	_같음("전부 회수 후 큐 0", 매니저.큐_크기(), 0)
	_같음("더 회수할 게 없으면 false", 매니저.되돌리기(), false)

	# ── 8. 통계 ─────────────────────────────────────────────────────────
	print("\n[8] 통계")
	var 통계 := 매니저.통계()
	_확인("통계에 무색/칠함/회색/전체 키가 있다",
		통계.has("무색") and 통계.has("칠함") and 통계.has("회색") and 통계.has("전체"))

	print("\n=== 결과: %d 통과 / %d 실패 ===\n" % [_통과, _실패])
	quit(0 if _실패 == 0 else 1)
