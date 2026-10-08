extends SceneTree
## 도형 요청: 같은 실제 시작방·1920×1080·줌 1에서 전후와 점화/재진입/부활을 확인한다.
const SCENE := "res://scenes/쳅터1/스테이지/쳅터1_01_방_시작방.tscn"
const OUT := "res://tools/_진단/촛불체크/"
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + label + ".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1920, 1080)
	var scene: Node2D = load(SCENE).instantiate()
	var baseline := "--baseline" in OS.get_cmdline_user_args()
	if baseline:
		# 동일 씬에서 체크포인트 외형만 HEAD 버전으로 바꿔 전후 비교의 좌표·줌을 고정한다.
		scene.get_node("체크포인트/체크02").set_script(load("res://tools/_진단/촛불체크/기존_체크포인트.gd"))
	root.add_child(scene)
	current_scene = scene
	await frames(20)
	var p: CharacterBody2D = scene.get_node("Player")
	var cp: Area2D = scene.get_node("체크포인트/체크02")
	for c in scene.find_children("*", "Camera2D", true, false):
		c.enabled = false
		c.process_mode = Node.PROCESS_MODE_DISABLED
	var cam := Camera2D.new()
	cam.position = cp.position + Vector2(0, -180)
	cam.zoom = Vector2.ONE
	scene.add_child(cam)
	cam.make_current()
	p.global_position = cp.global_position + Vector2(-140, -2)
	p.velocity = Vector2.ZERO
	await frames(20)
	if baseline:
		await shot("00_수정전")
		quit()
		return
	await shot("01_꺼짐")
	check(not cp.활성, "방문 전 꺼짐")
	p.global_position = cp.global_position + Vector2(0, -2)
	p.velocity = Vector2.ZERO
	await frames(8)
	await shot("02_점화")
	check(cp.활성, "실제 착지로 점화")
	check(scene._저장체크 == cp, "실제 월드 저장 연결")
	var saved: Vector2 = scene._체크포인트_위치
	var saved_color: int = scene._체크포인트_색
	await frames(80)
	await shot("03_켜짐")
	check(cp._펄스 == 0.0, "확산 효과 소멸")
	p.global_position += Vector2(-140, 0)
	await frames(10)
	p.global_position = saved
	await frames(10)
	check(cp._펄스 == 0.0, "재진입 효과 중복 없음")
	p.global_position += Vector2(400, -100)
	p.set("player_color", 1 - saved_color)
	# 리스폰은 사망 모션을 기다린 뒤 옮긴다(2026-10 원격 병합) → 끝날 때까지 기다린다.
	await scene._리스폰()
	check(p.global_position.distance_to(saved) < 0.01, "리스폰 위치 복원")
	check(p.get("자유색") == saved_color, "리스폰 색 복원")
	await frames(50)
	await shot("04_리스폰")
	check(not scene._사망_판정(), "리스폰 후 생존")
	print("CHECKPOINT FAILURES ", failures)
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
