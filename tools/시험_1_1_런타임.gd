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
	["벽계단A", 500.0, -2050.0],
	["벽계단B", 1100.0, -1830.0],
	["옷장", 1930.0, -1522.0],
	["서랍(열림)", 2447.0, -1522.0],
	["가시받침", 2850.0, -1632.0],
	["출구선반", 3770.0, -1742.0],
	["1-2 기둥코벨", 4325.0, -1740.0],
	["1-2 창윗틀", 5000.0, -1740.0],
	["1-2 커튼주름1", 5250.0, -1380.0],
	["1-2 커튼주름2", 5450.0, -1020.0],
	["1-2 커튼주름3", 5150.0, -900.0],
	["1-2 창턱", 5070.0, -537.0],
	["1-2 탁자", 5745.0, -319.0],
	["1-2 바닥", 4000.0, 0.0],
]

var _루트: Node = null
var _p: CharacterBody2D = null
var _결과: Array = []
var _최대드리프트: float = 0.0
var _지상y: float = 0.0


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
	await _시험_완주()
	await _시험_색칠()
	await _시험_색사망()
	await _시험_배경()
	await _시험_서랍()
	await _시험_가시()
	await _시험_가구밑()
	await _시험_1_4()
	await _시험_STAGE1_완주()

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
	await _놓기(Vector2(700.0, -100.0))      # 방바닥. x 300…1566 이 평평하다
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
	await _놓기(Vector2(1930.0, -1622.0))   # 옷장 위
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
		# ⚠ 낙하 높이 150. 300 으로 뒀더니 **위 발판 안**에 스폰돼 밀려 올라갔다
		#   (커튼 주름은 360 간격에 두께 160 이라 빈 공간이 200 뿐이다).
		await _놓기(Vector2(x, 예상 - 150.0))
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
	_기록("Landing", 착지_ok, "발판 %d 개 모두 예상 윗면에 안착" % 발판들.size())
	_기록("Wood Collision", 나무_ok, "옷장·서랍·창윗틀·커튼주름·창턱·탁자·바닥 · 오차 < 6px")
	_기록("Brick Collision", 벽돌_ok, "벽계단A/B · 가시받침 · 출구선반 · 기둥코벨 · 오차 < 6px")
	print("    [착지 오차] %s" % ", ".join(상세))


# ── 6) 외벽 충돌 ────────────────────────────────────────────────────────────
## 문턱(−2400) 위에서 왼쪽으로 계속 밀어 본다. 바깥 벽(x −500)을 못 뚫어야 한다.
func _시험_벽충돌() -> void:
	await _놓기(Vector2(200.0, -2100.0))
	await _착지_대기()
	Input.action_press("move_left")
	await _프레임(120)                          # 2 초 = 780px 분
	Input.action_release("move_left")
	var x := _p.global_position.x
	# 구멍 마개(0…100) 안쪽 면 x = 100. 몸 반폭 22 → 122 에서 멈춘다.
	# ★0 이하로 가면 원화 밖 허공으로 떨어진다 = 이 시험이 그걸 막는다.
	_기록("Brick Wall", x > 100.0,
		"2초간 왼쪽으로 밀었을 때 x=%.1f (구멍 마개 안쪽면 100)" % x)


# ── 7) 천장(들보) 충돌 ──────────────────────────────────────────────────────
## 출구 선반(−1860) 위에서 점프하면 들보(아랫면 −2030)에 머리가 막혀야 한다.
## 안 막히면 점프 높이 167 만큼 올라 −2027 까지 간다.
func _시험_천장충돌() -> void:
	# ★들보는 x 3697…3997 에 있다. 그 **바로 아래**에서 재야 한다.
	await _놓기(Vector2(3770.0, -1790.0))
	await _착지_대기()
	var y0 := _p.global_position.y
	Input.action_press("jump")
	var 최고 := y0
	for i in 60:
		await physics_frame
		최고 = minf(최고, _p.global_position.y)
	Input.action_release("jump")
	var 오름 := y0 - 최고
	# 들보 아랫면 −1912 · 몸 높이 95.63 → 발바닥은 −1816 까지만 오른다(약 74px).
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
		["Gap1 벽계단A→B", 350.0, -2050.0, 700.0, -1830.0, 850.0],
		["Gap2 벽계단B→옷장", 900.0, -1830.0, 1390.0, -1522.0, 1566.0],
		["Gap3 서랍→가시받침", 2320.0, -1522.0, 2597.0, -1632.0, 2747.0],
		["Gap4 받침→출구", 3200.0, -1632.0, 3397.0, -1742.0, 3547.0],
		["1-2 Gap5 출구→코벨", 3600.0, -1742.0, 3997.0, -1740.0, 4147.0],
		["1-2 Gap6 코벨→창윗틀", 4180.0, -1740.0, 4504.0, -1740.0, 4654.0],
		["1-2 Gap7 창턱→탁자", 4750.0, -537.0, 5450.0, -319.0, 5600.0],
	]
	var 전부 := true
	var 상세: Array = []
	var 서랍 := _루트.get_node_or_null("기믹/서랍_옷장")
	for c in 구간:
		var 이름: String = c[0]
		await _놓기(Vector2(float(c[1]), float(c[2]) - 40.0))
		await _착지_대기(120)
		# ★서랍을 건너는 틈은 **열릴 때까지 기다렸다가** 출발한다.
		#   안 기다리면 옷장 끝에서 그대로 떨어져 죽는다(실측: 리스폰돼 x 1498 로 튀었다).
		# ★서랍을 건너는 틈은 **막 열린 순간**에 출발한다.
		#   그냥 "열려 있으면 출발" 로 하면 이미 1.1 초 지난 열림일 수 있어
		#   달려가는 도중에 닫혀 떨어진다(실측: 리스폰돼 x 1540 으로 튀었다).
		#   → 먼저 **닫히기를** 기다린 뒤, 다시 열리는 순간을 잡는다.
		if 이름.contains("서랍") and 서랍 != null:
			for w in 400:
				if float(서랍.call("열린정도")) < 0.05:
					break
				await physics_frame
			for w in 400:
				if float(서랍.call("열린정도")) > 0.99:
					break
				await physics_frame
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


# ── 9) (삭제) 옛 무작정 봇 — `_시험_완주()` 로 대체했다


# ── 10) 색칠 — 총알이 지형을 칠하는가 · 탄약이 주는가 ───────────────────────
## ▣ 도형님 제보: "색칠 시스템이 안 되고, 플레이어가 쏘는 페인트의 갯수도 줄지 않아."
##   원인은 빌더가 **모든 지형을 `칠하기_허용 = false`(구조물) 로 지었기** 때문이었다.
##   그러면 `지형.명중()` 이 "blocked" 를 돌려주고 `페인트코어` 가 탄약을 **환급**한다.
##   → 발판을 전부 `칠하기_허용 = true` 로 바꾼 뒤, 그 계약을 여기서 직접 검사한다.
##
## ⚠ 총을 마우스로 쏘는 대신 **총알이 부르는 경로 그대로**(`발사_소모` → `명중_처리`)
##   호출한다. 헤드리스에서는 마우스 좌표가 없어 `총.gd` 의 조준이 성립하지 않는다.
func _시험_색칠() -> void:
	var 코어 := _루트.get_tree().get_first_node_in_group("페인트코어")
	if 코어 == null:
		_기록("Paint Ammo", false, "페인트코어를 못 찾음")
		return
	var 발판: Node = _루트.get_node_or_null("지형/SS_WOOD_WARDROBE_01")
	var 구조물: Node = _루트.get_node_or_null("지형/SS_WOOD_FLOOR_01")
	if 발판 == null or 구조물 == null:
		_기록("Paint Ammo", false, "지형 노드를 못 찾음")
		return

	# ① 칠할 수 있는 발판 — 탄약이 줄어야 한다
	var 전: int = 코어.남은_탄약
	코어.발사_소모()
	var 결과: String = 코어.명중_처리(발판, ColorDefs.BLACK, Vector2(1930.0, -1520.0))
	var 후: int = 코어.남은_탄약
	var 칠함:= (결과 == "painted" or 결과 == "progress") and 후 == 전 - 1
	_기록("Paint Ammo", 칠함,
		"옷장 명중 → \"%s\" · 탄약 %d → %d (줄어야 정상)" % [결과, 전, 후])

	# ② 구조물(벽·바닥) — "blocked" 로 튕기고 탄약이 되돌아와야 한다
	var 전2: int = 코어.남은_탄약
	코어.발사_소모()
	var 결과2: String = 코어.명중_처리(구조물, ColorDefs.BLACK, Vector2(700.0, 5.0))
	var 후2: int = 코어.남은_탄약
	_기록("Paint Blocked", 결과2 == "blocked" and 후2 == 전2,
		"바닥(구조물) 명중 → \"%s\" · 탄약 %d → %d (그대로여야 정상)" % [결과2, 전2, 후2])

	# ③ 인스펙터 체크박스가 실제로 씬에 실렸는가
	var 발판_칠: bool = 발판.get("칠하기_허용")
	var 구조_칠: bool = 구조물.get("칠하기_허용")
	_기록("Paint Flag", 발판_칠 == true and 구조_칠 == false,
		"옷장 칠하기_허용=%s · 바닥=%s (인스펙터 체크박스와 같은 값)" % [발판_칠, 구조_칠])


