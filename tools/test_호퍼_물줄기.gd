extends SceneTree
## ============================================================================
## [2026-09-07 신규] 호퍼 — 입구·출구 물줄기 모양 네 칸 검사
## ----------------------------------------------------------------------------
## 실행: godot --headless --path . -s res://tools/test_호퍼_물줄기.gd
##
## ▣ 여기서 고정하는 것
##   1. **-1 은 "손대지 않는다"** 는 뜻이다. 입구 두 칸은 기본이 -1 이라
##      이 기능이 생겨도 기존 맵의 물이 한 픽셀도 안 바뀌어야 한다.
##   2. 입구와 출구를 **따로** 조절할 수 있다 (도형님 지시의 본문).
##   3. 출구 폭에도 -1 이 통한다. 예전에는 -1 이 없어서 유체에서 폭을 바꿔도
##      게임을 켜면 호퍼가 64 로 되돌려 놨다.
##   4. ★들어오는 물이 짧아 입구에 안 닿으면 **경고가 뜬다.**
##      이게 이 부품에서 조용히 망가지는 유일한 길이다 —
##      화면에는 물이 보이는데 출구로는 한 방울도 안 나간다.
##   5. 물 없이 발판으로만 쓰는 호퍼에는 **경고가 뜨면 안 된다**(2-3 의 대기 발판).
##      가짜 경고가 섞이면 진짜 경고를 안 보게 된다.
## ============================================================================

const 호퍼_씬 := "res://scenes/집/스마트월드_장애물/호퍼.tscn"
const 유체_씬 := "res://scenes/집/스마트월드_장애물/유체.tscn"

var 통과 := 0
var 실패 := 0


func _init() -> void:
	call_deferred("_실행")


func _확인(조건: bool, 글: String) -> void:
	if 조건:
		통과 += 1
		print("  ✔ %s" % 글)
	else:
		실패 += 1
		print("  ✖ %s" % 글)


func _실행() -> void:
	print("\n=== 호퍼 입구·출구 물줄기 ===")
	await _기본값은_아무것도_안건드린다()
	await _입구와_출구를_따로()
	await _출구_폭_음수1()
	await _짧은_물_경고()
	await _물_없는_발판은_조용하다()

	print("\n════════════════════════════════════════")
	print("  통과 %d · 실패 %d" % [통과, 실패])
	print("════════════════════════════════════════\n")
	quit(1 if 실패 > 0 else 0)


## 호퍼 하나 + 위에서 내려오는 물 + 아래로 나가는 물을 세운다.
## 호퍼 원점은 **아래 출구**이고, 윗면은 `높이` 만큼 위다.
func _판_만들기(입구길이: float = 900.0) -> Dictionary:
	var 판 := Node2D.new()
	root.add_child(판)

	var h: Node2D = (load(호퍼_씬) as PackedScene).instantiate()
	h.name = "H"
	판.add_child(h)
	h.position = Vector2(0, 1000)

	var 입: Node2D = (load(유체_씬) as PackedScene).instantiate()
	입.name = "입구물"
	판.add_child(입)
	입.position = Vector2(0, 100)            # 물 윗끝 100
	입.set("크기", Vector2(64, 입구길이))
	입.set("색", 0)

	var 출: Node2D = (load(유체_씬) as PackedScene).instantiate()
	출.name = "출구물"
	판.add_child(출)
	출.position = Vector2(0, 1000)
	출.set("크기", Vector2(64, 400))

	h.set("출구_유체", NodePath("../출구물"))
	h.set("입구_유체", NodePath("../입구물"))
	await physics_frame
	return {"판": 판, "호": h, "입": 입, "출": 출}


func _기본값은_아무것도_안건드린다() -> void:
	print("\n── 기본값(-1): 들어오는 물을 안 건드린다")
	var s := await _판_만들기()
	var 입: Node2D = s["입"]
	_확인(입.get("크기") == Vector2(64, 900), "입구 물 크기가 그대로 (64, 900)")
	# 출구는 예전부터 폭 기본 64 를 밀어 넣는다 — 그 동작은 안 바꿨다
	_확인(s["출"].get("크기").x == 64.0, "출구 폭은 기본 64 가 적용된다(기존 동작 유지)")
	_확인(s["출"].get("크기").y == 400.0, "출구 길이는 -1 이라 유체 값 400 유지")
	s["판"].queue_free()
	await physics_frame


func _입구와_출구를_따로() -> void:
	print("\n── 입구와 출구를 따로 조절한다")
	var s := await _판_만들기()
	var h: Node2D = s["호"]
	h.set("입구_물줄기_폭", 128.0)
	h.set("입구_물줄기_길이", 820.0)
	h.set("출구_물줄기_폭", 32.0)
	h.set("출구_물줄기_길이", 260.0)
	await physics_frame
	_확인(s["입"].get("크기") == Vector2(128, 820), "입구 물 = (128, 820)")
	_확인(s["출"].get("크기") == Vector2(32, 260), "출구 물 = (32, 260) — 서로 안 섞인다")
	s["판"].queue_free()
	await physics_frame


func _출구_폭_음수1() -> void:
	print("\n── 출구 폭 -1 = 유체가 가진 폭을 그대로 둔다")
	var s := await _판_만들기()
	var h: Node2D = s["호"]
	h.set("출구_물줄기_폭", -1.0)
	s["출"].set("크기", Vector2(200, 400))
	h.set("출구_물줄기_길이", 300.0)          # 길이만 밀어 넣는다
	await physics_frame
	_확인(s["출"].get("크기") == Vector2(200, 300), "폭 200 은 살아 있고 길이만 300 으로 바뀐다")
	s["판"].queue_free()
	await physics_frame


func _짧은_물_경고() -> void:
	print("\n── ★짧은 입구 물: 경고가 떠야 한다")
	var s := await _판_만들기()
	var h: Node2D = s["호"]
	var 필요: float = h.call("입구까지_필요한_길이")
	_확인(필요 > 0.0, "입구까지 필요한 길이 = %.0fpx" % 필요)

	h.set("입구_물줄기_길이", 900.0)
	await physics_frame
	var 경고1: PackedStringArray = h.call("_get_configuration_warnings")
	_확인(경고1.is_empty(), "900px 는 닿는다 → 경고 없음")

	h.set("입구_물줄기_길이", maxf(필요 - 100.0, 8.0))
	await physics_frame
	var 경고2: PackedStringArray = h.call("_get_configuration_warnings")
	_확인(경고2.size() == 1 and 경고2[0].contains("안 닿는다"),
		"100px 모자라게 줄이면 경고가 뜬다")
	if not 경고2.is_empty():
		print("      → %s" % 경고2[0])
	s["판"].queue_free()
	await physics_frame


func _물_없는_발판은_조용하다() -> void:
	print("\n── 물 없이 발판으로만 쓰는 호퍼: 경고가 뜨면 안 된다")
	var 판 := Node2D.new()
	root.add_child(판)
	var h: Node2D = (load(호퍼_씬) as PackedScene).instantiate()
	h.name = "대기발판"
	판.add_child(h)
	h.position = Vector2(0, 1000)
	await physics_frame
	var 경고: PackedStringArray = h.call("_get_configuration_warnings")
	_확인(경고.is_empty(), "들어오는 물이 아예 없어도 조용하다 (가짜 경고 없음)")
	판.queue_free()
	await physics_frame
