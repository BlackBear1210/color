extends SceneTree
## ============================================================================
## [2026-08-30 신규] STAGE 1 구간 1-1 **런타임 시험**
## ----------------------------------------------------------------------------
## 실행: godot --headless --path . -s res://tools/시험_1_1_런타임.gd
##
## ▣ 왜 만들었나
##   `레벨검사.gd` 는 레이캐스트로 지형을 **모델링해서** 도달 가능성을 계산한다.
##   그건 "이론상 갈 수 있다" 까지고, **진짜 물리 위에서 진짜 입력으로 가는지**는 다르다
##   (floor_snap · 벽 미끄러짐 · 코요테 타임 · 점프 버퍼가 전부 개입한다).
##   → 실제 스테이지 씬을 띄우고(= 월드.gd·사망 판정·카메라까지 전부 살아 있는 상태),
##     `Input.action_press()` 로 사람처럼 조작해 본다.
##
## ⚠ 이 도구는 아무것도 고치지 않는다. 재서 PASS/FAIL 만 보고한다.
## ============================================================================

const 씬경로 := "res://scenes/집/스테이지_1_2층방.tscn"

## 지형 윗면 실측 기대값 (빌더 상수와 같아야 한다).
const 발판들 := [
	["SS_BRICK_LEDGE_A_01", 160.0, -2400.0],
	["SS_BRICK_LEDGE_B_01", 620.0, -2290.0],
	["SS_WOOD_BOOKSHELF_01(낮은)", 1050.0, -1943.0],
	["SS_WOOD_BOOKSHELF_01(중간)", 1350.0, -2053.0],
	["SS_WOOD_WARDROBE_01(높은)", 1850.0, -2163.0],
	["SS_WOOD_WARDROBE_01(중간)", 2250.0, -2053.0],
	["SS_BRICK_SPIKE_BASE_01", 2750.0, -1943.0],
	["SS_BRICK_LEDGE_EXIT_01", 3220.0, -1860.0],
]

var _루트: Node = null
var _p: CharacterBody2D = null
var _결과: Array = []


func _init() -> void:
	Engine.max_fps = 0
	call_deferred("_실행")


func _실행() -> void:
	print("\n════════ STAGE 1 · 구간 1-1 런타임 시험 ════════")
	var 씬: PackedScene = load(씬경로)
	if 씬 == null:
		print("  ✗ 씬 로드 실패"); quit(1); return
	_루트 = 씬.instantiate()
	root.add_child(_루트)
	await process_frame
	await physics_frame
	_p = _루트.get_node_or_null("Player") as CharacterBody2D
	if _p == null:
		print("  ✗ Player 노드를 못 찾음"); quit(1); return

	await _시험_스폰()
	await _시험_이동()
	await _시험_점프()
	await _시험_발판_착지()
	await _시험_벽충돌()
	await _시험_천장충돌()
	await _시험_구간별_점프()
	await _시험_주파()

	print("\n──────────────── 결과 ────────────────")
	var 실패 := 0
	for r in _결과:
		print("  %-22s %s   %s" % [r[0], "PASS" if r[1] else "✗ FAIL", r[2]])
		if not r[1]:
			실패 += 1
	print("  ─────────────────────────────────────")
	print("  %d / %d PASS" % [_결과.size() - 실패, _결과.size()])
	print("════════════════════════════════════════════════\n")
	quit(0 if 실패 == 0 else 1)


# ── 도우미 ──────────────────────────────────────────────────────────────────
func _기록(이름: String, 통과: bool, 메모: String) -> void:
	_결과.append([이름, 통과, 메모])

func _해제() -> void:
	for a in ["move_left", "move_right", "jump"]:
		if Input.is_action_pressed(a):
			Input.action_release(a)

## 플레이어를 그 자리에 세우고 속도를 지운다. (월드의 리스폰이 끼어들지 않게 안전한 공중에)
func _놓기(자리: Vector2) -> void:
	_해제()
	_p.velocity = Vector2.ZERO
	_p.global_position = 자리
	await physics_frame

func _프레임(n: int) -> void:
	for i in n:
		await physics_frame

## 바닥에 닿을 때까지 최대 n 프레임 기다린다. 닿았으면 true.
func _착지_대기(n: int = 240) -> bool:
	for i in n:
		await physics_frame
		if _p.is_on_floor():
			return true
	return false


# ── 1) 스폰 ─────────────────────────────────────────────────────────────────
func _시험_스폰() -> void:
	var 시작: Vector2 = _루트.get("시작_위치")
	var 자리 := _p.global_position
	var 닿음 := await _착지_대기(120)
	_기록("Spawn", 닿음 and 자리.distance_to(시작) < 600.0,
		"시작_위치=%s · 실제=%s · 착지 y=%.1f" % [시작, 자리, _p.global_position.y])


