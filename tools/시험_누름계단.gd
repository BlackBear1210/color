extends SceneTree
## ============================================================================
## [2026-10-09 Claude] 15 집 밖(하수도 가는 길) 엔진 시험 — 누름계단(하수도 2-5 장치) · 상자 · 색 계단 · 치명 낙하
## 실행(헤드리스 가능 · 60fps 고정):
##   Godot_console --headless --fixed-fps 60 --path . -s res://tools/시험_누름계단.gd
##   창 모드면 화면도 남긴다: tools/_진단/누름계단/
## ============================================================================
const OUT := "res://tools/_진단/누름계단/"
const 씬경로 := "res://scenes/쳅터1/스테이지/쳅터1_15_집밖_하수도길.tscn"
const C := 32.0

var failures := 0
var _씬: Node = null
var _p: CharacterBody2D = null
var _죽음 := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.get_texture().get_image().save_png(OUT + label + ".png")


func n(이름: String) -> Node:
	return _씬.get_node("추가기믹/" + 이름)


func 놓기(위치: Vector2, 색: int) -> void:
	_p.global_position = 위치
	_p.velocity = Vector2.ZERO
	_p.set("player_color", 색)
	_p.set("자유색", 색)


func run() -> void:
	root.size = Vector2i(1920, 1080)
	_씬 = (load(씬경로) as PackedScene).instantiate()
	root.add_child(_씬)
	current_scene = _씬
	_p = _씬.get_node("Player") as CharacterBody2D
	_씬.connect("사망함", func(): _죽음 += 1)
	await wait(30)
	# 반딧불·거미는 이 시험의 대상이 아니다(빛·추적은 시험_거미방) — 치운다
	for m in get_nodes_in_group("광원몹"):
		m.queue_free()
	for m in get_nodes_in_group("그을음"):
		m.queue_free()
	await wait(2)

	var 발판 := n("누름계단01_발판")
	var 판1 := n("누름계단01_판1") as Node2D
	var 판2 := n("누름계단01_판2") as Node2D
	var 상자 := n("누름계단01_상자") as CharacterBody2D
	var 숨1 := 판1.position
	var 숨2 := 판2.position
	var 나1 := 숨1 + Vector2(-7 * C, 0)
	var 나2 := 숨2 + Vector2(-4 * C, 0)
	check(숨1.x >= 92 * C and 숨2.x >= 92 * C, "처음엔 돌 계단 둘이 담장(92칸~) 속에 숨어 있다")
	var 발판위 := Vector2(79 * C, 48 * C - 2)

	# ── 1) 몸으로 밟으면 나온다 · 둘째는 0.45초 늦게 · 내리면 들어간다 ──
	놓기(발판위, ColorDefs.BLACK)
	await wait(12)
	var 첫움직임 := 판1.position != 숨1
	var 둘째그대로 := 판2.position == 숨2
	check(첫움직임 and 둘째그대로, "밟자마자 첫 계단부터 움직이고 둘째는 아직(지연 0.45초)")
	await wait(90)
	check(판1.position.is_equal_approx(나1) and 판2.position.is_equal_approx(나2), "다 나옴 — 판1 %s · 판2 %s" % [판1.position / C, 판2.position / C])
	await shot("01_몸으로_밟음_계단나옴")
	놓기(Vector2(60 * C, 48 * C - 2), ColorDefs.BLACK)
	await wait(120)
	check(판1.position.is_equal_approx(숨1) and 판2.position.is_equal_approx(숨2), "내리면 계단이 다시 담장 속으로(누르는 동안만)")

	# ── 2) 진짜로 상자를 밀어 발판에 올린다(플레이어 걷기 → player.gd 밀기) ──
	상자.global_position = Vector2(72.5 * C, 48 * C)
	놓기(Vector2(69.5 * C, 48 * C - 2), ColorDefs.BLACK)
	await wait(10)
	_p.set("자동_걷기", 1.0)
	var 올림 := -1
	for f in 400:
		await physics_frame
		if absf(상자.global_position.x - 79 * C) < 20.0:
			올림 = f
			break
	_p.set("자동_걷기", 0.0)
	check(올림 >= 0, "상자를 밀어 발판 위로(%d 프레임 · 상자 x %.1f칸)" % [올림, 상자.global_position.x / C])
	놓기(Vector2(60 * C, 48 * C - 2), ColorDefs.BLACK)        # 몸은 비킨다 — 상자 무게만으로
	await wait(120)
	check(bool(발판.call("활성인가")) and 판1.position.is_equal_approx(나1) and 판2.position.is_equal_approx(나2), "상자 무게만으로 계단이 나온 채 유지")
	await shot("02_상자로_누름_계단유지")

	# ── 3) 계단을 올라 담장 위로(실제 물리) — 판2(41행) 왼쪽 끝에서 달려 뛰기(검사기 비행과 같은 출발) ──
	놓기(Vector2(86.5 * C, 45 * C - 2), ColorDefs.BLACK)
	await wait(10)
	check(_p.is_on_floor() and _죽음 == 0, "판1(45행) 위에 섬")
	놓기(Vector2(88.2 * C, 41 * C - 2), ColorDefs.BLACK)
	await wait(10)
	check(_p.is_on_floor(), "판2(41행) 위에 섬")
	Input.action_press("move_right")
	Input.action_press("jump")
	var 담장위 := false
	for f in 80:
		await physics_frame
		if f == 24:
			Input.action_release("jump")
		# 담장 윗면(37행 · x 92~99칸)에 발이 닿은 순간을 잡고 멈춘다
		if _p.is_on_floor() and absf(_p.global_position.y - 37 * C) < 3.0 and _p.global_position.x > 92 * C:
			담장위 = true
			break
	Input.action_release("jump")
	Input.action_release("move_right")
	await wait(10)
	check(담장위 and _죽음 == 0, "판2 → 검은 담장 위(37행 · 검정 몸) — 몸 %s" % [_p.global_position / C])
	await shot("03_담장위")

	# ── 4) 죽으면 상자가 제자리(36칸)로 — 퍼즐이 처음으로 ──
	_씬.call("_리스폰")
	await wait(90)
	check(상자.global_position.distance_to(Vector2(36.5 * C, 48 * C)) < 4.0, "부활 → 상자 제자리(36칸) · 지금 %s" % [상자.global_position / C])
	await wait(120)
	check(판1.position.is_equal_approx(숨1), "상자가 없으니 계단도 다시 숨음")

	# ── 5) 지붕에서 마당으로 뛰어내리면 죽는다(치명 낙하 720 — 색 계단을 건너뛰지 못하게) ──
	_죽음 = 0
	놓기(Vector2(41.5 * C, 16 * C - 2), ColorDefs.BLACK)
	await wait(5)
	_p.set("자동_걷기", 1.0)
	await wait(20)
	_p.set("자동_걷기", 0.0)
	await wait(120)
	check(_죽음 >= 1, "지붕 끝에서 마당으로 떨어지면 사망(%d)" % _죽음)

	# ── 6) 흰 계단은 흰 몸만 · 검은 담장은 검정만 ──
	await wait(60)
	_p.set_physics_process(false)
	놓기(Vector2(47 * C, 20 * C - 1), ColorDefs.BLACK)
	await wait(2)
	check(bool(_씬.call("_사망_판정")), "흰 계단(20행)에 검정 몸 → 죽음")
	_p.set("player_color", ColorDefs.WHITE)
	_p.set("자유색", ColorDefs.WHITE)
	await wait(2)
	check(not bool(_씬.call("_사망_판정")), "흰 계단에 흰 몸 → 안전")
	_p.set_physics_process(true)

	print("\n시험_누름계단: 실패 %d" % failures)
	# [2026-10-09] 스테이지를 띄운 채 quit 하면 가끔 엔진 종료가 죽는다(쳅터1 어느 스테이지든 · 시험과 무관한 종료 순서 문제)
	#   → 씬을 먼저 지우고 몇 프레임 뒤에 끝낸다(tools/검사_띄운채종료.gd 로 확인).
	_씬.queue_free()
	for i in 3:
		await process_frame
	quit(1 if failures > 0 else 0)