# ── 11) 색 사망 판정 — 반대색 지형을 밟으면 죽는가 ──────────────────────────
## ▣ 도형님 제보: "플레이어가 색을 반전시켰을 때 아래 지형의 색에 따라 사망 판정도 안 되어있고"
##   `색규칙.gd`(2026-08-30): **안 칠한 지형은 무색이 아니라 검정**이다.
##   → 흰색 플레이어가 안 칠한 발판 위에 서면 죽어야 한다.
##   구조물(`칠하기_허용 = false`)은 색 규칙 **밖**이라 안 죽는다 — 이것도 같이 확인한다.
func _시험_색사망() -> void:
	# ① 칠할 수 있는 발판(= 안 칠했으니 검정) 위에서 흰색으로 바꾸면 죽어야 한다
	await _놓기(Vector2(1930.0, -1622.0))     # 옷장 위
	await _착지_대기()
	_p.set("자유색", ColorDefs.BLACK)
	await _프레임(2)
	var 검정일때: bool = _루트.call("_사망_판정")
	# ⚠ 월드는 살아 있어서 사망을 감지하면 **바로 리스폰**한다. 2 프레임 뒤에 읽으면
	#   이미 안전지점으로 옮겨져 false 가 나온다(가시 시험에서 겪은 것과 같은 함정).
	#   → 색을 바꾼 직후부터 여러 프레임을 훑어 한 번이라도 true 면 죽은 것으로 본다.
	_p.set("자유색", ColorDefs.WHITE)
	var 흰색일때 := false
	for i in 10:
		if bool(_루트.call("_사망_판정")):
			흰색일때 = true
			break
		await physics_frame
	_기록("Color Death", (not 검정일때) and 흰색일때,
		"옷장(안 칠함=검정) 위 — 검정 플레이어 죽음=%s · 흰색 플레이어 죽음=%s" % [검정일때, 흰색일때])

	# ② 구조물(바닥) 위에서는 흰색이어도 안 죽어야 한다
	await _놓기(Vector2(700.0, -100.0))
	await _착지_대기()
	_p.set("자유색", ColorDefs.WHITE)
	await _프레임(2)
	var 바닥_흰색: bool = _루트.call("_사망_판정")
	_p.set("자유색", ColorDefs.BLACK)
	_기록("Structure Safe", not 바닥_흰색,
		"바닥(구조물) 위 흰색 플레이어 죽음=%s (false 여야 정상)" % 바닥_흰색)


# ── 12) 배경 구조 — STEP 1-1.6 의 절대 원칙을 기계로 검사한다 ───────────────
## 도형님 §1: room.png 를 **자르지도 · 반복하지도 · 비율을 바꾸지도** 않는다.
##            원화 위에 코드로 방을 다시 그리지 않는다. 앞바닥을 쓰지 않는다.
## 눈으로만 보면 "어두워서 안 보이는 것"과 "안 그려진 것"을 구별할 수 없다 → 값으로 잰다.
func _시험_배경() -> void:
	var 배경들: Array = []
	for c in _모두(_루트):
		var s: Script = c.get_script()
		if s != null and String(s.resource_path).ends_with("실내배경.gd"):
			배경들.append(c)

	# ① 배경 노드가 정확히 1 개 (앞바닥 띠가 사라졌으니 한 장뿐이어야 한다)
	_기록("앞바닥 제거", 배경들.size() == 1 and _이름에_앞바닥없나(),
		"실내배경 노드 %d 개 · 이름에 '앞바닥' 들어간 노드 %d 개 (둘 다 1/0 이어야 정상)"
			% [배경들.size(), _앞바닥_노드수()])
	if 배경들.is_empty():
		_기록("room.png Load", false, "실내배경 노드가 없다")
		return

	var b: Node2D = 배경들[0]
	var t: Texture2D = b.get("그림_아래")
	var 영역: Rect2 = b.get("영역")
	var 원본영역: Rect2 = b.get("그림_원본영역")

	# ② 원본 로드 + 크기
	_기록("room.png Load", t != null and t.get_size() == Vector2(2135, 1200),
		"%s %s" % ["null" if t == null else t.resource_path.get_file(),
			"—" if t == null else str(t.get_size())])

	# ③ Crop 없음 — 원본영역이 원본 전체와 같아야 한다
	var 통짜 := t != null and is_equal_approx(원본영역.position.x, 0.0) \
		and is_equal_approx(원본영역.position.y, 0.0) \
		and 원본영역.size == t.get_size()
	_기록("Full Background / Crop", 통짜,
		"그림_원본영역=%s (원본 전체 (0,0,2135,1200) 여야 정상)" % 원본영역)

	# ④ 비율 유지 — 가로 배율과 세로 배율이 같아야 한다(= 균등 확대, 왜곡 아님)
	var 배x := 영역.size.x / 2135.0
	var 배y := 영역.size.y / 1200.0
	_기록("Stretch(비율 왜곡)", absf(배x - 배y) < 0.001,
		"가로 ×%.4f · 세로 ×%.4f — 같으면 균등 확대(왜곡 없음)" % [배x, 배y])

	# ⑤ Repeat 없음 — Parallax2D 의 repeat_size 가 0 이어야 한 장만 그린다
	var 부모 := b.get_parent() as Parallax2D
	var 반복 := Vector2.ZERO if 부모 == null else 부모.repeat_size
	_기록("Repeat", 반복 == Vector2.ZERO, "Parallax2D.repeat_size=%s (0 이어야 한 장)" % 반복)

	# ⑥ 코드 그림 덮어쓰기 없음 — 섞임이 0 이면 `_이층방()` 이 안 그려진다
	var 섞임: float = b.call("섞임_계산", -1500.0)
	_기록("Code Overlay", is_equal_approx(섞임, 0.0),
		"섞임_계산(-1500)=%.3f · 전환_시작y=%.1f 전환_끝y=%.1f (0 이면 원화만 그린다)"
			% [섞임, b.get("전환_시작y"), b.get("전환_끝y")])

	# ⑦ 바닥이 WOOD 인가 + 원화 바닥선과 맞물리는가
	# ⚠ `shape_material.resource_path` 는 인스턴스에서 **빈 문자열**이다(씬에 임베드된다).
	#   재질을 알아내려면 **채움 텍스처 경로**를 봐야 한다 — wood_v2 / brick_v2 로 갈린다.
	var 바닥_재질 := _채움텍스처("SS_WOOD_FLOOR_01")
	var 벽_재질 := _채움텍스처("벽_왼아래_BRICK_01")
	_기록("WOOD Floor", 바닥_재질.contains("wood") and 벽_재질.contains("brick"),
		"바닥 채움=%s · 벽 채움=%s (바닥은 wood, 벽은 brick 이어야 정상)"
			% [바닥_재질.get_file(), 벽_재질.get_file()])

	# 원화 py 950 이 world 어디로 가는지 = 영역.y + 950 × 세로배율. 바닥 윗면(0)과 같아야 한다.
	var 원화바닥_월드 := 영역.position.y + 950.0 * 배y
	_기록("Background ↔ Floor 정렬", absf(원화바닥_월드 - 0.0) < 1.0,
		"원화 py950 → world y %.1f · WOOD 바닥 윗면 y 0.0 (오차 %.1fpx)"
			% [원화바닥_월드, absf(원화바닥_월드)])

	# ⑧ 카메라 리밋이 배경 영역과 정확히 같은가 → 배경 밖이 절대 안 보인다
	var 리밋: Rect2 = _루트.get("카메라_리밋")
	_기록("Camera Limit = 배경", 리밋 == 영역,
		"리밋 %s · 배경 %s" % [리밋, 영역])
	# 뷰포트가 리밋보다 작으면 카메라가 클램프돼 배경 밖이 나올 수 없다.
	var 보이는크기 := Vector2(1920.0, 1080.0) / float(_루트.get("카메라_줌"))
	_기록("Background 밖 노출", 보이는크기.x < 리밋.size.x and 보이는크기.y < 리밋.size.y,
		"화면 %s < 리밋 %s 이면 클램프돼 배경 밖이 안 보인다" % [보이는크기, 리밋.size])