# ── 2) 좌우 이동 ────────────────────────────────────────────────────────────
## ⚠ 반드시 **평평한 곳**에서 재야 한다. 처음에 책장 낮은 단(900…1200) 위에서 쟀더니
##   오른쪽으로 124px 만 가고 멈췄다 — 1200 에 있는 한 칸(110) 벽면에 막힌 것이었다.
##   이 게임에는 자동 계단 오르기가 없다(단차는 점프로 오른다). 도구 쪽 실수였다.
func _시험_이동() -> void:
	await _놓기(Vector2(400.0, -100.0))      # 방바닥. x 0…900 이 평평하다
	await _착지_대기()
	var x0 := _p.global_position.x
	Input.action_press("move_right")
	await _프레임(30)                          # 0.5 초
	Input.action_release("move_right")
	var 오른 := _p.global_position.x - x0
	await _프레임(5)
	var x1 := _p.global_position.x
	Input.action_press("move_left")
	await _프레임(30)
	Input.action_release("move_left")
	var 왼 := x1 - _p.global_position.x
	# 390px/s × 0.5s = 195px 가 이론값. 마찰·스냅으로 조금 줄 수 있다.
	_기록("Move", 오른 > 150.0 and 왼 > 150.0,
		"오른쪽 %.1fpx · 왼쪽 %.1fpx (0.5초씩 · 이론 195)" % [오른, 왼])


# ── 3) 점프 ─────────────────────────────────────────────────────────────────
func _시험_점프() -> void:
	await _놓기(Vector2(1050.0, -2043.0))
	await _착지_대기()
	var y0 := _p.global_position.y
	# ⚠ **끝까지 누르고 있어야** 최대 높이가 나온다. 처음에 4 프레임 만에 뗐더니 73px 이
	#   나왔는데, 그건 player.gd 의 가변 점프(JUMP_CUT_MULTIPLIER 0.4)가 제대로 작동한
	#   결과였다 — 지형 문제가 아니라 도구 쪽 실수였다.
	Input.action_press("jump")
	var 최고 := y0
	for i in 90:
		await physics_frame
		최고 = minf(최고, _p.global_position.y)
	Input.action_release("jump")
	var 높이 := y0 - 최고
	# 실측 MAX_JUMP_HEIGHT = 167.24. 여유 15% 를 준다.
	_기록("Jump", 높이 > 140.0, "최고 높이 %.1fpx (실측 기준 167.2)" % 높이)


# ── 4) 착지 + 5) Wood/Brick 콜리전 ──────────────────────────────────────────
## 발판 8 개 각각의 **가운데 위 300px 에서 떨어뜨려** 예상한 윗면에 서는지 본다.
## 이것이 "Texture 와 Collision 이 어긋나지 않았나" 의 실질 검증이다 —
## 지형이 그림보다 위/아래에 있으면 착지 y 가 그만큼 어긋난다.
func _시험_발판_착지() -> void:
	var 나무_ok := true
	var 벽돌_ok := true
	var 착지_ok := true
	var 상세: Array = []
	for f in 발판들:
		var 이름: String = f[0]
		var x: float = f[1]
		var 예상: float = f[2]
		await _놓기(Vector2(x, 예상 - 300.0))
		var 닿음 := await _착지_대기(200)
		var 오차: float = _p.global_position.y - 예상
		var 통과: bool = 닿음 and absf(오차) < 6.0
		상세.append("%s %+.1f" % [이름.split("_")[-1], 오차])
		if not 통과:
			착지_ok = false
			if 이름.contains("WOOD"):
				나무_ok = false
			else:
				벽돌_ok = false
	_기록("Landing", 착지_ok, "발판 8 개 모두 예상 윗면에 안착")
	_기록("Wood Collision", 나무_ok, "책장 2 단 · 옷장 2 단 · 오차 < 6px")
	_기록("Brick Collision", 벽돌_ok, "선반A/B · 가시받침 · 출구선반 · 오차 < 6px")
	print("    [착지 오차] %s" % ", ".join(상세))


# ── 6) 외벽 충돌 ────────────────────────────────────────────────────────────
## 문턱(−2400) 위에서 왼쪽으로 계속 밀어 본다. 바깥 벽(x −500)을 못 뚫어야 한다.
func _시험_벽충돌() -> void:
	await _놓기(Vector2(-300.0, -2450.0))
	await _착지_대기()
	Input.action_press("move_left")
	await _프레임(120)                          # 2 초 = 780px 분
	Input.action_release("move_left")
	var x := _p.global_position.x
	# 벽 안쪽 면 x = −500. 몸 반폭 22 → 최소 −478 에서 멈춘다.
	_기록("Brick Wall", x > -500.0,
		"2초간 왼쪽으로 밀었을 때 x=%.1f (벽 안쪽면 −500)" % x)


