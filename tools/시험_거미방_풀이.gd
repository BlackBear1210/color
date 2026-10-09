extends SceneTree
## ============================================================================
## [2026-10-10 Claude] 거미방(19) — 사람이 하는 대로 풀어 보기
##   도형님 10-10: "반딧불이를 쏘지도 못하고 거미한테 죽는 일이 많다 · 거미를 어떻게 쓰라는 건지 애매하다"
##   ① 조준선이 반딧불에서 멈추나(예전엔 몸을 뚫고 뒤 벽에 빨간 X) · 같은 색이면 X · 다른 색이면 표적 점
##   ② C 풀이: 줄 너머로 다가가 거미를 깨운다 → 왼쪽(140)으로 걸어 물러나 기다린다 →
##      거미는 영역 끝(147 근처)에서 멈춰 노려보고 → 반딧불3 이 147 에 내려앉아 빛을 켜면 탄다 → 줄 삭음 → 빛받이3 → 창살3
##      그동안 플레이어는 한 번도 죽지 않아야 한다.
##   ③ 세 번째 체크포인트(171 · 창살 너머)에 검정·흰 몸으로 서 있어도 반딧불·거미에 안 죽는다.
## 실행: Godot_console --headless --fixed-fps 60 --path . -s res://tools/시험_거미방_풀이.gd
## ⚠ 진행 파일을 쓰지 않는다(기록_허용 = 0).
## ============================================================================
const C := 32.0

var failures := 0
var _씬: Node
var _p: CharacterBody2D
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


func 찾기(이름: String) -> Node:
	return _씬.get_node_or_null("추가기믹/" + 이름)


