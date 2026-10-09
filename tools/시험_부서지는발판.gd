extends SceneTree
## ============================================================================
## [2026-10-08 Claude] 부서지는 발판 v3 시험 — 기획 §4-F 확정 규칙을 실제 스테이지(하수도 2-4)에서 확인한다.
##   ① 밟으면 0.3 금 1 → 0.6 금 2 → 0.9 부서짐(콜리전 꺼짐)   ② 칠해도 타이머 그대로(보강 불가)
##   ③ 저절로 복구 안 됨(4초 기다려도 부서진 채)                ④ 죽어 부활하면 전부 복구
## 실행: Godot_console --headless --fixed-fps 60 --path . -s res://tools/시험_부서지는발판.gd
##   창 모드면 화면도 남긴다: tools/_진단/부서지는발판/
## ============================================================================
const OUT := "res://tools/_진단/부서지는발판/"
const 씬경로 := "res://scenes/world_2_클로드/stage_2-4.tscn"

var failures := 0
var _씬: Node = null
var _p: CharacterBody2D = null


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func shot(label: String, 관심: Rect2 = Rect2()) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var img := root.get_texture().get_image()
	if 관심.size != Vector2.ZERO:
		var xf := root.get_canvas_transform()
		var a := xf * 관심.position
		var b := xf * 관심.end
		var r := Rect2i(Vector2i(a), Vector2i(b - a)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		if r.size.x < 4 or r.size.y < 4:
			return
		img = img.get_region(r)
	img.save_png(OUT + label + ".png")


## ⚠ 2-4 의 부서지는발판_1~4 는 판정 폴리곤이 340×288 인데 176~192 간격으로 놓여 **이웃과 150px 씩 겹친다**
##   (씬 데이터 그대로 — 2026-10-08 실측). 가운데에 세우면 이웃 발판을 밟은 것으로 잡히므로 왼쪽 끝 60px 에 세운다.
func 발판_윗면(발: Node2D) -> Vector2:
	var r: Rect2 = 발.call("_범위")
	return 발.to_global(Vector2(r.position.x + 60.0, r.position.y))


func 세우기(발: Node2D) -> void:
	# 발판 윗면 가운데에 발을 딛게 — 색은 발판 색(같은 색이라 안 죽는다)
	var 위 := 발판_윗면(발)
	_p.global_position = 위 + Vector2(0, -2)
	_p.velocity = Vector2.ZERO
	var 색: int = 발.call("현재색")
	_p.set("player_color", ColorDefs.WHITE if 색 == ColorDefs.WHITE else ColorDefs.BLACK)


func 붙잡기(발: Node2D, 프레임: int) -> void:
	# 발판이 꺼질 때까지 그 위에 세워 둔다(떨어져 죽지 않게 매 프레임 다시 세운다 — 판정만 본다)
	for i in 프레임:
		if bool(발.call("부서졌나")):
			return
		await wait(1)


func run() -> void:
	root.size = Vector2i(1920, 1080)
	_씬 = (load(씬경로) as PackedScene).instantiate()
	root.add_child(_씬)
	current_scene = _씬
	_p = _씬.get_node("Player") as CharacterBody2D
	await wait(20)
	var 발들 := get_nodes_in_group("붕괴발판")
	check(발들.size() == 4, "2-4 부서지는 발판 4 개가 그룹에 있다(%d)" % 발들.size())
	var 발 := 발들[0] as Node2D
	var 관심 := Rect2(발판_윗면(발) + Vector2(-220, -200), Vector2(440, 360))

	# ① 리듬
	세우기(발)
	세우기(발)
	var 시작 := -1
	var 금1 := -1
	var 금2 := -1
	var 끝 := -1
	for f in 120:
		await wait(1)
		var 단 := int(발.get("_붕괴단계"))
		var 금 := int(발.get("_금단계"))
		if 시작 < 0 and 단 >= 1:
			시작 = f
		if 금1 < 0 and 금 >= 1:
			금1 = f
			await shot("1_금1", 관심)
		if 금2 < 0 and 금 >= 2:
			금2 = f
			await shot("2_금2_처짐", 관심)
		if 단 == 2:
			끝 = f
			break
	await wait(3)
	await shot("3_부서짐_파편", 관심)
	var 초 := func(a: int, b: int) -> float: return float(b - a) / 60.0
	check(시작 >= 0, "밟자 금 가기 시작")
	check(금1 > 0 and absf(초.call(시작, 금1) - 0.3) < 0.05, "금 1 ≈ 0.3초(%.2f)" % 초.call(시작, 금1))
	check(금2 > 0 and absf(초.call(시작, 금2) - 0.6) < 0.05, "금 2·처짐 ≈ 0.6초(%.2f)" % 초.call(시작, 금2))
	check(끝 > 0 and absf(초.call(시작, 끝) - 0.9) < 0.05, "부서짐 ≈ 0.9초(%.2f)" % 초.call(시작, 끝))
	var 폴리: CollisionPolygon2D = 발.call("get_collision_polygon_node")
	await wait(2)
	check(폴리.disabled, "부서지면 콜리전 꺼짐")

	# ③ 자동 복구 없음
	# 플레이어는 멈춰 둔다 — 떨어져 죽으면 부활 복구가 일어나 '저절로 복구' 와 구분이 안 된다
	_p.set_physics_process(false)
	await wait(240)
	_p.set_physics_process(true)
	check(bool(발.call("부서졌나")), "4초 지나도 부서진 채(자동 복구 없음)")
	await shot("4_4초뒤_부서진채", 관심)

	# ② 칠해도 보강 안 됨 — 다른 발판을 칠한 뒤 밟는다
	var 발2 := 발들[1] as Node2D
	발2.call("명중", ColorDefs.BLACK, 발판_윗면(발2) + Vector2(0, 8))
	await wait(30)
	세우기(발2)
	var 시작2 := -1
	var 끝2 := -1
	for f in 120:
		await wait(1)
		if 시작2 < 0 and int(발2.get("_붕괴단계")) >= 1:
			시작2 = f
		if bool(발2.call("부서졌나")):
			끝2 = f
			break
	check(끝2 > 0 and absf(float(끝2 - 시작2) / 60.0 - 0.9) < 0.05, "칠한 발판도 0.9초에 부서짐(보강 불가 · %.2f)" % (float(끝2 - 시작2) / 60.0))

	# ④ 부활하면 전부 복구
	_씬.call("_리스폰")
	await wait(120)
	for b in 발들:
		print("  부활 뒤 %s 부서짐=%s · 플레이어 %s" % [b.name, b.call("부서졌나"), _p.global_position])
	check(not bool(발.call("부서졌나")) and not bool(발2.call("부서졌나")), "죽어 부활하면 부서진 발판 전부 복구")
	check(not 폴리.disabled, "복구되면 콜리전 다시 켜짐")
	await shot("5_부활_복구", 관심)

	print("\n시험_부서지는발판: 실패 %d" % failures)
	quit(1 if failures > 0 else 0)
