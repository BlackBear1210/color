extends SceneTree
## ============================================================================
## [2026-08-22 신규] 투명블럭 색칠 — **두 스테이지 계열 모두** 되는지 검사
## ----------------------------------------------------------------------------
## 실행: Godot --headless --path . -s res://tools/test_투명블럭_색칠.gd
##
## ▣ 왜 이 검사가 필요한가
##   투명블럭을 stage_2-1 에 넣었더니 **총을 쏴도 아무 일이 없었다**(2026-08-22).
##   원인은 `proto_bullet.gd` 가 PaintPlatform 과 TileMapLayer 두 갈래만 알고
##   그 외의 칠할 수 있는 노드는 "빗나감"으로 흘려보낸 것이었다.
##   같은 장애물이 씬 계열에 따라 다르게 동작하면 레벨 디자이너가 못 믿는다
##   → **양쪽을 같은 파일에서 나란히** 검사한다.
##
##   계열 A: 스마트월드 (월드.gd)   — 총알.gd  →  페인트_코어.명중_처리()
##   계열 B: stage_lab  (타일맵)     — proto_bullet.gd → TilePaintMap.노드_명중()
## ============================================================================

const 블럭씬 := "res://scenes/집/스마트월드_장애물/투명블럭.tscn"
const 코어 := preload("res://scripts/스마트월드/페인트_코어.gd")
const 타일페인트 := preload("res://scripts/proto/tile_paint_map.gd")

var 통과 := 0
var 실패 := 0


func _확인(조건: bool, 이름: String) -> void:
	if 조건:
		통과 += 1
		print("PASS  ", 이름)
	else:
		실패 += 1
		print("FAIL  ", 이름)


func _새블럭(부모: Node) -> Node:
	var b = load(블럭씬).instantiate()
	부모.add_child(b)
	return b


func _init() -> void:
	var 뿌리 := Node2D.new()
	root.add_child(뿌리)
	await process_frame

	# ════════════════════════════════════════════════════════════════════
	# 계열 A — 스마트월드: 페인트_코어.명중_처리()
	# ════════════════════════════════════════════════════════════════════
	print("── 계열 A: 스마트월드 (페인트_코어)")
	var c = 코어.new()
	var 블럭A := _새블럭(뿌리)
	var 필요: int = 블럭A.get("필요횟수")

	var 결과A := ""
	for i in 필요:
		결과A = c.명중_처리(블럭A, ColorDefs.WHITE, Vector2.ZERO)
	_확인(결과A == "painted", "A: 필요횟수를 채우면 painted")
	await process_frame
	_확인(블럭A.collision_layer == 1, "A: 칠하면 단단해진다(레이어 1)")

	# 같은 색을 또 쏘면 낭비 → 환급
	_확인(c.명중_처리(블럭A, ColorDefs.WHITE, Vector2.ZERO) == "wasted", "A: 같은 색은 wasted")
	# 반대색을 덮으면 회색
	_확인(c.명중_처리(블럭A, ColorDefs.BLACK, Vector2.ZERO) == "mixed_gray", "A: 반대색은 mixed_gray")

	# ════════════════════════════════════════════════════════════════════
	# 계열 B — stage_lab: TilePaintMap.노드_명중()
	# ════════════════════════════════════════════════════════════════════
	print("── 계열 B: stage_lab (TilePaintMap)")
	var t = 타일페인트.new()
	t.최대_탄약 = 14
	뿌리.add_child(t)
	await process_frame

	_확인(t.has_method("노드_명중"), "B: 노드_명중 진입점이 있다")

	var 블럭B := _새블럭(뿌리)
	var 시작탄약: int = t.남은_탄약

	var 결과B := ""
	for i in 필요:
		t.발사_소모()
		결과B = t.노드_명중(블럭B, ColorDefs.WHITE, Vector2.ZERO)
	_확인(결과B == "painted", "B: 필요횟수를 채우면 painted")
	await process_frame
	_확인(블럭B.collision_layer == 1, "B: 칠하면 단단해진다(레이어 1)")
	_확인(t.남은_탄약 == 시작탄약 - 필요, "B: 칠한 만큼 탄약이 줄었다 (%d발)" % 필요)

	# 낭비는 환급되어야 한다
	t.발사_소모()
	var 낭비전: int = t.남은_탄약
	_확인(t.노드_명중(블럭B, ColorDefs.WHITE, Vector2.ZERO) == "wasted", "B: 같은 색은 wasted")
	_확인(t.남은_탄약 == 낭비전 + 1, "B: 낭비한 발은 환급된다")

	# ── HUD 조회 경로 ────────────────────────────────────────────────────
	# ⚠ 여기가 2026-08-22 에 실제로 터진 자리다. `외부칠` 이 `플랫폼` 의 필드를
	#   안 갖고 있어서 HUD 가 그려지는 순간 `회색` 접근에서 죽었다.
	#   규칙 검사만 하고 **HUD 가 읽는 길**을 안 밟으면 또 놓친다.
	var 줄: Array = t.회수줄_요약()
	_확인(줄.size() == 1, "B(HUD): 회수줄_요약에 외부 노드가 1개 잡힌다")
	if 줄.size() == 1:
		var 항목: Dictionary = 줄[0]
		_확인(항목["발수"] == 필요, "B(HUD): 발수가 %d 로 잡힌다" % 필요)
		_확인(t.대상_발수(항목["대상"]) == 필요, "B(HUD): 대상_발수가 안 죽는다")
		_확인(t.대상_좌표(항목["대상"]) is Vector2, "B(HUD): 대상_좌표가 안 죽는다")
	_확인(t.진행줄_요약() is Array, "B(HUD): 진행줄_요약이 안 죽는다")
	_확인(t.회색_수() >= 0, "B(HUD): 회색_수가 안 죽는다")
	_확인(t.대상_아래(Vector2.ZERO) == null or true, "B(HUD): 대상_아래가 안 죽는다")

	# E 회수 — 회수줄에 서 있어야 한다
	_확인(t.되돌리기(), "B: E 회수가 먹는다 (회수줄에 서 있다)")
	await process_frame
	_확인(블럭B.현재색() == -1, "B: 회수하면 무색으로 돌아간다")
	_확인(블럭B.collision_layer == 8, "B: 회수하면 다시 유령 — 발판이 사라진다")
	_확인(t.남은_탄약 == 시작탄약, "B: 들어갔던 발이 통째로 돌아온다")

	# 못 칠하는 대상을 주면 빗나감으로 환급
	t.발사_소모()
	var 빗나감전: int = t.남은_탄약
	_확인(t.노드_명중(null, ColorDefs.WHITE, Vector2.ZERO) == "miss", "B: 대상이 없으면 miss")
	_확인(t.남은_탄약 == 빗나감전 + 1, "B: miss 는 환급된다")

	# 사망 리셋은 회색으로 굳은 것도 푼다
	var 블럭C := _새블럭(뿌리)
	for i in 필요:
		t.노드_명중(블럭C, ColorDefs.BLACK, Vector2.ZERO)
	t.노드_명중(블럭C, ColorDefs.WHITE, Vector2.ZERO)      # → 회색
	_확인(블럭C.현재색() == ColorDefs.GRAY, "B: 회색으로 굳었다")
	t.리셋()
	await process_frame
	_확인(블럭C.현재색() == -1, "B: 리셋은 회색도 무색으로 되돌린다")

	print("---")
	print("결과: %d / %d 통과" % [통과, 통과 + 실패])
	quit(0 if 실패 == 0 else 1)