func _앞바닥_노드수() -> int:
	var n := 0
	for c in _모두(_루트):
		if String(c.name).contains("앞바닥"):
			n += 1
	return n

func _이름에_앞바닥없나() -> bool:
	return _앞바닥_노드수() == 0

func _모두(n: Node) -> Array:
	var r := [n]
	for c in n.get_children():
		r.append_array(_모두(c))
	return r


## 지형 노드의 **채움 텍스처 경로**. 재질 종류(wood/brick)를 이걸로 판별한다.
func _채움텍스처(이름: String) -> String:
	var t := _루트.get_node_or_null("지형/" + 이름)
	if t == null:
		return ""
	var m = t.get("shape_material")
	if m == null or m.fill_textures.is_empty() or m.fill_textures[0] == null:
		return ""
	return String(m.fill_textures[0].resource_path)


# ── 13) 서랍 — 실제로 열리고 닫히는가 · 플레이어를 태우는가 ─────────────────
## 도형님 §14 Test 4·5. 콜리전이 그림과 **같이** 움직이는지가 핵심이다.
func _시험_서랍() -> void:
	var d := _루트.get_node_or_null("기믹/서랍_옷장") as AnimatableBody2D
	if d == null:
		_기록("Drawer Open", false, "서랍 노드를 못 찾음")
		return
	var 닫힘x: float = d.position.x
	var 주기: float = d.call("주기")

	# ① 한 주기를 돌려 열림/닫힘 양 끝에 실제로 도달하는지 본다.
	var 최소 := 1.0
	var 최대 := 0.0
	var 최소x := 1e9
	var 최대x := -1e9
	for i in int(주기 * 60.0) + 20:
		await physics_frame
		var v: float = d.call("열린정도")
		최소 = minf(최소, v)
		최대 = maxf(최대, v)
		최소x = minf(최소x, d.position.x)
		최대x = maxf(최대x, d.position.x)
	_기록("Drawer Open", 최대 > 0.99, "한 주기 중 최대 열린정도 %.2f · 오른끝 x %.0f" % [최대, 최대x])
	_기록("Drawer Close", 최소 < 0.01, "한 주기 중 최소 열린정도 %.2f · 왼끝 x %.0f" % [최소, 최소x])

	# ② 그림과 콜리전이 같은 노드 밑에 있으니 이동량이 같아야 한다.
	#    (SS2D 쪽 StaticBody2D 가 남아 있으면 밟는 면이 둘이 되어 여기서 걸린다)
	var 그림 := d.get_node_or_null("그림")
	var 그림_몸 := 그림.get_node_or_null("StaticBody2D") if 그림 else null
	var 이동량: float = 최대x - 최소x
	_기록("Drawer Collision Sync", 그림_몸 == null and absf(이동량 - 300.0) < 6.0,
		"SS2D StaticBody2D=%s(없어야 정상) · 이동량 %.1fpx (설계 300)"
			% ["없음" if 그림_몸 == null else "있음 ✗", 이동량])

	# ③ 서랍 위에 세워 두고 한 주기를 돌린다 — 실려 가야 하고, 안 빠지고, 안 박혀야 한다.
	#    서랍이 완전히 열린 순간을 기다렸다가 그 위에 놓는다.
	for i in 400:
		await physics_frame
		if float(d.call("열린정도")) > 0.99:
			break
	await _놓기(Vector2(d.global_position.x, d.global_position.y - 160.0))
	await _착지_대기(120)
	var 탑승_시작 := _p.global_position
	var 서랍_시작x := d.position.x
	# ★서랍이 **옷장 밖**(x > 2297)에 있는 동안만 잰다.
	#   플레이어가 옷장 위로 넘어가면 바닥이 옷장으로 바뀌어 더는 안 실리는 게 정상이다.
	#   그 구간까지 드리프트로 세면 "정상 동작" 을 실패로 잡는다.
	var 떨어짐 := false
	var 기준_오프셋 := _p.global_position.x - d.position.x
	var 최대순간이동 := 0.0
	_최대드리프트 = 0.0
	var 이전x := _p.global_position.x
	for i in int(주기 * 60.0) + 20:
		await physics_frame
		최대순간이동 = maxf(최대순간이동, absf(_p.global_position.x - 이전x))
		이전x = _p.global_position.x
		if _p.global_position.x > 2320.0:
			_최대드리프트 = maxf(_최대드리프트,
				absf((_p.global_position.x - d.position.x) - 기준_오프셋))
		if _p.global_position.y > 탑승_시작.y + 200.0:
			떨어짐 = true
			break
	# ⚠ 한 주기를 돌면 서랍은 제자리로 돌아온다 → **순이동량 비교는 의미가 없다**(처음에 그렇게
	#   쟀다가 서랍 0px · 플레이어 −150px 이 나왔다). 실려 가는지는 **상대 오프셋이
	#   유지되는가**로 봐야 한다.
	_기록("Player on Drawer",
		(not 떨어짐) and _최대드리프트 < 20.0 and 최대순간이동 < 60.0,
		"옷장 밖 구간 드리프트 최대 %.1fpx(실리면 ≈0) · 한 프레임 최대 이동 %.1fpx(순간이동 없음) · 떨어짐=%s"
			% [_최대드리프트, 최대순간이동, 떨어짐])


# ── 14) 가시 — 닿으면 죽는가 · 칠해도 안전해지지 않는가 ─────────────────────
## 도형님 §7·§14 Test 6·7. 가시는 **항상** hazard 다 — 색 규칙과 완전히 분리된다.
func _시험_가시() -> void:
	var s := _루트.get_node_or_null("위험물/가시_1_1") as Area2D
	if s == null:
		_기록("Spike Hazard", false, "가시 노드를 못 찾음")
		return

	# ① 가시 위에 서면 죽는다
	# ⚠ 플레이어 원점은 **발바닥**이고 몸은 위로 뻗는다. 처음에 가시보다 60 위에
	#   놓았더니 몸이 통째로 가시 위에 떠서 안 겹쳤다(죽음=false). 떨어뜨려 받침에
	#   착지시켜야 다리가 가시에 잠긴다.
	var 가시위_죽음 := await _가시위에서_죽나(s)
	# ② 가시에서 멀리 떨어진 같은 받침 위에서는 안 죽는다 (가시만 위험하다는 확인)
	await _놓기(Vector2(2850.0, -1700.0))
	await _착지_대기(120)
	var 받침위_죽음 := false
	for i in 10:
		await physics_frame
		if bool(_루트.call("_사망_판정")):
			받침위_죽음 = true
	_기록("Spike Hazard", 가시위_죽음 and (not 받침위_죽음),
		"가시 위 죽음=%s · 같은 받침의 빈 자리 죽음=%s · hazard그룹=%s"
			% [가시위_죽음, 받침위_죽음, s.is_in_group("hazard")])

	# ③ 받침을 칠해도 가시는 그대로 위험하다.
	#    (총알은 레이어 1|8 만 레이캐스트한다 → 레이어 0 인 가시는 통과하고 받침이 맞는다)
	var 코어 := _루트.get_tree().get_first_node_in_group("페인트코어")
	var 받침: Node = _루트.get_node_or_null("지형/SS_BRICK_SPIKE_BASE_01")
	var 결과 := "—"
	if 코어 != null and 받침 != null:
		코어.발사_소모()
		결과 = 코어.명중_처리(받침, ColorDefs.BLACK, s.global_position + Vector2(0, 40))
	var 칠한뒤_죽음 := await _가시위에서_죽나(s)
	_기록("Spike Paint Immunity", 칠한뒤_죽음,
		"받침 명중 \"%s\" 뒤에도 가시 위 죽음=%s (칠해도 안전해지면 안 된다)" % [결과, 칠한뒤_죽음])


