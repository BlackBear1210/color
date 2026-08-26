extends SceneTree
## ============================================================================
## [2026-08-26 신규] 집 챕터 — **씬 연결 + 실제 걸어서 통과** 검사
## ----------------------------------------------------------------------------
## 실행:  godot --headless --path . -s res://tools/test_집_체인.gd
##
## ▣ 왜 만들었나
##   `레벨검사.gd` 는 레이캐스트로 **도달 가능성 그래프**를 그린다 — 이론상 갈 수 있는가.
##   `test_집_칠하기와빛.gd` 는 **색 규칙**만 본다.
##   둘 다 "진짜로 걸어가 봤을 때 계단에 걸리거나 천장에 끼지 않는가" 는 안 본다.
##   도형님 지시 §17 이 요구한 것이 정확히 그것이다.
##   → 여기서는 **플레이어를 실제로 조작해** 스테이지를 관통시킨다.
##
## ▣ 두 가지를 본다
##   A. 체인 — 방 → 복도계단 → 거실 → 부엌 → 굴뚝 이 `연결통로.다음_씬` 으로 이어졌나,
##      받는 쪽에 `입구통로` 가 있나, 시작 위치 아래에 밟을 바닥이 있나.
##   B. 관통 — 복도·계단 스테이지를 시작점에서 **오른쪽으로 계속 걸어** 1층 홀 바닥까지
##      내려갈 수 있나. 좁은 통로에서 안 끼고, 계단에서 안 튕기고, 안 죽어야 한다.
##      ⚠ 유령 발판 게이트 앞에서 멈추는 것은 **정상**이다(칠해야 열린다).
##         그래서 목표는 "출구" 가 아니라 "1층 홀 바닥에 서기" 다.
##
## ▣ 입력을 흉내 낼 때의 함정 (측정_플레이어_능력.gd 에서 겪은 것과 같다)
##   `Input.action_press()` 는 약 2 프레임 뒤에야 `is_action_just_pressed` 로 보인다.
##   상승 중에 떼면 `JUMP_CUT_MULTIPLIER(0.4)` 가 점프를 잘라 167px → 40px 이 된다.
##   → **공중에 뜬 뒤 정점을 지난 뒤에만** 뗀다.
## ============================================================================

const 방 := "res://scenes/집/집_2층방.tscn"
const 복도 := "res://scenes/집/집_복도계단.tscn"
const 거실 := "res://scenes/집/집_거실.tscn"
const 부엌 := "res://scenes/집/집_부엌.tscn"
const 굴뚝 := "res://scenes/집/집_굴뚝.tscn"

## [씬, 다음 씬] — 마지막 굴뚝은 지붕(스마트월드_7)으로 나가므로 여기서 끊는다.
const 체인 := [
	[방, 복도], [복도, 거실], [거실, 부엌], [부엌, 굴뚝],
]

## 관통 검사 목표: 1층 홀 바닥(y≈770)에 x 1780 을 넘어 서 있으면 성공.
const 목표_x := 1820.0
const 목표_y := 800.0
const 관통_최대프레임 := 1800      ## 30 초. 실제로는 12 초쯤이면 닿는다.

var _통과 := 0
var _실패 := 0


func _initialize() -> void:
	Engine.max_fps = 0
	_실행()


func _확인(조건: bool, 설명: String) -> void:
	if 조건:
		_통과 += 1
		print("  ✔ %s" % 설명)
	else:
		_실패 += 1
		print("  ✖ %s" % 설명)


func _실행() -> void:
	print("\n════ 집 챕터 체인 + 관통 검사 ════")
	await process_frame
	await _A_체인()
	await _B_관통()
	print("\n────────────────────────────────")
	print("  통과 %d · 실패 %d" % [_통과, _실패])
	print("────────────────────────────────\n")
	quit(1 if _실패 > 0 else 0)


