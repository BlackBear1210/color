extends SceneTree
## ============================================================================
## [2026-09-12 신규] 압력버튼 → 발판 이동 실측 (헤드리스)
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/test_버튼승강기.gd
##
## ▣ 도형 지시
##   "압력버튼이 눌려 있는 동안 내가 지정한 플랫폼이 지정한 방향(상하좌우)으로 움직인다."
##
## ▣ 무엇을 확인하나 — 새 코드 없이 되는가
##   `압력버튼.gd` 는 이미 `대상들`+`대상_이동량들` 로 아무 Node2D 나 움직이고,
##   떼면 되돌린다. 문제는 **플레이어를 태우느냐**다:
##   · SS2D 지형(StaticBody2D)을 움직이면 위에 선 플레이어를 **못 태운다**(`움직이는발판.gd` 머리 주석).
##   · `움직이는발판.tscn`(AnimatableBody2D · sync_to_physics) 을 `이동거리 = 0` 으로 두고
##     버튼의 대상으로 삼으면 태울 것이다 — 이걸 실측한다.
##
## ▣ 검사
##   A. 박스가 버튼에 올라가면 버튼이 활성이 된다
##   B. 발판이 지정 방향(위 300px)으로 움직인다
##   C. ★발판 위의 플레이어가 **같이 실려 간다**
##   D. 박스를 치우면 발판이 원위치로 돌아온다
##   E. (대조) SS2D 지형을 대상으로 하면 플레이어는 안 실린다 — 문/벽 용도로만
## ============================================================================

const 지형공통_S := preload("res://tools/지형공통.gd")
const 월드_S := preload("res://scripts/스마트월드/월드.gd")
const 코어_S := preload("res://scripts/스마트월드/페인트_코어.gd")
const 버튼_S := preload("res://scripts/스마트월드/압력버튼.gd")
const 발판_씬 := preload("res://scenes/집/스마트월드_장애물/움직이는발판.tscn")
const 박스_씬 := preload("res://scenes/집/스마트월드_장애물/박스.tscn")
const 플레이어_씬 := preload("res://scenes/player/Player.tscn")

var 실패 := 0
var 총 := 0


func 확인(이름: String, 조건: bool, 덧붙임: String = "") -> void:
	총 += 1
	print(("  PASS  " if 조건 else "  FAIL  ") + 이름 + ("   " + 덧붙임 if 덧붙임 != "" else ""))
	if not 조건:
		실패 += 1


func _init() -> void:
	Engine.max_fps = 60
	call_deferred("_실행")


func _실행() -> void:
	print("\n=== 압력버튼 → 발판 이동 · 플레이어 탑승 검사 ===")
	await _승강기_검사()
	await _지형대조_검사()
	print("---")
	print("결과: %d / %d 통과%s" % [총 - 실패, 총, "" if 실패 == 0 else "  ← %d개 실패" % 실패])
	quit(1 if 실패 > 0 else 0)