# ── 15) 완주 — 스폰부터 1-2 진입 직전까지 실제 조작으로 끝까지 간다 ─────────
## ▣ 왜 "무작정 봇" 을 버렸나
##   예전 봇은 **오른쪽 누른 채 착지할 때마다 점프**했다. 이 구간에는
##     · 타이밍이 있는 서랍(닫혀 있으면 못 건넌다)
##     · 넘어야 하는 가시(무작정 점프하면 그 위에 착지한다)
##   가 생겨서, 봇이 x 3030 = **가시 한복판**에 떨어져 죽었다.
##   → 사람이 하는 것과 같은 **웨이포인트 조작**으로 바꿨다:
##     발판 끝에서 점프하고, 서랍이 닫혀 있으면 옷장 위에서 **기다린다**.
func _시험_완주() -> void:
	var d := _루트.get_node_or_null("기믹/서랍_옷장")
	var 시작: Vector2 = _루트.get("시작_위치")
	await _놓기(시작)
	await _착지_대기(120)

	# 점프를 눌러야 하는 x 들 (각 발판의 오른쪽 끝 조금 앞)
	# ★웨이포인트에는 **x 뿐 아니라 그 발판의 y** 도 붙인다.
	#   x 만 보면 위/아래로 겹친 다른 발판에서도 점프해 버린다 —
	#   실제로 5390(창턱용)이 주름2(−1020) 위에도 걸려 봇이 그 자리에서
	#   점프-착지를 20 초 넘게 반복했다(추적으로 확인).
	var 점프지점: Array[Vector2] = [
		Vector2(660.0, -2050.0),    # Gap1  벽계단A → B
		Vector2(1350.0, -1830.0),   # Gap2  벽계단B → 옷장
		Vector2(2560.0, -1522.0),   # Gap3  서랍 → 가시받침
		Vector2(2930.0, -1632.0),   # 가시 넘기 (가시 2990…3182)
		Vector2(3360.0, -1632.0),   # Gap4  받침 → 출구
		Vector2(3950.0, -1742.0),   # 1-2 Gap5  출구 → 기둥 코벨
		Vector2(4460.0, -1740.0),   # 1-2 Gap6  코벨 → 창 윗틀
		Vector2(5390.0, -537.0),    # 1-2 Gap7  창턱 → 탁자
	]
	var 다음 := 0
	var 최대x := _p.global_position.x
	var 죽음 := 0
	var 이전y := _p.global_position.y
	var 기다린프레임 := 0
	var 바닥도착 := false

	for i in 5400:                                  # 90 초 (1-2 하강까지)
		await physics_frame
		var x := _p.global_position.x
		최대x = maxf(최대x, x)
		if absf(_p.global_position.y - 이전y) > 900.0:
			죽음 += 1
		이전y = _p.global_position.y

		# ★옷장 오른쪽 끝(2297) 앞에서는 서랍이 **막 열릴 때**까지 기다린다.
		#   닫혀 있는데 걸어 나가면 1522 아래 바닥까지 떨어져 죽는다.
		var 기다려 := false
		if d != null and x > 2150.0 and x < 2290.0 and float(d.call("열린정도")) < 0.99:
			기다려 = true
			기다린프레임 += 1

		# ★탁자(5600…5891)에 올라선 뒤에는 **왼쪽**으로 걸어 내려간다.
		#   오른쪽으로 계속 가면 오른쪽 벽(5891)에 막혀 영영 바닥에 못 내려간다
		#   (실측: 최대 x 5865 에서 멈췄다).
		# ★★1-2 창가 하강은 **높이에 따라 방향이 바뀐다**(사람이 하는 것과 같다).
		#   ① 창 윗틀·주름1(y < −1100) : 오른쪽으로 걸어 다음 단에 내려선다
		#   ② 주름2·주름3(−1100…−700) : **왼쪽**으로 꺾어 창턱으로 내려간다
		#   ③ 창턱(−700…−450)          : 오른쪽으로 달려 탁자로 점프(웨이포인트 5390)
		#   ④ 탁자·바닥(> −450)        : 왼쪽으로 걸어 바닥에 내려서고 1-3 으로 간다
		#   ⚠ 처음엔 "무조건 오른쪽" 이었는데, 주름2 오른쪽 끝에서 탁자까지 701 을
		#     떨어져 즉사를 반복했다(치명 낙하 520). 사람은 거기서 왼쪽으로 꺾는다.
		# ★방향은 **마지막으로 밟은 높이**로 정한다. 공중에서 실시간 y 로 정하면
		#   점프 도중에 방향이 뒤집혀 제자리를 맴돈다(실측: 20 초 넘게 왕복했다).
		if _p.is_on_floor():
			_지상y = _p.global_position.y
		var y := _지상y
		var 왼쪽으로 := (y > -1100.0 and y < -700.0) or (y > -450.0 and x > 4200.0)
		if 기다려:
			Input.action_release("move_right")
			Input.action_release("move_left")
		elif 왼쪽으로:
			Input.action_release("move_right")
			Input.action_press("move_left")
		else:
			Input.action_release("move_left")
			Input.action_press("move_right")

		# ★웨이포인트 점프 — **자리로 판단한다**(순번으로 하면 리스폰 뒤에 어긋난다).
		#   처음엔 index 를 하나씩 올렸는데, 죽고 되살아나면 index 는 그대로라
		#   이미 지난 지점으로 취급돼 다음 틈에서 점프를 안 하고 계속 떨어졌다(사망 21 회).
		var 뛸때 := false
		for wp in 점프지점:
			if x > wp.x and x < wp.x + 70.0 and absf(_p.global_position.y - wp.y) < 90.0:
				뛸때 = true
				break
		if _p.is_on_floor() and 뛸때:
			Input.action_press("jump")
			다음 = maxi(다음, _지난_웨이포인트(점프지점, x))
		elif _p.is_on_floor():
			Input.action_release("jump")

		# ★바닥(y 0)에 닿으면 1-2 하강 완료. 거기서부터는 **왼쪽**으로 1-3 을 향한다.
		if _p.is_on_floor() and _p.global_position.y > -60.0:
			바닥도착 = true
			break
	_해제()
	_기록("Exit Reachable", 최대x > 3900.0 and 죽음 == 0,
		"1-1 출구 통과 최대 x = %.0f · 웨이포인트 %d/7 · 서랍 대기 %.1f초 · 사망 %d 회"
			% [최대x, 다음, 기다린프레임 / 60.0, 죽음])

	# ── 1-2 하강 완료 + 1-3 진입 ──
	_기록("1-2 Descent", 바닥도착 and 죽음 == 0,
		"바닥 도착=%s · 끝난 자리 (%.0f, %.0f) · 바닥=%s (사망 %d 회)"
			% [바닥도착, _p.global_position.x, _p.global_position.y, _p.is_on_floor(), 죽음])
	if 바닥도착:
		# ★1-3 완주 — 바닥을 따라 왼쪽으로 가면서 옷장 밑 · 가시 · 책장 밑을 통과한다.
		Input.action_press("move_left")
		var 최소x := _p.global_position.x
		var 죽음13 := 0
		var 이전y13 := _p.global_position.y
		for i in 2400:
			await physics_frame
			var px := _p.global_position.x
			최소x = minf(최소x, px)
			if absf(_p.global_position.y - 이전y13) > 900.0:
				죽음13 += 1
			이전y13 = _p.global_position.y
			# 1-3 의 가시(1882…1978) 앞에서만 점프한다 — 낮은 천장 밑이라 상승 124 뿐이다.
			if _p.is_on_floor() and px > 2020.0 and px < 2090.0:
				Input.action_press("jump")
			elif _p.is_on_floor():
				Input.action_release("jump")
			if px < 800.0:
				break
		_해제()
		_기록("1-3 Entry", 최소x < 2600.0,
			"1-2 바닥에서 왼쪽으로 x %.0f 까지 (1-3 진입 = x < 2600)" % 최소x)
		_기록("1-1→1-2→1-3 연속", 최소x < 800.0 and 죽음13 == 0,
			"스폰부터 1-3 끝(x %.0f)까지 한 번에 · 1-3 구간 사망 %d 회" % [최소x, 죽음13])
	else:
		_기록("1-3 Entry", false, "바닥에 못 내려와 1-3 진입을 못 쟀다")