# ============================================================================
# A. 체인 — 씬끼리 제대로 이어졌나
# ============================================================================
func _A_체인() -> void:
	print("\n── A. 씬 연결 ─────────────────────")
	for 줄 in 체인:
		var 이번: String = 줄[0]
		var 다음: String = 줄[1]
		var 씬: Node2D = (load(이번) as PackedScene).instantiate()
		root.add_child(씬)
		await physics_frame
		await physics_frame

		var 오브 := 씬.get_node_or_null("오브젝트")
		var 출구: Node = 오브.get_node_or_null("출구통로") if 오브 else null
		_확인(출구 != null and String(출구.get("다음_씬")) == 다음,
			"%s 의 출구가 %s 로 간다" % [이번.get_file(), 다음.get_file()])
		if 출구 != null:
			_확인(String(출구.get("다음_진입점")) == "입구통로",
				"  진입점 이름이 '입구통로' 다")

		# 시작 위치 아래에 밟을 바닥이 있나 (스폰하자마자 낙사하면 안 된다)
		var 시작: Vector2 = 씬.get("시작_위치")
		var 공간 := 씬.get_world_2d().direct_space_state
		var q := PhysicsRayQueryParameters2D.create(
			시작 + Vector2(0, -40), 시작 + Vector2(0, 900))
		var 맞음 := 공간.intersect_ray(q)
		_확인(not 맞음.is_empty(),
			"  시작 위치 %s 아래에 바닥이 있다" % 시작)

		씬.queue_free()
		await process_frame

	# 받는 쪽에 입구통로가 있나
	for 경로 in [복도, 거실, 부엌, 굴뚝]:
		var 씬2: Node2D = (load(경로) as PackedScene).instantiate()
		root.add_child(씬2)
		await physics_frame
		var 오브2 := 씬2.get_node_or_null("오브젝트")
		_확인(오브2 != null and 오브2.get_node_or_null("입구통로") != null,
			"%s 에 입구통로가 있다" % 경로.get_file())
		씬2.queue_free()
		await process_frame


# ============================================================================
# B. 관통 — 복도·계단을 실제로 걸어 내려간다
# ============================================================================
func _B_관통() -> void:
	print("\n── B. 복도 → 좁은 통로 → 계단 → 1층 홀 관통 ─────")
	var 씬: Node2D = (load(복도) as PackedScene).instantiate()
	root.add_child(씬)
	await physics_frame
	await physics_frame

	var p := 씬.get_node_or_null("Player") as CharacterBody2D
	if p == null:
		_확인(false, "Player 노드를 찾았다")
		return

	var 시작 := p.global_position
	var 최저 := 시작.y            # 가장 아래로 내려간 지점
	var 최우 := 시작.x            # 가장 오른쪽
	var 갇힘_프레임 := 0
	var 이전_x := 시작.x
	var 죽음 := false
	var 도착 := false
	var 누름 := false

	Input.action_press("move_right")
	for i in 관통_최대프레임:
		await physics_frame
		# 점프 — 공중에 뜬 뒤 정점을 지난 뒤에만 뗀다(JUMP_CUT 회피)
		if not 누름 and p.is_on_floor() and p.is_on_wall():
			Input.action_press("jump")
			누름 = true
		elif 누름 and not p.is_on_floor() and p.velocity.y >= 0.0:
			Input.action_release("jump")
			누름 = false

		var q := p.global_position
		최저 = maxf(최저, q.y)
		최우 = maxf(최우, q.x)

		# 리스폰(사망)이 일어나면 시작점 근처로 순간이동한다 — 그걸로 감지한다
		if q.distance_to(시작) < 40.0 and i > 90:
			죽음 = true
			break
		if q.x >= 목표_x and q.y >= 목표_y - 120.0:
			도착 = true
			break

		# 같은 자리에서 2 초 넘게 못 움직이면 끼인 것으로 본다
		if absf(q.x - 이전_x) < 1.0:
			갇힘_프레임 += 1
		else:
			갇힘_프레임 = 0
			이전_x = q.x
		if 갇힘_프레임 > 120:
			break
	_입력_해제()

	var 끝 := p.global_position
	_확인(not 죽음, "관통 도중에 죽지 않았다")
	_확인(갇힘_프레임 <= 120,
		"어디에도 끼이지 않았다 (마지막 위치 %.0f, %.0f)" % [끝.x, 끝.y])
	_확인(최우 > -200.0, "좁은 통로 입구(x −200)를 지났다 — 최대 x %.0f" % 최우)
	_확인(최우 > 520.0, "좁은 통로를 빠져나왔다 (x 520)")
	_확인(최저 > 700.0, "계단을 끝까지 내려갔다 — 최저 y %.0f (1층 바닥 770)" % 최저)
	_확인(도착, "1층 홀 바닥에 도착했다 (x≥%.0f)" % 목표_x)

	씬.queue_free()
	await process_frame


func _입력_해제() -> void:
	for a in ["move_left", "move_right", "jump"]:
		if Input.is_action_pressed(a):
			Input.action_release(a)