# ── 7) 천장(들보) 충돌 ──────────────────────────────────────────────────────
## 출구 선반(−1860) 위에서 점프하면 들보(아랫면 −2030)에 머리가 막혀야 한다.
## 안 막히면 점프 높이 167 만큼 올라 −2027 까지 간다.
func _시험_천장충돌() -> void:
	await _놓기(Vector2(3220.0, -1900.0))
	await _착지_대기()
	var y0 := _p.global_position.y
	Input.action_press("jump")
	var 최고 := y0
	for i in 60:
		await physics_frame
		최고 = minf(최고, _p.global_position.y)
	Input.action_release("jump")
	var 오름 := y0 - 최고
	# 들보 콜리전 아랫면 ≈ −2006(=−2030+24) · 몸 높이 95.63 → 발바닥은 −1910 까지만.
	# 막히면 오름 ≈ 50, 안 막히면 ≈ 167.
	_기록("Ceiling Collision", 오름 < 90.0,
		"들보 아래 점프 상승 %.1fpx (막히면 ~50 · 안 막히면 ~167)" % 오름)


# ── 8) 구간별 점프 — 어느 틈이 실제로 어려운지 짚어낸다 ────────────────────
## 봇 주파는 "된다/안 된다" 만 알려준다. 틈마다 따로 재야 **어디가** 문제인지 나온다.
## 조작: 출발 발판 왼쪽에서 오른쪽 키를 누른 채 달리다가, 발판 오른쪽 끝 60px 앞에서
##       점프를 누르고 끝까지 유지한다(사람이 하는 것과 같다).
func _시험_구간별_점프() -> void:
	# [이름, 출발x, 출발 윗면y, 출발 오른쪽끝, 목표 윗면y, 목표 x 최소]
	var 구간 := [
		["선반A→선반B", 60.0, -2400.0, 320.0, -2290.0, 470.0],
		["선반B→책장", 500.0, -2290.0, 770.0, -1943.0, 900.0],
		["책장→옷장", 1230.0, -2053.0, 1500.0, -2163.0, 1650.0],
		["옷장→가시받침", 2080.0, -2053.0, 2450.0, -1943.0, 2600.0],
		["가시받침→출구", 2630.0, -1943.0, 2900.0, -1860.0, 3050.0],
	]
	var 전부 := true
	var 상세: Array = []
	for c in 구간:
		var 이름: String = c[0]
		await _놓기(Vector2(float(c[1]), float(c[2]) - 40.0))
		await _착지_대기(120)
		Input.action_press("move_right")
		var 뛰었나 := false
		for i in 240:
			await physics_frame
			if not 뛰었나 and _p.global_position.x > float(c[3]) - 60.0:
				Input.action_press("jump")
				뛰었나 = true
			# 목표 발판에 안착했으면 끝
			if 뛰었나 and _p.is_on_floor() and _p.global_position.x > float(c[5]):
				break
		_해제()
		await _프레임(10)
		var y := _p.global_position.y
		var x := _p.global_position.x
		var 통과: bool = _p.is_on_floor() and x > float(c[5]) and absf(y - float(c[4])) < 8.0
		상세.append("%s %s(x %.0f y %.0f)" % [이름, "✔" if 통과 else "✗", x, y])
		if not 통과:
			전부 = false
	_기록("Gap Jumps", 전부, "틈 5 개 전부 달리기+점프로 건넜다")
	for s in 상세:
		print("    [틈] %s" % s)


# ── 9) 1-2 방향 주파 ────────────────────────────────────────────────────────
## 사람처럼 "오른쪽 누른 채로 착지할 때마다 점프" 하는 봇으로 1-1 을 끝까지 가 본다.
## ⚠ 최적 조작이 아니다. 이 봇이 통과하면 **여유 있게 통과 가능**하다는 뜻이고,
##   못 가면 그 x 좌표가 실제로 어려운 자리다.
func _시험_주파() -> void:
	var 시작: Vector2 = _루트.get("시작_위치")
	await _놓기(시작)
	await _착지_대기()
	var 최대x := _p.global_position.x
	var 죽음 := 0
	var 이전y := _p.global_position.y
	Input.action_press("move_right")
	for i in 1500:                              # 25 초
		await physics_frame
		if _p.is_on_floor():
			Input.action_press("jump")
		else:
			Input.action_release("jump")
		최대x = maxf(최대x, _p.global_position.x)
		# 리스폰되면 y 가 갑자기 크게 튄다 — 사망 횟수로 센다
		if absf(_p.global_position.y - 이전y) > 900.0:
			죽음 += 1
		이전y = _p.global_position.y
	_해제()
	# 출구 선반 오른쪽 끝 = 3396. 3300 을 넘으면 1-1 을 끝까지 간 것이다.
	_기록("1-2 Direction", 최대x > 3300.0,
		"봇이 도달한 최대 x = %.0f (출구선반 3050…3396) · 리스폰 %d 회" % [최대x, 죽음])