func _승강기_검사() -> void:
	print("\n[1] 움직이는발판(이동거리 0) 을 버튼 대상으로")
	var 월드 := _스테이지_만들기()
	await physics_frame
	# 바닥: x -400~1400, 윗면 y=0
	_지형_붙이기(월드, Vector2(500, 0), 1800.0, 200.0)
	# 버튼: 바닥 위 x=200. 사용법 §2 "position.y = 바닥_y + 24"
	var 버튼 := AnimatableBody2D.new()
	버튼.set_script(버튼_S)
	버튼.name = "버튼"
	버튼.position = Vector2(200, 24)
	버튼.set("작동방식", 0)                                  # 누르는 동안만
	버튼.set("누름_가능_그룹", PackedStringArray(["박스"]))
	월드.add_child(버튼)
	# 발판: 공중 x=900, y=-300. 이동거리 0 → 스스로는 안 움직인다
	var 발판: Node2D = 발판_씬.instantiate()
	발판.name = "승강기"
	발판.position = Vector2(900, -300)
	발판.set("이동거리", 0.0)
	발판.set("크기", Vector2(240, 28))
	월드.add_child(발판)
	var 대상경로: Array[NodePath] = [NodePath("../승강기")]
	버튼.set("대상들", 대상경로)   # ⚠ 타입 배열엔 타입 배열로 — 무타입 [] 는 조용히 무시된다
	var 이동량: Array[Vector2] = [Vector2(0, -300)]
	버튼.set("대상_이동량들", 이동량)         # 위로 300
	버튼.set("이동속도", 600.0)
	await physics_frame
	await physics_frame
	# 버튼이 대상을 다시 잇게 한다(_ready 때 대상들이 비어 있었다)
	if 버튼.has_method("_대상_연결_갱신"):
		버튼.call("_대상_연결_갱신")
	# 플레이어를 발판 위에 세운다 (발판 윗면 y = -314, 콜리전 높이 47 → 중심 ≈ -338)
	await _세우기(월드, Vector2(900, -340), ColorDefs.BLACK)
	for i in 20:
		await physics_frame
	var p: Node2D = 월드.get_node("Player")
	var 플레이어_전 := p.global_position.y
	var 발판_전 := 발판.position.y
	확인("(전제) 플레이어가 발판 위에 서 있다", absf(플레이어_전 - (-340.0)) < 30.0, "y=%.0f" % 플레이어_전)

	# 박스를 버튼 위에 떨어뜨린다
	var 박스: Node2D = 박스_씬.instantiate()
	박스.name = "박스"
	박스.position = Vector2(200, -80)
	월드.add_child(박스)
	for i in 40:
		await physics_frame
	확인("A 박스가 올라가자 버튼이 활성", bool(버튼.call("활성인가")))
	for i in 60:                                    # 1초 — 300px / 600px·s 면 0.5초
		await physics_frame
	var 발판_후 := 발판.position.y
	확인("B 발판이 위로 300 움직였다", absf((발판_전 - 발판_후) - 300.0) < 8.0, "Δ=%.0f" % (발판_전 - 발판_후))
	var 플레이어_후 := p.global_position.y
	확인("★C 발판 위 플레이어가 같이 실려 올라갔다", (플레이어_전 - 플레이어_후) > 250.0, "Δ=%.0f" % (플레이어_전 - 플레이어_후))

	# 박스를 치운다 → 되돌아온다
	박스.queue_free()
	for i in 80:
		await physics_frame
	확인("D 박스를 치우면 발판이 원위치", absf(발판.position.y - 발판_전) < 8.0, "y=%.0f" % 발판.position.y)
	확인("D 플레이어도 같이 내려왔다", absf(p.global_position.y - 플레이어_전) < 40.0, "y=%.0f" % p.global_position.y)
	월드.queue_free()
	await physics_frame


