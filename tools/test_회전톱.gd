extends SceneTree
## ============================================================================
## [2026-09-12 신규] 회전톱이 **스마트월드(월드.gd)** 에서 죽이는지 실측 (헤드리스)
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/test_회전톱.gd
##
## ▣ 왜 만들었나
##   `scenes/장애물/회전톱.tscn` 은 v3(stage_lab) 시절 장애물이다. 스마트월드는
##   `월드.gd:322` 의 `hazard` 그룹 루프로 가시를 죽이는데, 회전톱도 같은 그룹·
##   같은 Area2D 구조라 "아마 될 것" 이었다. 하수도 분기형 맵 가이드에 "검증됨" 으로
##   올리려면 실측이 있어야 한다(도형 지시: 회전톱도 넣자).
##
## ▣ 검사하는 것
##   A. 톱날 위에 서면 죽는다 (색과 무관 — 검정·흰색 둘 다)
##   B. 판정 반지름(반지름 × 0.72) 밖이면 안 죽는다
##   C. 왕복 이동 중인 톱도 잡힌다 (이동거리 > 0)
##   D. 칠할 수 없다 — 지형이 아니므로 `명중` 이 없다 (색으로 무력화 불가)
## ============================================================================

const 월드_S := preload("res://scripts/스마트월드/월드.gd")
const 코어_S := preload("res://scripts/스마트월드/페인트_코어.gd")
const 톱_씬 := preload("res://scenes/장애물/회전톱.tscn")
const 플레이어_씬 := preload("res://scenes/player/Player.tscn")

var 실패 := 0
var 총 := 0


func 확인(이름: String, 조건: bool) -> void:
	총 += 1
	print(("  PASS  " if 조건 else "  FAIL  ") + 이름)
	if not 조건:
		실패 += 1


func _init() -> void:
	Engine.max_fps = 60
	call_deferred("_실행")


func _실행() -> void:
	print("\n=== 회전톱 · 스마트월드 사망 검사 ===")
	var 월드 := _스테이지_만들기()
	await physics_frame

	# 톱을 (600, 0) 에 놓는다. 반지름 40 → 판정 28.8
	var 톱: Area2D = 톱_씬.instantiate()
	톱.name = "톱_1"
	톱.position = Vector2(600, 0)
	톱.set("반지름", 40.0)
	톱.set("이동거리", 0.0)
	월드.add_child(톱)
	await physics_frame
	await physics_frame

	확인("톱이 hazard 그룹에 들어갔다", 톱.is_in_group("hazard"))
	확인("톱에 콜리전이 생겼다", 톱.get_child_count() > 0 and 톱.get_children().any(func(c): return c is CollisionShape2D))

	# A. 검정 플레이어 · 톱 중심
	await _세우기(월드, Vector2(600, 0), ColorDefs.BLACK)
	확인("★A 검정 플레이어가 톱에 닿으면 죽는다", _죽나(월드))
	# A'. 흰색도 같다 — 색과 무관
	await _세우기(월드, Vector2(600, 0), ColorDefs.WHITE)
	확인("★A 흰색 플레이어도 죽는다 (색 무관)", _죽나(월드))

	# B. 판정 밖 — 톱 판정 28.8 + 플레이어 반폭 25 ≈ 54. 200px 옆이면 안전
	await _세우기(월드, Vector2(800, 0), ColorDefs.BLACK)
	확인("B 200px 옆에 서면 안 죽는다", not _죽나(월드))

	# C. 왕복 이동 톱 — 시작점에서 200 오른쪽까지 움직인다. 플레이어를 경로 중간에 세우고 기다린다
	var 톱2: Area2D = 톱_씬.instantiate()
	톱2.name = "톱_2"
	톱2.position = Vector2(1500, 0)
	톱2.set("반지름", 40.0)
	톱2.set("이동거리", 400.0)
	톱2.set("이동방향", 0)
	톱2.set("왕복시간", 1.0)
	월드.add_child(톱2)
	await physics_frame
	await _세우기(월드, Vector2(1650, 0), ColorDefs.BLACK)   # 경로(1300~1700) 안, 시작점 밖
	var 잡혔다 := false
	for i in 90:                 # 1.5초 — 한 왕복 안에 반드시 지나간다
		await physics_frame
		if _죽나(월드):
			잡혔다 = true
			break
	확인("★C 왕복 이동 중인 톱도 죽인다", 잡혔다)

	# D. 칠할 수 없다
	확인("D 톱은 지형이 아니라 `명중` 이 없다 (칠해서 무력화 불가)", not 톱.has_method("명중"))

	print("---")
	print("결과: %d / %d 통과%s" % [총 - 실패, 총, "" if 실패 == 0 else "  ← %d개 실패" % 실패])
	quit(1 if 실패 > 0 else 0)


# ── 공통 (test_사망판정.gd 와 같은 수법) ──────────────────────────────────────
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
	# 월드가 스스로 리스폰하면 세워 둔 좌표가 사라지므로 판정만 직접 부른다
	월드.set_physics_process(false)
	return 월드


func _세우기(월드: Node2D, 좌표: Vector2, 색: int) -> void:
	var p: Node2D = 월드.get_node("Player")
	p.set("velocity", Vector2.ZERO)
	p.global_position = 좌표
	p.set("player_color", 색)
	await physics_frame
	await physics_frame


func _죽나(월드: Node2D) -> bool:
	return bool(월드.call("_사망_판정"))
