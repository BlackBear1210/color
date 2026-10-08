extends SceneTree
## 실제 15번 씬에서 반사 법칙·가림·색 판정·동적 해제와 하수도까지 걷기를 검사한다.
const PATH := "res://scenes/쳅터1/스테이지/쳅터1_15_집밖_하수도길.tscn"
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func wait(n: int) -> void:
	for i in n:
		await physics_frame
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1
func shot(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tools/_진단/촛불체크/" + label + ".png")
func run() -> void:
	root.size = Vector2i(1920,1080)
	var scene: Node2D = load(PATH).instantiate()
	root.add_child(scene)
	current_scene = scene
	await wait(30)
	await shot("05_집밖_처마")
	var rig: Node2D = scene.get_node("반사빛길")
	check(not rig.길켜짐, "어긋난 거울은 길을 만들지 않음")
	rig.거울.법선각 = -45.0
	await wait(4)
	check(rig.길켜짐, "45도 거울의 아래→오른쪽 반사")
	check(rig.반대색인가(ColorDefs.BLACK) and not rig.반대색인가(ColorDefs.WHITE), "굳은 빛은 흰색 규칙")
	var p: CharacterBody2D = scene.get_node("Player")
	p.set("player_color", ColorDefs.WHITE)
	# [2026-10-07 Claude] 발판 y 40 → 25(윗면 = 노드 +16) 에 맞춰 발을 윗면 바로 위에 둔다
	p.global_position = rig.global_position + Vector2(120, 10)
	p.velocity = Vector2.ZERO
	await wait(18)
	check(p.is_on_floor(), "반사광 발판 실제 착지")
	await shot("06_거울_켜짐")
	rig.거울.position.x = 120
	await wait(4)
	check(not rig.길켜짐, "거울 이동시 광로 재계산 및 길 소멸")
	rig.거울.position.x = 0
	await wait(4)
	check(rig.길켜짐, "거울 복귀시 길 재생성")
	var blocker := StaticBody2D.new()
	blocker.position = rig.global_position + Vector2(280, 0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24,100)
	shape.shape = rect
	blocker.add_child(shape)
	scene.add_child(blocker)
	await wait(4)
	check(not rig.길켜짐, "중간 벽은 반사광을 차단")
	blocker.queue_free()
	await wait(4)
	check(rig.길켜짐, "가림 제거 복구")
	rig.거울.법선각 = -15
	await wait(4)
	await shot("07_거울_꺼짐")
	# 안전한 마당에서 실제 캐릭터를 걷게 하여 하수도 진입을 검증한다.
	p.global_position = Vector2(4700,1500)
	p.velocity = Vector2.ZERO
	p.set("자동_걷기",1.0)
	for i in 400:
		await physics_frame
		if current_scene != scene:
			break
	check(current_scene.scene_file_path == "res://scenes/world_2_클로드/stage_2-1.tscn", "집 밖에서 하수도 2-1 실제 연결")
	await wait(160)
	await shot("08_하수도_진입")
	print("EXTERIOR FAILURES ", failures)
	load("res://scripts/쳅터1/전경전환.gd").보관_비우기()
	current_scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