## 가시 위에 떨어뜨리고 **죽음이 잡히는지** 본다.
## ⚠ `월드.gd` 는 살아 있다 — 제 `_physics_process` 에서 사망을 감지하면 **바로 리스폰**한다.
##   그래서 착지 뒤 4 프레임이나 기다렸다가 `_사망_판정()` 을 부르면 이미 안전지점으로
##   옮겨져 **false** 가 나온다(처음에 그렇게 잘못 쟀다).
##   → 착지 직후부터 여러 프레임을 훑어 **한 번이라도 true 면 죽은 것**으로 본다.
func _가시위에서_죽나(가시: Area2D) -> bool:
	await _놓기(Vector2(가시.global_position.x, -1900.0))
	await _착지_대기(120)
	for i in 10:
		if bool(_루트.call("_사망_판정")):
			return true
		await physics_frame
	return false


## x 를 이미 지난 웨이포인트가 몇 개인가 (진행도 표시용).
func _지난_웨이포인트(목록: Array[Vector2], x: float) -> int:
	var n := 0
	for wp in 목록:
		if x > wp.x:
			n += 1
	return n


# ── 16) 1-3 가구 밑 통과 — 낮은 천장 두 장을 실제로 지나가는가 ──────────────
## 도형님 §F·§N. 좌표로만 "지나갈 수 있다" 고 판단하지 않고 **실제로 걸어서** 통과한다.
func _시험_가구밑() -> void:
	var 옷장밑 := _루트.get_node_or_null("지형/천장_옷장밑_WOOD_01") as Node2D
	var 책장밑 := _루트.get_node_or_null("지형/천장_책장밑_WOOD_01") as Node2D
	if 옷장밑 == null or 책장밑 == null:
		_기록("Furniture Underpass", false, "낮은 천장 노드를 못 찾음")
		return

	# ① 낮은 천장 밑에서 점프하면 머리가 막히는가 (천장이 점프를 봉인한다)
	await _놓기(Vector2(1700.0, -100.0))          # 옷장 밑 (천장 아랫면 −260)
	await _착지_대기(120)
	var y0 := _p.global_position.y
	Input.action_press("jump")
	var 최고1 := y0
	for i in 60:
		await physics_frame
		최고1 = minf(최고1, _p.global_position.y)
	_해제()
	await _놓기(Vector2(1200.0, -100.0))          # 책장 밑 (천장 아랫면 −151)
	await _착지_대기(120)
	var y1 := _p.global_position.y
	Input.action_press("jump")
	var 최고2 := y1
	for i in 60:
		await physics_frame
		최고2 = minf(최고2, _p.global_position.y)
	_해제()
	var 오름1 := y0 - 최고1
	var 오름2 := y1 - 최고2
	# ★상승 한계 = 천장 높이 − 플레이어 키 95.63 (콜리전은 아래로 안 부푼다 — 실측 확인).
	#   옷장 밑 220 → 124 · 책장 밑 151 → 55. 안 막히면 167.
	_기록("Low Ceiling", 오름1 < 140.0 and 오름2 < 80.0,
		"옷장 밑 점프 %.1fpx(한계 124) · 책장 밑 %.1fpx(한계 55) · 안 막히면 167"
			% [오름1, 오름2])

	# ② 오른쪽 넓은 바닥 → 두 천장 밑을 지나 왼쪽 끝까지 실제로 걸어간다.
	#    ★가시(1930)는 점프로 넘어야 하므로 그 앞에서만 점프한다.
	await _놓기(Vector2(3000.0, -100.0))   # 도약대(3250) 왼쪽에서 걸어 들어간다
	await _착지_대기(120)
	var 끼임 := false
	var 최소x := _p.global_position.x
	var 이전x := _p.global_position.x
	var 정체 := 0
	Input.action_press("move_left")
	for i in 1200:
		await physics_frame
		var x := _p.global_position.x
		최소x = minf(최소x, x)
		# 가시(1882…1978) 앞에서 점프
		if _p.is_on_floor() and x > 2020.0 and x < 2090.0:
			Input.action_press("jump")
		elif _p.is_on_floor():
			Input.action_release("jump")
		# 같은 자리에 1 초 넘게 붙어 있으면 낮은 천장에 **끼인** 것이다
		if absf(x - 이전x) < 0.5:
			정체 += 1
			if 정체 > 60:
				끼임 = true
				break
		else:
			정체 = 0
		이전x = x
		if x < 800.0:
			break
	_해제()
	_기록("Furniture Underpass", 최소x < 800.0 and not 끼임,
		"오른쪽 바닥 2600 → 왼쪽 %.0f 까지 걸어서 통과 (옷장 밑 · 가시 · 책장 밑) · 끼임=%s"
			% [최소x, 끼임])

	# ③ 1-3 의 가시도 hazard 로 작동하는가
	var s := _루트.get_node_or_null("위험물/가시_1_3") as Area2D
	if s == null:
		_기록("Spike 1-3", false, "가시_1_3 을 못 찾음")
		return
	await _놓기(Vector2(s.global_position.x, -220.0))
	await _착지_대기(120)
	var 죽나 := false
	for i in 10:
		if bool(_루트.call("_사망_판정")):
			죽나 = true
			break
		await physics_frame
	_기록("Spike 1-3", 죽나 and s.is_in_group("hazard"),
		"가시 위 죽음=%s · hazard그룹=%s · 폭 %d 칸" % [죽나, s.is_in_group("hazard"), s.get("칸수")])

	# ④ 죽은 뒤 안전지점으로 되살아나 다시 움직일 수 있는가 (도형님 Run 3)
	await _프레임(60)
	var 부활자리 := _p.global_position
	Input.action_press("move_left")
	await _프레임(30)
	Input.action_release("move_left")
	var 움직임 := 부활자리.x - _p.global_position.x
	_기록("Respawn", 움직임 > 50.0,
		"리스폰 자리 (%.0f, %.0f) 에서 0.5 초간 %.0fpx 이동 (조작 복귀)"
			% [부활자리.x, 부활자리.y, 움직임])


