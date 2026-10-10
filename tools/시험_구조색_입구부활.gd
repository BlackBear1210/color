extends SceneTree
## ============================================================================
## [2026-10-10 Claude] 도형님 제보 두 가지를 실제 씬으로 확인한다.
##   ① 05 침실 "흰색인데 안 죽는 버그" — 구조(테두리·선반)가 `구조_판정색 = 검정` 이 됐다:
##      흰 몸으로 구조 바닥에 서면 죽고, 검정 몸이면 산다. 칠은 여전히 안 된다(총알 blocked).
##   ② 06 복도C "공중에서 무한 리스폰" — 쳅터1 은 체크포인트(촛불등)를 켜기 전이면 **입구**에서 부활한다.
##      자동 안전지점을 쓰지 않고, 부활하면 입구 바닥 색(검정)으로 몸을 맞춘다. 칠한 유령판은 안전지점이 아니다.
##
## 실행: Godot_console --headless --fixed-fps 60 --path . -s res://tools/시험_구조색_입구부활.gd
## 진행·기록 파일은 쓰지 않는다(시험 실행 = SceneTree 스크립트 → 게임진행.기록해도_되나 = false).
## ============================================================================

const 침실 := "res://scenes/쳅터1/스테이지/쳅터1_05_방_침실.tscn"
const 복도C := "res://scenes/쳅터1/스테이지/쳅터1_06_복도_C.tscn"
const C := 32.0
var 실패 := 0


func _initialize() -> void:
	call_deferred("_실행")


func _확인(ok: bool, 이름: String) -> void:
	print(("PASS " if ok else "FAIL ") + 이름)
	if not ok:
		실패 += 1


func _프레임(n: int) -> void:
	for i in n:
		await physics_frame


func _올리기(경로: String) -> Node2D:
	var 씬: Node2D = load(경로).instantiate()
	root.add_child(씬)
	current_scene = 씬
	await _프레임(20)
	return 씬


func _세우기(p: CharacterBody2D, 칸x: float, 칸y: float, 색: int) -> void:
	p.velocity = Vector2.ZERO
	p.global_position = Vector2(칸x * C, 칸y * C - 1.0)
	p.set("player_color", 색)
	await _프레임(6)


func _실행() -> void:
	# ── ① 05 침실: 구조 바닥 색 ──────────────────────────────────────────
	var 씬 := await _올리기(침실)
	var p: CharacterBody2D = 씬.get_node("Player")
	씬.set("_무적", 0.0)
	# 오른쪽 아래 구조 바닥(칸 72~74 · 바닥 49) — 스크린샷의 자리
	await _세우기(p, 73.5, 49, ColorDefs.BLACK)
	_확인(p.is_on_floor(), "05 구조 바닥에 선다")
	_확인(not 씬._사망_판정(), "05 검정 몸 + 구조 바닥 = 산다")
	p.set("player_color", ColorDefs.WHITE)
	await _프레임(2)
	_확인(씬._사망_판정(), "05 흰 몸 + 구조 바닥 = 죽는다(버그 수정)")
	# 흰 판(59~64 · 바닥 49) 위 흰 몸은 산다
	await _세우기(p, 61.5, 49, ColorDefs.WHITE)
	_확인(not 씬._사망_판정(), "05 흰 몸 + 흰 판 = 산다")
	# 구조는 여전히 칠 수 없다
	var 구조 := 씬.get_node("지형/구조01")
	_확인(구조.명중(ColorDefs.WHITE, 구조.global_position) == "blocked", "05 구조는 칠이 안 된다(blocked)")
	_확인(int(구조.get("구조_판정색")) == 1, "05 구조_판정색 = 검정")

	# ── ② 입구 부활 ─────────────────────────────────────────────────────
	_확인(bool(씬.get("_입구_부활")), "쳅터1 = 입구 부활 켜짐")
	var 입구: Vector2 = 씬.get("_입구점")
	# 체크포인트 없이: 흰 몸으로 멀리서 죽으면 → 입구 · 검정 몸
	await _세우기(p, 73.5, 49, ColorDefs.WHITE)
	await _프레임(40)          # 자동 안전지점이 있었다면 이 사이에 저장됐을 시간
	await 씬._리스폰()
	_확인(p.global_position.distance_to(입구) < 1.0, "체크포인트 없음 → 입구에서 부활 %s ≈ %s" % [p.global_position, 입구])
	_확인(int(p.get("자유색")) == ColorDefs.BLACK, "입구 부활 → 입구 바닥(구조) 색 = 검정")
	씬.set("_무적", 0.0)
	await _프레임(30)
	_확인(not 씬._사망_판정(), "입구 부활 뒤 산다")
	# 촛불등을 켜면 그 자리에서 부활
	var 체크: Area2D = 씬.get_node("체크포인트/체크02")
	p.velocity = Vector2.ZERO
	p.global_position = 체크.global_position + Vector2(0, -2)
	p.set("player_color", ColorDefs.BLACK)
	await _프레임(10)
	_확인(bool(씬.get("_체크포인트_저장됨")), "촛불등 착지 → 저장")
	var 저장: Vector2 = 씬.get("_체크포인트_위치")
	await _세우기(p, 73.5, 49, ColorDefs.BLACK)
	await 씬._리스폰()
	_확인(p.global_position.distance_to(저장) < 1.0, "체크포인트 있음 → 촛불등에서 부활")
	씬.queue_free()
	await process_frame

	# ── ② 06 복도C: 칠한 유령판 위에서 죽어도 허공에서 부활하지 않는다 ─────────────
	씬 = await _올리기(복도C)
	p = 씬.get_node("Player")
	씬.set("_무적", 0.0)
	입구 = 씬.get("_입구점")
	var 유령: Node = null
	for n in 씬.get_node("지형").get_children():
		if String(n.name).begins_with("유령판") and absf(n.global_position.x - 127.0 * C) < 4 * C:
			유령 = n
	_확인(유령 != null, "06 빛 아래 유령판(124~129) 찾음")
	if 유령:
		# 흰색으로 칠해 굳힌다(시험용 — 게임에선 총으로 칠한다)
		for i in 12:
			유령.명중(ColorDefs.WHITE, 유령.global_position + Vector2(-60 + i * 10, -20))
		await _프레임(4)
		await _세우기(p, 127.0, 25, ColorDefs.WHITE)
		_확인(p.is_on_floor(), "06 흰 칠한 유령판 위에 선다")
		_확인(씬._유령판_위인가(), "06 발밑 = 칠한 유령판으로 알아본다(안전지점 금지)")
		await _프레임(40)
		await 씬._리스폰()
		_확인(p.global_position.distance_to(입구) < 1.0, "06 유령판에서 죽어도 → 입구에서 부활")
		씬.set("_무적", 0.0)
		await _프레임(60)
		_확인(not 씬._사망_판정() and p.is_on_floor(), "06 부활 뒤 바닥에 서서 산다(무한 사망 없음)")
	씬.queue_free()
	await process_frame
	print("구조색·입구부활 실패 %d" % 실패)
	quit(1 if 실패 else 0)