func _지형대조_검사() -> void:
	print("
[2] 방향별 탑승 매트릭스 — 발판 종류 × 이동 방향")
	# 도형 지시 "상하좌우 지정한 방향" 이므로 네 방향 다 잰다.
	# 예상: AnimatableBody2D(움직이는발판) 는 전부 태운다. StaticBody2D(SS2D 지형) 는
	#       위·아래는 되지만 **옆으로는 플레이어를 두고 간다** (실측 2026-09-12).
	for 종류 in ["움직이는발판", "SS2D지형"]:
		for 방향 in [["위", Vector2(0, -300)], ["아래", Vector2(0, 300)], ["오른쪽", Vector2(300, 0)], ["왼쪽", Vector2(-300, 0)]]:
			var 실림 := await _한번(종류, 방향[1])
			# SS2D 지형(StaticBody2D)은 위(밀어 올림)·아래(중력이 따라감)는 태우지만 옆으로는 두고 간다
			var 기대: bool = true if 종류 == "움직이는발판" else (방향[0] == "위" or 방향[0] == "아래")
			확인("%s · %s → %s" % [종류, 방향[0], "태운다" if 실림 else "두고 간다"], 실림 == 기대,
				"" if 실림 == 기대 else "(기대와 다름)")


## 한 조합을 격리된 월드에서 재고 "플레이어가 발판과 함께 ≥ 250px 움직였나" 를 돌려준다.
func _한번(종류: String, 이동량: Vector2) -> bool:
	var 월드 := _스테이지_만들기()
	await physics_frame
	_지형_붙이기(월드, Vector2(500, 0), 1800.0, 200.0)
	var 버튼 := AnimatableBody2D.new()
	버튼.set_script(버튼_S)
	버튼.name = "버튼"
	버튼.position = Vector2(200, 24)
	버튼.set("작동방식", 0)
	버튼.set("누름_가능_그룹", PackedStringArray(["박스"]))
	월드.add_child(버튼)
	var 발판: Node2D
	if 종류 == "움직이는발판":
		발판 = 발판_씬.instantiate()
		발판.set("이동거리", 0.0)
		발판.set("크기", Vector2(240, 28))
		발판.position = Vector2(900, -600)
		월드.add_child(발판)
	else:
		발판 = _지형_붙이기(월드, Vector2(900, -600), 240.0, 60.0)
	발판.name = "대상"
	var 경로: Array[NodePath] = [NodePath("../대상")]
	var 량: Array[Vector2] = [이동량]
	버튼.set("대상들", 경로)
	버튼.set("대상_이동량들", 량)
	버튼.set("이동속도", 600.0)
	await physics_frame
	await physics_frame
	버튼.call("_대상_연결_갱신")
	await _세우기(월드, Vector2(900, -640), ColorDefs.BLACK)
	for i in 20:
		await physics_frame
	var p: Node2D = 월드.get_node("Player")
	var 전 := p.global_position
	var 박스: Node2D = 박스_씬.instantiate()
	박스.position = Vector2(200, -80)
	월드.add_child(박스)
	for i in 100:
		await physics_frame
	var 이동 := p.global_position - 전
	var 실림 := 이동.dot(이동량.normalized()) > 250.0
	월드.queue_free()
	await physics_frame
	return 실림


# ── 공통 ─────────────────────────────────────────────────────────────────────
func _스테이지_만들기() -> Node2D:
	var 월드 := Node2D.new()
	월드.set_script(월드_S)
	월드.name = "테스트월드"
	월드.set("치명_낙하거리", 0.0)
	월드.set("낙사_y", 100000.0)
	월드.set("안전지점_자동저장", false)
	월드.set("시작_위치", Vector2(0, 0))
	var 코어 := Node.new()
	코어.set_script(코어_S)
	코어.name = "페인트코어"
	코어.add_to_group("페인트코어")
	월드.add_child(코어)
	var p := 플레이어_씬.instantiate()
	p.name = "Player"
	월드.add_child(p)
	root.add_child(월드)
	월드.set_physics_process(false)
	return 월드


func _지형_붙이기(월드: Node2D, 위치: Vector2, 폭: float, 높이: float) -> Node2D:
	var 재질 := 지형공통_S.재질_준비("기본")
	var 점들 := PackedVector2Array([
		Vector2(-폭 * 0.5, 0), Vector2(폭 * 0.5, 0),
		Vector2(폭 * 0.5, 높이), Vector2(-폭 * 0.5, 높이),
	])
	var 지형 := 지형공통_S.지형_노드("검사지형", 위치, 점들, 재질, true, false, 1, 8.0)
	월드.add_child(지형)
	return 지형


func _세우기(월드: Node2D, 좌표: Vector2, 색: int) -> void:
	var p: Node2D = 월드.get_node("Player")
	p.set("velocity", Vector2.ZERO)
	p.global_position = 좌표
	p.set("player_color", 색)
	await physics_frame
	await physics_frame