# ── 15) 구간 1-4 — OneWay 매트리스 · 부서지는 마룻바닥 ──────────────────────
## ▣ 왜 이 시험이 STEP 1-4.2 의 전부인가
##   1-4 의 핵심은 새 아트가 아니라 **두 가지 물리 계약**이다.
##     ① 매트리스는 아래에서 위로 뚫리고 위에서는 받는다 (안 그러면 1-3 이 막힌다)
##     ② 마룻바닥은 3 발에 부서지고 **콜리전이 실제로 사라진다** (안 그러면 구멍이 아니다)
##   둘 다 "화면에 보이는 것"이 아니라 **조작으로만 확인되는 것**이라 여기서 잰다.
func _시험_1_4() -> void:
	var 매트: Node2D = _루트.get_node_or_null("지형/SS_WOOD_MATTRESS_01")
	var 파괴: Node2D = _루트.get_node_or_null("지형/SS_WOOD_BREAK_FLOOR_01")
	if 매트 == null or 파괴 == null:
		_기록("1-4 Nodes", false, "매트리스/파괴바닥 노드를 못 찾음")
		return
	var 매트_중심 := 3258.0            # (2691 + 3825) / 2
	var 도약대_x := 3250.0             # 빌더 상수와 같아야 한다
	var 매트_윗면 := -435.0
	var 파괴_중심 := 5741.5            # (5591.5 + 5891.5) / 2

	# ── ① OneWay 가 실제로 켜졌는가 (씬에 저장이 안 되는 값이라 런타임에서 확인한다) ──
	var 켜짐: bool = bool(매트.call("단방향_켜졌나"))
	_기록("Mattress OneWay Flag", 켜짐,
		"one_way_collision=%s · 여유=%.0f (씬에는 저장 안 되고 단방향지형.gd 가 런타임에 켠다)"
			% [켜짐, float(매트.get("단방향_여유"))])

	# ── ② 아래 → 위 : 통과해야 한다. 그리고 되떨어져 **윗면에 선다** ──
	# 한 번의 조작으로 OneWay 양쪽을 다 본다: 뚫고 올라갔다가 위에서 착지한다.
	# (바닥에서 점프로는 435 를 못 올라가므로 도약대처럼 velocity.y 를 직접 준다 —
	#  `player.gd` 는 velocity.y 를 덮어쓰지 않는다)
	# ⚠ 여기서 `_착지_대기()` 를 부르면 안 된다 — 매트리스 밑은 허공이라 바닥(0)까지
	#   떨어지고, 거기서 쏘아 올려 봐야 상승 177 로는 −435 에 못 닿는다(첫 시도의 오답).
	#   **매트리스 밑면(−275) 바로 아래에서** 쏘아 올려야 OneWay 통과를 잰다.
	await _놓기(Vector2(매트_중심, -300.0))       # 매트리스 밑면(−275) 바로 아래
	_p.velocity.y = -900.0                       # 상승 ≈ 177 → 발이 −477 까지 올라간다
	var 최고 := _p.global_position.y
	for i in 40:
		await physics_frame
		최고 = minf(최고, _p.global_position.y)
	var 뚫었나 := 최고 < 매트_윗면                # 윗면보다 위로 올라갔으면 통과한 것
	var 섰나 := await _착지_대기(180)
	var 착지y := _p.global_position.y
	_기록("Mattress Pass Up", 뚫었나 and 섰나 and absf(착지y - 매트_윗면) < 8.0,
		"매트리스 밑(−300)에서 위로 쏘아 올림 → 최고 %.0f (윗면 %.0f 통과=%s) → 착지 %.1f (윗면이어야 정상)"
			% [최고, 매트_윗면, 뚫었나, 착지y])

	# ── ③ 위 → 아래 : 위에서 떨어지면 **막혀야** 한다 ──
	await _놓기(Vector2(매트_중심, -900.0))
	var 받았나 := await _착지_대기(240)
	var 위착지 := _p.global_position.y
	_기록("Mattress Land From Above", 받았나 and absf(위착지 - 매트_윗면) < 8.0,
		"−900 에서 낙하 → 착지 %.1f (윗면 %.0f 이어야 정상 · 뚫고 지나가면 0 근처)"
			% [위착지, 매트_윗면])

	# ── ④ 1-3 회귀 — 매트리스 **밑**을 걸어서 지나갈 수 있는가 ──
	# 1-3 의 검증된 동선(1-2 바닥 → 왼쪽)이 정확히 여기를 지난다. 막히면 1-3 이 죽는다.
	await _놓기(Vector2(3900.0, -100.0))
	await _착지_대기(180)
	var 최소x := _p.global_position.x
	var 끼임 := false
	var 이전x := _p.global_position.x
	var 정체 := 0
	Input.action_press("move_left")
	for i in 600:
		await physics_frame
		var x := _p.global_position.x
		최소x = minf(최소x, x)
		if absf(x - 이전x) < 0.5:
			정체 += 1
			if 정체 > 60:
				끼임 = true
				break
		else:
			정체 = 0
		이전x = x
		# ⚠ [STEP 1-4.3] 3000 에서 멈춘다 — 도약대(2740…2960)를 밟으면 튀어 올라
		#   "매트리스 **밑**을 지나갔는가" 를 잴 수 없다. 도약대까지 포함한 1-3 전체 통과는
		#   `1-3 Entry` · `1-1→1-2→1-3 연속` 이 따로 잰다.
		if x < 3000.0:
			break
	_해제()
	_기록("Under Mattress (1-3)", 최소x < 3050.0 and not 끼임,
		"바닥 3900 → 왼쪽 %.0f 로 매트리스 밑을 통과(도약대 앞 3000 까지) · 끼임=%s (틈 275 > 몸 96)"
			% [최소x, 끼임])

	# ── ③-2 ★[STEP 1-4.3] 도약대 — 실제 상승량과 매트리스 착지를 잰다 ──
	# ▣ 왜 계산이 아니라 실측인가
	#   `도약대.gd` 주석의 "−1500 = 418px" 는 **다른 플레이어 세팅**(상승_배수 4.563)의
	#   값이다. 이 스테이지는 중력 2287.97 · 상승_배수 1.00 이라 숫자가 다르다.
	#   → 물리 위에서 직접 재고, 그 값으로 매트리스(−435)를 넘는지 본다.
	var 도약: Node2D = _루트.get_node_or_null("기믹/도약대_침대밑")
	if 도약 == null:
		_기록("Trampoline", false, "도약대_침대밑 을 못 찾음")
		return
	# ★**걸어서** 들어간다. 위에서 떨어뜨리면 발판(−30)에서 발사돼 실제와 다른 값이 나온다 —
	#   실제로는 몸통이 옆에서 판정에 먼저 닿아 **바닥(0)** 에서 발사된다(§상승량 주석).
	await _놓기(Vector2(3000.0, -100.0))   # 도약대(3250) 왼쪽에서 걸어 들어간다
	await _착지_대기(180)
	var 발사y := 0.0
	var 최고2 := 0.0
	var 튀었나 := false
	Input.action_press("move_right")
	for i in 180:
		await physics_frame
		if not 튀었나 and _p.velocity.y < -1000.0:
			튀었나 = true
			발사y = _p.global_position.y
			최고2 = 발사y
		if 튀었나:
			최고2 = minf(최고2, _p.global_position.y)
			if _p.velocity.y > 0.0 and _p.global_position.y > 최고2 + 4.0:
				break
	_해제()
	var 상승 := 발사y - 최고2
	# 창이 좁다: 매트리스 윗면 435 를 넘겨야 하고, 빗맞아 바닥까지 되떨어져도 치명 520 미만.
	_기록("Trampoline Rise", 튀었나 and 최고2 < -480.0 and (발사y - 최고2) < 515.0,
		"걸어 들어가 y %.0f 에서 발사 · 상승 **%.1fpx** → 최고 %.0f (매트리스 −435 를 넘고, 되떨어져도 치명 520 미만)"
			% [발사y, 상승, 최고2])

	# 튀어 오른 뒤 **매트리스 위에 선다** — 도약대 하나로 도달이 풀리는지의 최종 확인
	var 올랐나 := await _착지_대기(240)
	var 오른자리 := _p.global_position
	_기록("Trampoline → Mattress", 올랐나 and absf(오른자리.y - 매트_윗면) < 8.0,
		"도약대에서 튀어 매트리스 착지 (%.0f, %.1f) · 윗면 %.0f 이어야 정상 (바닥이면 0)"
			% [오른자리.x, 오른자리.y, 매트_윗면])

	# 매트리스 위를 실제로 걸어 다닐 수 있는가 (올라가 놓고 못 움직이면 의미가 없다)
	var 위x0 := _p.global_position.x
	Input.action_press("move_right")
	await _프레임(60)
	_해제()
	var 위이동 := _p.global_position.x - 위x0
	_기록("Walk On Mattress", 위이동 > 150.0 and absf(_p.global_position.y - 매트_윗면) < 8.0,
		"매트리스 위에서 1 초간 오른쪽으로 %.0fpx 이동 · y=%.1f (윗면 유지)"
			% [위이동, _p.global_position.y])

	# ── ④-2 ★1-4 의 실제 동선 : 1-3 종료 지점(x 794)에서 **오른쪽으로 되돌아간다** ──
	# 1-3 에서 왼쪽으로 기어 지나온 관문 셋(책장 밑 151 · 가시 · 옷장 밑 220)을
	# **반대 방향으로** 다시 통과해 오른쪽 벽 앞까지 간다. 이것이 1-4 의 본체다.
	await _놓기(Vector2(794.0, -100.0))
	await _착지_대기(180)
	var 최대x := _p.global_position.x
	var 죽음14 := 0
	var 이전y := _p.global_position.y
	var 이전x14 := _p.global_position.x
	var 정체14 := 0
	var 끼임14 := false
	Input.action_press("move_right")
	for i in 2400:
		await physics_frame
		var px := _p.global_position.x
		최대x = maxf(최대x, px)
		if absf(_p.global_position.y - 이전y) > 900.0:
			죽음14 += 1
		이전y = _p.global_position.y
		# 가시(1882…1978) **앞**에서 점프한다. 오른쪽으로 가므로 1882 왼쪽이 앞이다.
		if _p.is_on_floor() and px > 1780.0 and px < 1850.0:
			Input.action_press("jump")
		elif _p.is_on_floor():
			Input.action_release("jump")
		if absf(px - 이전x14) < 0.5 and _p.is_on_floor():
			정체14 += 1
			if 정체14 > 90:
				끼임14 = true
				break
		else:
			정체14 = 0
		이전x14 = px
		if px > 5400.0:
			break
	_해제()
	_기록("1-4 Return Route", 최대x > 5400.0 and not 끼임14 and 죽음14 == 0,
		"1-3 종료(794)에서 오른쪽으로 x %.0f 까지 · 책장밑 151 → 가시 → 옷장밑 220 역방향 통과 · 끼임=%s · 사망 %d 회"
			% [최대x, 끼임14, 죽음14])

	# ── ④-3 ★[STEP 1-4.3] 진행 신호 — 파괴 바닥 위에 빛이 실제로 켜졌는가 ──
	# 새 텍스처 없이 `발광체.gd`(구슬)가 코드로 굽는 광원이다. 노드만 놓고 빛이 안 켜지면
	# 신호가 아니라 흰 점 하나일 뿐이라, **Light2D 가 실제로 생겼는지**까지 본다.
	var 신호: Node2D = _루트.get_node_or_null("오브젝트/신호_파괴바닥")
	var 빛: Light2D = null
	if 신호:
		for c in 신호.get_children():
			if c is Light2D:
				빛 = c
				break
	var 신호_위 := 신호 != null and absf(신호.global_position.x - 파괴_중심) < 200.0
	_기록("Progress Signal", 신호_위 and 빛 != null and 빛.enabled,
		"파괴 바닥(%.0f) 위 반딧불 자리=%s · Light2D=%s (켜짐=%s) — 캄캄한 막다른 구석의 유일한 빛"
			% [파괴_중심, 신호.global_position if 신호 else "없음",
			   "있음" if 빛 else "없음", 빛.enabled if 빛 else false])

	# ── ⑤ 파괴 전 : 그냥 바닥이어야 한다 ──
	await _놓기(Vector2(파괴_중심, -100.0))   # ★1-2 탁자(−319, 밑면 −159) 아래에 놓아야 바닥에 닿는다
	var 밟히나 := await _착지_대기(240)
	var 밟은y := _p.global_position.y
	_기록("Break Floor Solid", 밟히나 and absf(밟은y) < 8.0,
		"파괴 전 x %.0f 에 착지 y=%.1f (0 이어야 정상 — 부수기 전엔 평범한 바닥)"
			% [파괴_중심, 밟은y])

	# ── ⑥ 총알이 **실제로 닿는 자리**인가 (§10 — 못 쏘는 바닥이면 관문이 아니다) ──
	# 총알과 똑같은 레이캐스트(레이어 1|8)로, 왼쪽 바닥에 선 플레이어의 총구에서
	# 파괴 바닥 윗면을 겨눴을 때 **처음 맞는 것이 파괴 바닥인지** 본다.
	await _놓기(Vector2(5400.0, -100.0))
	await _착지_대기(180)
	var 총구 := _p.global_position + Vector2(0.0, -48.0)   # 몸 중심 높이
	var 공간 := _p.get_world_2d().direct_space_state
	var 질의 := PhysicsRayQueryParameters2D.create(총구, Vector2(파괴_중심, 20.0), 1 | 8)
	질의.collide_with_areas = false
	질의.exclude = [_p.get_rid()]
	var 맞음 := 공간.intersect_ray(질의)
	var 맞은대상: Node = null
	if 맞음:
		var n := 맞음.get("collider") as Node
		while n != null and not n.has_method("명중"):
			n = n.get_parent()
		맞은대상 = n
	_기록("Break Floor Shootable", 맞은대상 == 파괴,
		"x 5400 에 선 총구 → (%.0f, −4) 레이캐스트 첫 명중 = %s (SS_WOOD_BREAK_FLOOR_01 이어야 정상)"
			% [파괴_중심, 맞은대상.name if 맞은대상 else "없음"])

	# ── ⑦ 1 발 / 2 발 / 3 발 ──
	var 코어 := _루트.get_tree().get_first_node_in_group("페인트코어")
	if 코어 == null:
		_기록("Break Floor 3 Hits", false, "페인트코어를 못 찾음")
		return
	코어.리셋()
	var 기록: Array[String] = []
	var 단계_정상 := true
	for 발 in 3:
		코어.발사_소모()
		var r: String = 코어.명중_처리(파괴, ColorDefs.BLACK, Vector2(파괴_중심, 0.0))
		await _프레임(4)                                  # _부수기() 가 call_deferred 다
		var 부서짐: bool = bool(파괴.call("부서졌나"))
		var 남음: int = int(파괴.call("남은_명중"))
		기록.append("%d발→\"%s\" 남은 %d 부서짐 %s" % [발 + 1, r, 남음, 부서짐])
		# 1·2 발째는 멀쩡해야 하고 3 발째에 부서져야 한다
		if (발 < 2 and 부서짐) or (발 == 2 and not 부서짐):
			단계_정상 = false
	_기록("Break Floor 3 Hits", 단계_정상, " · ".join(기록))

	# ── ⑧ 콜리전이 실제로 사라졌는가 ──
	var 폴리 := 파괴.call("get_collision_polygon_node") as CollisionPolygon2D
	var 바디 := 폴리.get_parent() as CollisionObject2D if 폴리 else null
	await _프레임(4)
	# ⚠ `_착지_대기()` 로 재면 안 된다 — 구멍으로 떨어지다 **낙사 판정(치명 낙하 520)**이
	#   먼저 걸려 리스폰되고, 그 리스폰 자리(바닥)를 "착지" 로 읽어 버린다(첫 시도의 오답).
	#   → 착지 여부가 아니라 **얼마나 깊이 내려갔는지**(최대 y)를 본다. 리스폰해도 최대값은 남는다.
	await _놓기(Vector2(파괴_중심, -100.0))   # ★1-2 탁자(−319, 밑면 −159) 아래에 놓아야 바닥에 닿는다
	var 최대y := _p.global_position.y
	for i in 60:
		await physics_frame
		최대y = maxf(최대y, _p.global_position.y)
	var 폴리_꺼짐: bool = 폴리.disabled if 폴리 else false
	var 레이어_0: bool = (바디.collision_layer == 0) if 바디 else false
	_기록("Break Floor Collision Gone", 최대y > 300.0 and 폴리_꺼짐 and 레이어_0,
		"파괴 후 같은 자리에서 최대 y=%.0f (바닥 아랫면 300 아래로 빠져야 정상 · 남아 있으면 0) · disabled=%s layer=%s"
			% [최대y, 폴리_꺼짐, 바디.collision_layer if 바디 else "-"])

	# ── ⑨ 걸어가서 구멍에 빠지는가 → 낙사 → 리스폰 ──
	# ★"떨어져서 죽는다" 까지가 지금의 STAGE 1 종료다 (STAGE 2 씬이 아직 없다).
	await _놓기(Vector2(5350.0, -100.0))
	await _착지_대기(180)
	var 시작x := _p.global_position.x
	var 최저y := _p.global_position.y
	var 죽었나 := false
	Input.action_press("move_right")
	for i in 420:
		await physics_frame
		최저y = maxf(최저y, _p.global_position.y)
		if _p.global_position.y > 400.0:
			죽었나 = true                                  # 바닥 아랫면(300) 밑으로 빠졌다
			break
	_해제()
	_기록("Break Floor Fall", 죽었나,
		"x %.0f 에서 오른쪽으로 걸어가 구멍(5591…5891)에 빠짐 · 최저 y=%.0f (300 아래면 관통)"
			% [시작x, 최저y])

	# ⑩ 빠진 뒤 되살아나 다시 움직일 수 있는가 (끼임 · 무한 낙하가 아니어야 한다)
	await _프레임(150)
	var 부활 := _p.global_position
	Input.action_press("move_left")
	await _프레임(30)
	Input.action_release("move_left")
	var 움직임 := 부활.x - _p.global_position.x
	_기록("Fall Respawn", 움직임 > 50.0 and 부활.y < 400.0,
		"리스폰 자리 (%.0f, %.0f) 에서 0.5 초간 %.0fpx 이동 (조작 복귀)"
			% [부활.x, 부활.y, 움직임])