func run() -> void:
	게임진행.기록_허용 = 0
	root.size = Vector2i(1920, 1080)
	_씬 = (load("res://scenes/쳅터1/스테이지/쳅터1_19_거미방.tscn") as PackedScene).instantiate()
	root.add_child(_씬)
	current_scene = _씬
	_p = _씬.get_node("Player") as CharacterBody2D
	_씬.connect("사망함", func():
		_죽음 += 1
		print("    (사망 @ 칸 %.1f, %.1f)" % [_p.global_position.x / C, _p.global_position.y / C]))
	await wait(20)

	# ── ① 조준선 ──
	var 총: Node = null
	for n in _씬.find_children("*", "", true, false):
		var sc: Script = n.get_script()
		if sc and sc.resource_path.ends_with("스마트월드/총.gd"):
			총 = n
	check(총 != null and 총.has_method("_궤적_따라"), "총(스마트월드) 있음 · 궤적 함수")
	var F2 := 찾기("반딧불02") as Node2D
	if 총 and F2:
		await wait(30)
		var 표적: Vector2 = F2.global_position
		for 색 in [ColorDefs.WHITE, ColorDefs.BLACK]:
			_p.set("player_color", 색)
			await wait(2)
			var 점들: PackedVector2Array = 총.call("_궤적_따라", 표적 + Vector2(-220, -6), Vector2(1150, 0))
			var 끝 := 점들[점들.size() - 1]
			var 닿음 := bool(총.get("_궤적_닿음"))
			var 불가 := bool(총.get("_탄착_불가"))
			check(닿음 and 끝.distance_to(표적) < 40.0, "조준선이 반딧불 몸에서 멈춤(끝 %.0f px)" % 끝.distance_to(표적))
			if 색 == ColorDefs.WHITE:
				check(불가, "흰 몸 → 흰 반딧불 = 빨간 X(소용없음)")
			else:
				check(not 불가, "검정 몸 → 흰 반딧불 = 표적 점(칠할 수 있음)")

	# ── ② C 풀이 ──
	var 거미 := 찾기("거미01") as Node2D
	var 줄 := 찾기("거미01_줄1")
	var R3 := 찾기("빛받이03")
	var 문3 := 찾기("빛받이03_문")
	check(거미 != null and 줄 != null and R3 != null and 문3 != null, "C: 거미 · 줄 · 빛받이3 · 창살3")
	if 거미 == null:
		_끝()
		return
	print("    거미 영역 %.1f칸 · 깨어남 %.1f칸 · 둥지 칸 %.1f" % [float(거미.get("영역_칸")), float(거미.get("깨어남_칸")), 거미.global_position.x / C])
	_죽음 = 0
	# 줄 너머(152)로 다가가 깨운다 — 흰 몸(반딧불 흰 빛 안이어도 안전)
	_p.global_position = Vector2(152 * C, 55 * C - 1)
	_p.velocity = Vector2.ZERO
	_p.set("player_color", ColorDefs.WHITE)
	var 깸 := false
	for f in 120:
		await wait(1)
		if int(거미.get("지금")) in [1, 2]:          # 깨어남 · 추적
			깸 = true
			break
	check(깸, "C: 줄 너머(152)로 다가가면 거미가 깨어남")
	# 왼쪽으로 걸어 물러나(140) 기다린다
	_p.set("자동_걷기", -1.0)
	for f in 240:
		await wait(1)
		if _p.global_position.x <= 140 * C:
			break
	_p.set("자동_걷기", 0.0)
	await wait(90)
	var 거미x := 거미.global_position.x / C
	check(_죽음 == 0 and 거미x > 145.5 and 거미x < 151.5, "C: 물러나면 거미는 영역 끝에서 멈춰 노려봄(거미 칸 %.1f · 사망 %d)" % [거미x, _죽음])
	# 반딧불이 147 에 내려앉아 빛을 켜는 순간 거미가 탄다
	var 탐 := -1
	var 열림 := -1
	for f in 60 * 45:
		await wait(1)
		if 탐 < 0 and int(거미.get("지금")) in [6, 7]:          # 탐 · 재
			탐 = f
		if 열림 < 0 and bool(R3.get("켜짐")):
			열림 = f
		if 탐 >= 0 and 열림 >= 0:
			break
	check(탐 >= 0, "C: 기다리면 반딧불 빛이 켜지며 거미가 탐(%.1f초)" % (탐 / 60.0))
	check(not bool(줄.call("완성")), "C: 거미가 타자 줄이 삭음")
	check(열림 >= 0, "C: 빛이 빛받이3 에 닿음(%.1f초)" % (열림 / 60.0))
	await wait(40)
	check(_죽음 == 0, "C: 풀이 내내 플레이어 사망 0(%d)" % _죽음)

	# ── 거미에게서 도망칠 수 있나: 다시 태어난 거미를 깨워 왼쪽 끝(120)까지 달아나도 안 죽는다 ──
	for f in 60 * 10:
		await wait(1)
		if int(거미.get("지금")) == 0:
			break
	_죽음 = 0
	_p.global_position = Vector2(152 * C, 55 * C - 1)
	_p.velocity = Vector2.ZERO
	await wait(45)
	_p.set("자동_걷기", -1.0)
	for f in 300:
		await wait(1)
		if _p.global_position.x <= 120 * C:
			break
	_p.set("자동_걷기", 0.0)
	await wait(240)
	check(_죽음 == 0 and absf(거미.global_position.x / C - 157.5) <= 11.0, "C: 깨운 뒤 달아나면 산다 · 거미는 영역 밖으로 안 나옴(거미 칸 %.1f)" % (거미.global_position.x / C))

	# ── ③ 세 번째 체크포인트(창살 너머 171) ──
	var 체 := _씬.get_node_or_null("체크포인트/체크04") as Node2D
	check(체 != null and absf(체.global_position.x / C - 171.5) < 0.6, "체크04 = 창살 너머 D 선반(칸 %.1f)" % (체.global_position.x / C if 체 else -1.0))
	if 체:
		for 색 in [ColorDefs.BLACK, ColorDefs.WHITE]:
			_죽음 = 0
			for f in 60 * 20:
				_p.global_position = 체.global_position + Vector2(0, -1)
				_p.velocity = Vector2.ZERO
				_p.set("player_color", 색)
				await wait(1)
				if _죽음 > 0:
					break
			check(_죽음 == 0, "체크04 에 %s 몸으로 20초 — 반딧불4·거미에 안 죽음" % ("검정" if 색 == ColorDefs.BLACK else "흰"))
	_끝()


func _끝() -> void:
	print("\n시험_거미방_풀이: 실패 %d" % failures)
	quit(1 if failures > 0 else 0)
