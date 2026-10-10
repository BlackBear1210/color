extends SceneTree
## ============================================================================
## [2026-10-09 Claude] 19 거미방 엔진 시험 — 반딧불 몹 · 그을음 거미(거미줄) · 빛받이 · 창살문 · 새장 레버
##   지시서 STEP 6 조합: 거미줄 없음/있음 × 흰/검은 빛 · 이동 중/붙음 · 색 시간 끝 · 거미가 줄을 다시 침 ·
##   같은 자리 중복 없음 · 씬을 다시 열어도 줄·광원이 쌓이지 않음 · 진짜 총알로 맞히기 · 문이 몸 위로 안 닫힘
## 실행(헤드리스 가능 · 60fps 고정):
##   Godot_console --headless --fixed-fps 60 --path . -s res://tools/시험_거미방.gd
##   창 모드면 화면도 남긴다: tools/_진단/거미방/
## ============================================================================
const OUT := "res://tools/_진단/거미방/"
const 씬경로 := "res://scenes/쳅터1/스테이지/쳅터1_19_거미방.tscn"
const 총알 := preload("res://scripts/스마트월드/총알.gd")
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


## 조건이 참이 될 때까지 기다린다(최대 프레임) — 걸린 프레임 수, 못 이루면 −1
func 까지(조건: Callable, 최대: int) -> int:
	for f in 최대:
		if 조건.call():
			return f
		await physics_frame
	return -1


func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.get_texture().get_image().save_png(OUT + label + ".png")


func 열기() -> void:
	for c in root.get_children():
		if c.get_node_or_null("Player") != null:
			c.queue_free()
	await process_frame
	await process_frame
	_씬 = (load(씬경로) as PackedScene).instantiate()
	root.add_child(_씬)
	current_scene = _씬
	_p = _씬.get_node("Player") as CharacterBody2D
	_죽음 = 0
	_씬.connect("사망함", func(): _죽음 += 1)
	await wait(10)


func n(이름: String) -> Node:
	return _씬.get_node("추가기믹/" + 이름)


## 플레이어를 시작 자리(모든 빛·거미에서 먼 곳)에 세워 둔다
func 주차() -> void:
	_p.global_position = Vector2(8.5 * C, 65 * C - 2)
	_p.velocity = Vector2.ZERO
	# [2026-10-10] 검정으로 세운다 — 입구 바닥(구조)이 검정이 됐다(흰 몸이면 주차하자마자 죽어 물감이 전부 회수되고
	#   '자동 환급' 같은 탄약 셈이 어긋난다). 입구는 반딧불 빛 밖이라 검정 몸도 안전하다.
	_p.set("player_color", ColorDefs.BLACK)


## 카메라를 그 점으로(촬영용) — 플레이어를 옮기면 위험할 때 쓴다
func 카메라_보기(점: Vector2) -> void:
	var cam := get_first_node_in_group("주카메라") as Camera2D
	if cam:
		cam.global_position = 점
		cam.set_physics_process(false)
		cam.set_process(false)


func 카메라_풀기() -> void:
	var cam := get_first_node_in_group("주카메라") as Camera2D
	if cam:
		cam.set_physics_process(true)
		cam.set_process(true)


func 문_열림(g: Node) -> bool:
	return bool(g.call("열렸나"))


func 문_막음(g: Node) -> bool:
	var cs: CollisionShape2D = g.get("_판정")
	return cs != null and not cs.disabled