# ── 16) ★[STEP 1-4.4] STAGE 1 최종 완주 — **스폰부터 구멍까지 한 번에** ────────
## ▣ 왜 따로 만드나
##   지금까지의 시험은 구간마다 `_놓기()` 로 플레이어를 옮겨 놓고 쟀다. 그건
##   "그 구간이 되는가" 지 **"처음부터 끝까지 한 흐름으로 되는가"** 가 아니다.
##   여기서는 스폰 뒤로 **한 번도 옮기지 않는다.** 입력만 준다.
##
## ▣ 경로 (5 막)
##   ① 1-1 지그재그 → ② 1-2 창가 하강 → ③ 1-3 바닥 왼쪽 끝(x<800)
##   → ④ 1-4 되돌아가기(가시 넘고 · 도약대 · 매트리스) → ⑤ 파괴 바닥 3 발 → 낙하
##
## ⚠ 앞선 `_시험_1_4()` 가 이미 바닥을 부숴 놨으므로 **되살려 놓고** 시작한다.
##   (`되살아남 = 0` 이라 게임 중에는 안 되살아난다 — 시험 하네스만 쓰는 리셋이다)
func _시험_STAGE1_완주() -> void:
	var 파괴: Node2D = _루트.get_node_or_null("지형/SS_WOOD_BREAK_FLOOR_01")
	var d := _루트.get_node_or_null("기믹/서랍_옷장")
	if 파괴 == null:
		_기록("STAGE1 Full Run", false, "파괴 바닥을 못 찾음")
		return
	if bool(파괴.call("부서졌나")):
		파괴.call("_되살리기")
		await _프레임(4)

	var 점프지점: Array[Vector2] = [
		Vector2(660.0, -2050.0), Vector2(1350.0, -1830.0), Vector2(2560.0, -1522.0),
		Vector2(2930.0, -1632.0), Vector2(3360.0, -1632.0), Vector2(3950.0, -1742.0),
		Vector2(4460.0, -1740.0), Vector2(5390.0, -537.0),
	]
	await _놓기(_루트.get("시작_위치"))
	await _착지_대기(120)

	var 막 := 1                       # 1=하강 2=왼쪽으로 3=오른쪽으로 4=쏘기 5=낙하
	var 죽음 := 0
	var 이전y := _p.global_position.y
	var 왼끝x := 9999.0
	var 오른끝x := 0.0
	var 끼임 := false
	var 이전x := _p.global_position.x
	var 정체 := 0
	var 막_프레임 := [0, 0, 0, 0, 0, 0]

	for i in 12000:                   # 200 초. 넉넉히 준다.
		await physics_frame
		var x := _p.global_position.x
		var y := _p.global_position.y
		막_프레임[막] += 1
		if absf(y - 이전y) > 900.0:
			죽음 += 1
		이전y = y
		if _p.is_on_floor():
			_지상y = y

		# 어느 막에서든 **같은 자리에 3 초** 붙어 있으면 끼인 것이다
		if absf(x - 이전x) < 0.5 and _p.is_on_floor():
			정체 += 1
			if 정체 > 180:
				끼임 = true
				break
		else:
			정체 = 0
		이전x = x

		match 막:
			1:  # ── 1-1 → 1-2 하강. `_시험_완주()` 와 같은 규칙을 쓴다 ──
				var 기다려 := (d != null and x > 2150.0 and x < 2290.0
					and float(d.call("열린정도")) < 0.99)
				var 왼쪽으로 := (_지상y > -1100.0 and _지상y < -700.0) \
					or (_지상y > -450.0 and x > 4200.0)
				if 기다려:
					_해제()
				elif 왼쪽으로:
					Input.action_release("move_right")
					Input.action_press("move_left")
				else:
					Input.action_release("move_left")
					Input.action_press("move_right")
				var 뛸때 := false
				for wp in 점프지점:
					if x > wp.x and x < wp.x + 70.0 and absf(y - wp.y) < 90.0:
						뛸때 = true
						break
				if _p.is_on_floor() and 뛸때:
					Input.action_press("jump")
				elif _p.is_on_floor():
					Input.action_release("jump")
				if _p.is_on_floor() and y > -60.0:
					막 = 2
					_해제()

			2:  # ── 1-3 : 바닥을 따라 **왼쪽 끝**까지 (가시 앞에서만 점프) ──
				Input.action_press("move_left")
				if _p.is_on_floor() and x > 2020.0 and x < 2090.0:
					Input.action_press("jump")
				elif _p.is_on_floor():
					Input.action_release("jump")
				왼끝x = minf(왼끝x, x)
				if x < 800.0:
					막 = 3
					_해제()

			3:  # ── 1-4 : **오른쪽으로 되돌아간다.** 가시 앞에서만 점프 ──
				Input.action_press("move_right")
				if _p.is_on_floor() and x > 1780.0 and x < 1850.0:
					Input.action_press("jump")
				elif _p.is_on_floor():
					Input.action_release("jump")
				오른끝x = maxf(오른끝x, x)
				if x > 5450.0 and _p.is_on_floor() and y > -60.0:
					막 = 4
					_해제()

			4:  # ── 파괴 바닥에 3 발. 총구에서 실제로 닿는 자리인지는 §Shootable 이 이미 쟀다 ──
				var 코어 := _루트.get_tree().get_first_node_in_group("페인트코어")
				코어.리셋()
				for 발 in 3:
					코어.발사_소모()
					코어.명중_처리(파괴, ColorDefs.BLACK, Vector2(5741.5, 0.0))
					await _프레임(6)
				막 = 5

			5:  # ── 구멍으로 걸어 들어간다 ──
				Input.action_press("move_right")
				if y > 400.0:
					break
	_해제()

	var 부서졌나: bool = bool(파괴.call("부서졌나"))
	var 빠졌나 := _p.global_position.y > 400.0 or 막 == 5
	_기록("STAGE1 Full Run", 왼끝x < 800.0 and 오른끝x > 5450.0 and 부서졌나
			and 빠졌나 and not 끼임 and 죽음 == 0,
		"스폰→1-2하강→1-3 왼끝 %.0f→1-4 오른끝 %.0f→3발 파괴 %s→구멍 낙하 %s · 끼임=%s · **사망 %d 회**"
			% [왼끝x, 오른끝x, 부서졌나, 빠졌나, 끼임, 죽음])
	print("    [막별 소요] 1-1·1-2 하강 %.1f초 · 1-3 왼쪽 %.1f초 · 1-4 오른쪽 %.1f초 · 낙하 %.1f초"
		% [막_프레임[1] / 60.0,막_프레임[2] / 60.0, 막_프레임[3] / 60.0, 막_프레임[5] / 60.0])

	# 마지막으로 되살아나 조작이 돌아오는가
	await _프레임(150)
	var 부활 := _p.global_position
	Input.action_press("move_left")
	await _프레임(30)
	Input.action_release("move_left")
	_기록("STAGE1 Full Run · Respawn", 부활.x - _p.global_position.x > 50.0 and 부활.y < 400.0,
		"리스폰 (%.0f, %.0f) 에서 조작 복귀" % [부활.x, 부활.y])
