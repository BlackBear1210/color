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
	["벽계단_단1", 460.0, -2050.0],
	["벽계단_단2", 845.0, -1940.0],
	["벽계단_단3", 1295.0, -1830.0],
	["옷장", 1930.0, -1522.0],
	["출구계단_단1", 2522.0, -1632.0],
	["출구계단_단2", 2972.0, -1742.0],
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
	await _시험_색칠()
	await _시험_색사망()
	await _시험_배경()

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
	# ★들보는 x 2997…3297 에 있다. 그 **바로 아래**에서 재야 한다 —
	#   2972 에서 쟀더니 167px 이 나왔는데(= 안 막힘), 들보 왼쪽 25px 밖이었다.
	await _놓기(Vector2(3100.0, -1790.0))
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
		["벽계단 단1→단2", 340.0, -2050.0, 620.0, -1940.0, 640.0],
		["벽계단 단2→단3", 680.0, -1940.0, 1070.0, -1830.0, 1090.0],
		["벽계단→옷장", 1150.0, -1830.0, 1520.0, -1522.0, 1580.0],
		["옷장→출구계단", 1700.0, -1522.0, 2297.0, -1632.0, 2320.0],
		["출구계단 단1→단2", 2350.0, -1632.0, 2747.0, -1742.0, 2770.0],
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
	# 출구 선반 오른쪽 끝 = 3197. 3150 을 넘으면 1-1 을 끝까지 간 것이다.
	_기록("1-2 Direction", 최대x > 3150.0,
		"봇이 도달한 최대 x = %.0f (출구계단 2297…3197) · 리스폰 %d 회" % [최대x, 죽음])


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
	_p.set("자유색", ColorDefs.WHITE)
	await _프레임(2)
	var 흰색일때: bool = _루트.call("_사망_판정")
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
