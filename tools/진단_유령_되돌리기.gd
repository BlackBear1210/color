extends SceneTree
## ============================================================================
## [2026-09-08 STEP 16 신규] 유령 발판 **오칠 복구** 검사 — 소프트락 잡기 전용
## ----------------------------------------------------------------------------
## 실행: godot --headless --path . -s res://tools/진단_유령_되돌리기.gd -- <씬경로>
##       (인자가 없으면 STAGE 2)
##
## # STEP16:
## # 문제: STEP 15 에서 `EXIT_GHOST` 가 `경계_반딧불이`(흰색 강제 구역) 한가운데라
## #       **검정으로 칠하면 밟는 순간 죽는다**. 설계된 함정이라고 적어 두긴 했는데,
## #       "잘못 칠한 뒤 되돌릴 수 있는가" 를 아무도 확인하지 않았다.
## #       되돌릴 수 없으면 그건 함정이 아니라 **소프트락**이고, 출시 불가 결함이다.
## # 목적: 유령을 잘못된 색으로 칠한 상태에서 **다시 반대색으로 칠해 복구되는지**를
## #       숫자로 확인한다. 그리고 죽었을 때 어디서 다시 시작하는지도 같이 본다.
## # 해결: 유령마다 ① 틀린 색으로 칠하고 ② 색이 실제로 그 색인지 확인한 뒤
## #       ③ 반대색으로 다시 칠해 ④ 색이 뒤집혔는지 + 여전히 밟을 수 있는지를 잰다.
## #       ⑤ 그 위에서 죽었을 때 리스폰 지점이 맵 처음이 아니라 **직전 안전지점**인지도 잰다.
##
## ⚠ 이 도구는 아무것도 고치지 않는다. 재서 PASS/FAIL 만 보고한다.
## ============================================================================

const 기본씬 := "res://scenes/집/스테이지_2_복도계단.tscn"
const 검정 := 0
const 흰색 := 1

var _루트: Node = null
var _p: CharacterBody2D = null
var _결과: Array = []


func _init() -> void:
	Engine.max_fps = 120
	call_deferred("_go")


func _go() -> void:
	var 씬경로 := 기본씬
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			씬경로 = a

	_루트 = (load(씬경로) as PackedScene).instantiate()
	root.add_child(_루트)
	current_scene = _루트
	for _i in 40:
		await process_frame
	_p = _찾기(_루트, func(n): return String(n.name).ends_with("Player")) as CharacterBody2D

	print("")
	print("════════ 유령 오칠 복구 검사 — %s ════════" % 씬경로.get_file())

	var 유령들: Array = []
	for n in _모두(_루트):
		if n.get("칠하기_허용") == null:
			continue
		if n.has_method("유령인가") and bool(n.call("유령인가")):
			유령들.append(n)
		elif String(n.name).contains("GHOST"):
			유령들.append(n)

	if 유령들.is_empty():
		print("  (유령 발판 없음)")
		_끝()
		return

	for t in 유령들:
		await _한장(t)

	# ── 죽었을 때 어디서 다시 시작하나 ──
	await _리스폰_검사()

	print("")
	print("──────────── 결과 ────────────")
	var 통과 := 0
	for r in _결과:
		var ok: bool = r[1]
		if ok:
			통과 += 1
		print("  %-34s %s   %s" % [r[0], "PASS  " if ok else "✗ FAIL", r[2]])
	print("  ─────────────────────────────")
	print("  %d / %d PASS" % [통과, _결과.size()])
	print("════════════════════════════════")
	_끝()


## 유령 한 장 : 틀린 색으로 칠했다가 반대색으로 되돌린다.
func _한장(t: Node) -> void:
	var 이름 := String(t.name)
	var 필요: int = int(t.call("필요횟수"))

	# ① 먼저 **검정**으로 칠한다.
	for i in 필요:
		t.call("명중", 검정, t.global_position)
	for _i in 6:
		await physics_frame
	var 색1: int = int(t.call("현재색")) if t.has_method("현재색") else -99
	var 밟1: bool = bool(t.call("밟을_수_있나"))

	# ② 이제 **흰색**으로 다시 칠한다 — 되돌릴 수 있는가?
	for i in 필요:
		t.call("명중", 흰색, t.global_position)
	for _i in 6:
		await physics_frame
	var 색2: int = int(t.call("현재색")) if t.has_method("현재색") else -99
	var 밟2: bool = bool(t.call("밟을_수_있나"))

	var 뒤집힘 := (색1 != 색2) and (색2 == 흰색)
	_결과.append([이름 + " 검정→흰색 되돌리기", 뒤집힘 and 밟2,
		"검정칠 후 색=%d(밟기=%s) → 흰색칠 후 색=%d(밟기=%s) · %d발"
		% [색1, 밟1, 색2, 밟2, 필요]])

	# ③ 반대 방향도 확인 (흰색 → 검정)
	for i in 필요:
		t.call("명중", 검정, t.global_position)
	for _i in 6:
		await physics_frame
	var 색3: int = int(t.call("현재색")) if t.has_method("현재색") else -99
	var 밟3: bool = bool(t.call("밟을_수_있나"))
	_결과.append([이름 + " 흰색→검정 되돌리기", (색3 == 검정) and 밟3,
		"흰색칠 후 색=%d → 검정칠 후 색=%d(밟기=%s)" % [색2, 색3, 밟3]])


## 죽었을 때 맵 처음으로 보내지는가, 직전 안전지점으로 가는가.
func _리스폰_검사() -> void:
	if _p == null:
		_결과.append(["리스폰 지점", false, "Player 를 못 찾았다"])
		return
	var 시작 = _루트.get("시작_위치")
	# 1층 바닥 한복판에 충분히 오래 서 있게 해서 안전지점을 그 자리에 찍는다.
	var 안전자리 := Vector2(11000.0, 2400.0)
	_p.set("player_color", 흰색)
	_p.velocity = Vector2.ZERO
	_p.global_position = 안전자리
	for _i in 260:            # 안전지점_유예를 넉넉히 넘긴다
		await physics_frame
	var 찍힌곳 := _p.global_position

	# 낙사시킨다 (낙사_y 아래로 던진다).
	_p.global_position = Vector2(11000.0, float(_루트.get("낙사_y")) + 400.0)
	for _i in 120:
		await physics_frame
	var 다시 := _p.global_position
	var 처음으로 := 시작 is Vector2 and 다시.distance_to(시작) < 400.0
	_결과.append(["낙사 후 리스폰 지점", not 처음으로,
		"섰던 곳 (%.0f, %.0f) → 리스폰 (%.0f, %.0f) · 맵 처음으로 갔나=%s"
		% [찍힌곳.x, 찍힌곳.y, 다시.x, 다시.y, 처음으로]])


func _끝() -> void:
	_루트.queue_free()
	for _i in 3:
		await process_frame
	quit(0)


func _모두(n: Node, 모음: Array = []) -> Array:
	모음.append(n)
	for c in n.get_children():
		_모두(c, 모음)
	return 모음


func _찾기(뿌리: Node, 조건: Callable) -> Node:
	if 조건.call(뿌리):
		return 뿌리
	for c in 뿌리.get_children():
		var r := _찾기(c, 조건)
		if r != null:
			return r
	return null