func run() -> void:
	root.size = Vector2i(1920, 1080)
	await 열기()
	주차()

	# ── 0) 구성 ──────────────────────────────────────────────────────────
	var 몹들 := []
	for i in 4:
		몹들.append(n("반딧불%02d" % (i + 1)))
	var 받이들 := []
	var 문들 := []
	for i in 4:
		받이들.append(n("빛받이%02d" % (i + 1)))
		문들.append(n("빛받이%02d_문" % (i + 1)))
	var 거미 := n("거미01")
	var 줄 := n("거미01_줄1")
	check(get_nodes_in_group("광원몹").size() == 4, "반딧불 몹 4")
	check(get_nodes_in_group("거미줄").size() == 1 and bool(줄.call("완성")), "거미줄 1 · 처음부터 쳐져 있음")
	var 다막음 := true
	for g in 문들:
		다막음 = 다막음 and 문_막음(g) and not 문_열림(g)
	check(다막음, "창살문 4 개 모두 닫힘(판정 켜짐)")
	var 코어 := get_first_node_in_group("페인트코어")
	check(코어 != null, "페인트 코어 있음(물감 계약)")

	# ── 1) A 도입: 반딧불1 이 돌다 세 번째 자리에서 흰 빛받이 → 창살 열림(유지형) ──
	var F1: Node = 몹들[0]
	var 본상태 := {}
	var 걸림 := await 까지(func():
		본상태[F1.call("상태_이름")] = true
		return bool(받이들[0].get("켜짐")), 60 * 40)
	check(걸림 >= 0, "A: 반딧불1 → 빛받이1 켜짐(%.1f초)" % (걸림 / 60.0))
	check(본상태.has("이동") and 본상태.has("붙음") and 본상태.has("빛냄") and 본상태.has("떠남"), "A: 상태가 이동·붙음·빛냄·떠남을 돈다 %s" % [본상태.keys()])
	check(int(F1.call("정지점_번호")) == 2, "A: 켜 준 것은 세 번째 정지점(빛받이 옆)")
	await wait(80)
	check(문_열림(문들[0]) and not 문_막음(문들[0]), "A: 창살1 올라감(판정 꺼짐)")
	카메라_보기(Vector2(36 * C, 58 * C))
	await shot("01_A_빛받이_창살열림")
	# 유지형 — 반딧불이 떠나도 켜진 채
	await 까지(func(): return F1.call("상태_이름") == "이동", 60 * 10)
	await wait(120)
	check(bool(받이들[0].get("켜짐")) and 문_열림(문들[0]), "A: 유지형 — 반딧불이 떠나도 열린 채")

	# ── 2) 색 규칙(흰 빛): 빛 안 검정 몸 = 위험 · 흰 몸 = 안전 · 빛 밖 = 안전 ──
	await 까지(func(): return F1.call("상태_이름") == "빛냄" and float(F1.get("_세기")) >= 0.999, 60 * 15)
	var 아래: Vector2 = F1.global_position + Vector2(0, 120)
	var 가짜 := _p
	가짜.set_physics_process(false)
	가짜.global_position = 아래
	가짜.set("player_color", ColorDefs.BLACK)
	check(bool(F1.call("위험한가", 가짜)), "흰 빛 안 · 검정 몸 → 위험")
	check(bool(_씬.call("_사망_판정")), "월드 _사망_판정 도 같은 답(그룹 색빛)")
	가짜.set("player_color", ColorDefs.WHITE)
	check(not bool(F1.call("위험한가", 가짜)), "흰 빛 안 · 흰 몸 → 안전")
	# 몸 세 점(발 −8 · 허리 −48 · 머리 −88) 모두 반경 밖이 되게 — 발이 +260 이면 머리(+172)는 아직 빛 안이다
	가짜.global_position = F1.global_position + Vector2(0, 300)
	가짜.set("player_color", ColorDefs.BLACK)
	check(not bool(F1.call("위험한가", 가짜)), "반경(200px) 밖 · 검정 몸 → 안전")
	가짜.set_physics_process(true)
	주차()
	# 이동 중에는 빛이 없다(기본) → 위험 없음
	await 까지(func(): return F1.call("상태_이름") == "이동", 60 * 10)
	await wait(30)
	check(int(F1.call("빛_도달", F1.global_position + Vector2(0, 40))) == -1, "이동 중 → 빛 없음(판정 −1)")

	# ── 3) B: 검은 빛받이 — 흰 빛으로는 안 켜지고, 검정 물감을 맞힌 빛으로 켜진다 ──
	var F2: Node = 몹들[1]
	await 까지(func(): return int(F2.call("정지점_번호")) == 2 and F2.call("상태_이름") == "빛냄" and float(F2.get("_세기")) >= 0.999, 60 * 40)
	await wait(10)
	check(not bool(받이들[1].get("켜짐")), "B: 흰 빛 → 검은 빛받이 안 켜짐(검은 빛 ≠ 흰 빛)")
	코어.set("남은_탄약", int(코어.get("최대_탄약")) - 3)
	var 탄0 := int(코어.get("남은_탄약"))
	var 줄0 := int(코어.call("회수_대기수"))
	# 진짜 총알(스마트월드 페인트총알)을 쏴서 Area 레이어 16 → 명중() 경로까지 본다
	var 탄 := 총알.new()
	탄.시작(F2.global_position + Vector2(-140, -10), Vector2.RIGHT, 1100.0, ColorDefs.BLACK, 코어)
	_씬.add_child(탄)
	걸림 = await 까지(func(): return int(F2.get("빛색")) == ColorDefs.BLACK, 60)
	check(걸림 >= 0, "B: 검정 총알 → 반딧불2 검은 빛(%d 프레임)" % 걸림)
	check(F2.call("상태_이름") == "색바뀜", "B: 붙은 채 색바뀜 상태")
	check(int(코어.call("회수_대기수")) == 줄0 + 1, "B: 코어 회수줄에 올라감(E 로 되돌릴 수 있다)")
	check(int(F2.call("빛_도달", 받이들[1].global_position)) == -1, "B: 색이 막 바뀐 0.3초는 판정 쉼")
	걸림 = await 까지(func(): return bool(받이들[1].get("켜짐")), 60)
	check(걸림 >= 0, "B: 검은 빛 → 검은 빛받이 켜짐")
	await wait(80)
	check(문_열림(문들[1]), "B: 창살2 열림")
	카메라_보기(Vector2(94 * C, 50 * C))
	await shot("02_B_검은빛_빛받이")
	# 같은 색을 또 맞혀도 시간은 늘지 않는다(낭비 · 물감 환급) — 타이머는 하나
	var 남0 := float(F2.call("남은_색시간"))
	check(F2.call("명중", ColorDefs.BLACK, F2.global_position) == "wasted", "B: 같은 색 다시 → wasted")
	await wait(1)
	check(float(F2.call("남은_색시간")) <= 남0, "B: 다시 맞혀도 남은 시간이 늘지 않음")
	# 검은 빛 안 흰 몸 = 위험(반대 규칙)
	_p.set_physics_process(false)
	_p.global_position = F2.global_position + Vector2(-40, 120)
	_p.set("player_color", ColorDefs.WHITE)
	check(bool(F2.call("위험한가", _p)), "검은 빛 안 · 흰 몸 → 위험")
	_p.set("player_color", ColorDefs.BLACK)
	check(not bool(F2.call("위험한가", _p)), "검은 빛 안 · 검정 몸 → 안전")
	_p.set_physics_process(true)
	주차()
	# 시간 끝 → 흰색 · 물감 자동 환급 · 다시 날아감
	걸림 = await 까지(func(): return int(F2.get("빛색")) == ColorDefs.WHITE, 60 * 7)
	check(걸림 >= 0, "B: 색 시간(5초) 끝 → 흰 빛으로 돌아옴")
	check(int(코어.get("남은_탄약")) == 탄0 + 1 - 0 and int(코어.call("회수_대기수")) == 줄0,
		"B: 물감 자동 환급(탄 %d→%d · 회수줄 %d)" % [탄0, int(코어.get("남은_탄약")), int(코어.call("회수_대기수"))])
	걸림 = await 까지(func(): return F2.call("상태_이름") == "이동", 60 * 3)
	check(걸림 >= 0, "B: 흰 빛 0.8초 뒤 다시 이동(%.2f초)" % (걸림 / 60.0))
	check(bool(받이들[1].get("켜짐")), "B: 유지형 — 검은 빛이 끝나도 열린 채")
	# E 수동 회수 · 흰 물감으로 걷어 내기
	await 까지(func(): return F2.call("상태_이름") == "빛냄", 60 * 15)
	check(코어.call("명중_처리", F2, ColorDefs.BLACK, F2.global_position) == "painted", "물감 → painted")
	check(bool(코어.call("수동_회수")) and int(F2.get("빛색")) == ColorDefs.WHITE, "E 수동 회수 → 바로 흰색")
	코어.call("명중_처리", F2, ColorDefs.BLACK, F2.global_position)
	check(F2.call("명중", ColorDefs.WHITE, F2.global_position) == "wasted" and int(F2.get("빛색")) == ColorDefs.WHITE, "흰 물감 → 칠한 색을 바로 걷음")
	check(int(코어.call("회수_대기수")) == 줄0, "걷어 낸 발은 회수줄에서도 빠짐(중복 환급 없음)")
	# 이동 중에 맞으면 몸 색만 바뀌고 계속 난다
	await 까지(func(): return F2.call("상태_이름") == "이동", 60 * 10)
	F2.call("명중", ColorDefs.BLACK, F2.global_position)
	await wait(20)
	check(F2.call("상태_이름") == "이동" and int(F2.get("빛색")) == ColorDefs.BLACK, "이동 중 명중 → 계속 날며 색만 바뀜")
	F2.call("되돌리기")

	# ── 4) C: 거미줄이 흰 빛을 가린다 → 거미가 타면 줄이 삭고 빛이 닿는다 ──
	var F3: Node = 몹들[2]
	await 까지(func(): return int(F3.call("정지점_번호")) == 2 and F3.call("상태_이름") == "빛냄" and float(F3.get("_세기")) >= 0.999, 60 * 50)
	await wait(5)
	var R3: Node = 받이들[2]
	var 거리 := (F3.global_position as Vector2).distance_to(R3.global_position)
	check(거리 < 200.0, "C: 세 번째 자리 ↔ 빛받이3 거리 %.0f < 반경 200" % 거리)
	check(int(F3.call("빛_도달", R3.global_position)) == -1 and not bool(R3.get("켜짐")), "C: 거미줄이 가림 → 빛받이3 안 켜짐(흰 빛 · 줄 있음)")
	카메라_보기(Vector2(150 * C, 48 * C))
	await shot("03_C_거미줄이_빛을_가림")
	# 검게 칠해도 줄은 가린다(색 조건과 무관하게 막힘)
	코어.call("명중_처리", F3, ColorDefs.BLACK, F3.global_position)
	await wait(25)
	check(int(F3.call("빛_도달", R3.global_position)) == -1, "C: 검은 빛도 줄에 막힘(줄 있음 + 검은 빛)")
	# 거미를 검은 빛 자리로 꾀어 둔다 — 검은 빛은 거미를 태우지 않는다
	거미.set_physics_process(false)
	거미.global_position = Vector2(146 * C, 55 * C)
	await wait(2)
	check(not bool(거미.call("_빛에_닿나", 거미.global_position)), "C: 검은 빛 → 거미 안 탐")
	거미.set_physics_process(true)
	# 색 시간이 끝나 흰 빛이 돌아오는 순간 → 거미가 탄다 → 줄이 삭는다 → 빛받이3 → 창살3
	걸림 = await 까지(func(): return 거미.call("상태_이름") == "탐", 60 * 7)
	check(걸림 >= 0, "C: 검은 빛 → 흰 빛 돌아오는 순간 거미가 탐(%.1f초)" % (걸림 / 60.0))
	check(not bool(줄.call("완성")), "C: 거미가 타자 줄이 삭음")
	걸림 = await 까지(func(): return bool(R3.get("켜짐")), 60)
	check(걸림 >= 0, "C: 줄이 사라진 흰 빛 → 빛받이3 켜짐")
	await wait(20)
	await shot("04_C_거미탐_줄삭음")
	await wait(70)
	check(문_열림(문들[2]), "C: 창살3 열림")
	# 거미가 다시 태어나 같은 자리에 줄을 다시 친다 — 줄 노드는 그대로 1 개
	걸림 = await 까지(func(): return 거미.call("상태_이름") == "잠복", 60 * 12)
	check(걸림 >= 0, "C: 6초 뒤 둥지에서 다시 태어남")
	var 본 := {}
	걸림 = await 까지(func():
		본[거미.call("상태_이름")] = true
		return bool(줄.call("완성")), 60 * 15)
	check(걸림 >= 0 and 본.has("엮으러감") and 본.has("엮음"), "C: 거미가 줄 자리로 가서 다시 침 %s" % [본.keys()])
	check(get_nodes_in_group("거미줄").size() == 1, "C: 같은 자리 중복 없음(거미줄 노드 1)")
	await shot("05_C_거미가_줄을_다시침")
	await wait(10)
	check(bool(R3.get("켜짐")) and 문_열림(문들[2]), "C: 유지형 — 줄이 다시 쳐져도 창살3 열린 채")
	# 엮는 중에 타면 덜 친 줄은 흩어진다
	줄.call("삭기")
	await 까지(func(): return 거미.call("상태_이름") == "엮음", 60 * 10)
	await wait(20)
	var 반 := float(줄.get("진행"))
	거미.call("_상태", 6)       # 상태.탐(enum 7번째)
	await wait(2)
	check(반 > 0.0 and 반 < 1.0 and float(줄.get("진행")) == 0.0, "C: 엮다가 타면 덜 친 줄(%.2f)은 흩어짐" % 반)

	# ── 5) D: 새장 레버 — 끄면 2초 머물고 떠나 창살4 가 닫히고, 켜 두면 붙잡혀 열린 채 ──
	var F4: Node = 몹들[3]
	var 레버 := n("반딧불04_새장레버")
	var R4: Node = 받이들[3]
	await 까지(func(): return int(F4.call("정지점_번호")) == 2 and F4.call("상태_이름") == "빛냄", 60 * 40)
	걸림 = await 까지(func(): return bool(R4.get("켜짐")), 60 * 2)
	check(걸림 >= 0, "D: 새장 정지점에서 빛받이4(켜진 동안만) 켜짐")
	await 까지(func(): return F4.call("상태_이름") == "이동", 60 * 5)
	걸림 = await 까지(func(): return not bool(R4.get("켜짐")), 60 * 2)
	check(걸림 >= 0, "D: 레버 꺼짐 → 반딧불 떠남 → 빛받이4 꺼짐(놓침 여유 뒤)")
	await wait(90)
	check(not 문_열림(문들[3]) and 문_막음(문들[3]), "D: 창살4 다시 닫힘")
	레버.set("켜짐", true)
	await 까지(func(): return int(F4.call("정지점_번호")) == 2 and F4.call("상태_이름") == "빛냄", 60 * 40)
	await wait(60 * 6)
	check(int(F4.call("정지점_번호")) == 2 and F4.call("상태_이름") == "빛냄", "D: 새장 닫힘 → 머묾(2초)을 넘겨 6초째 그 자리")
	check(bool(R4.get("켜짐")) and 문_열림(문들[3]), "D: 붙잡힌 빛 → 창살4 열린 채")
	카메라_보기(Vector2(182 * C, 55 * C))
	await shot("06_D_새장레버_창살열림")
	# 문간에 몸이 있으면 닫히지 않는다
	_p.set_physics_process(false)
	_p.global_position = (문들[3] as Node2D).global_position + Vector2(0, -2)
	레버.set("켜짐", false)
	await wait(60 * 4)
	check(not 문_막음(문들[3]), "D: 문간에 몸 → 창살이 몸 위로 닫히지 않음")
	주차()
	_p.set_physics_process(true)
	걸림 = await 까지(func(): return 문_막음(문들[3]), 60 * 3)
	check(걸림 >= 0, "D: 몸이 비키자 닫힘")
	카메라_풀기()

	# ── 6) 부활 — 칠해 둔 색은 걷히고(환급) 켜진 동안만 장치는 처음으로 ──
	코어.call("명중_처리", F4, ColorDefs.BLACK, F4.global_position)
	get_root_world_respawn()
	await wait(90)
	check(int(F4.get("빛색")) == ColorDefs.WHITE, "부활 → 반딧불 색 걷힘")

	# ── 7) 씬을 두 번 다시 열어도 줄·광원·빛받이가 쌓이지 않는다 ──
	for k in 2:
		await 열기()
		주차()
	await wait(5)
	check(get_nodes_in_group("거미줄").size() == 1 and get_nodes_in_group("광원몹").size() == 4 and get_nodes_in_group("빛받이").size() == 4,
		"다시 열기 ×2 → 거미줄 %d · 광원 %d · 빛받이 %d" % [get_nodes_in_group("거미줄").size(), get_nodes_in_group("광원몹").size(), get_nodes_in_group("빛받이").size()])

	# ── 8) 전체 화면 몇 장(창 모드) ──
	카메라_풀기()
	await shot("07_시작")
	print("\n시험_거미방: 실패 %d" % failures)
	quit(1 if failures > 0 else 0)


func get_root_world_respawn() -> void:
	if _씬.has_method("_리스폰"):
		_씬.call("_리스폰")
