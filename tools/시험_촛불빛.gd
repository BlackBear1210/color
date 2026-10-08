extends SceneTree
## ============================================================================
## [2026-10-07 Claude] 촛불등 체크포인트 빛 단계 시험 — 창 모드로 실행(촬영 포함)
##   Godot_console --path . -s res://tools/시험_촛불빛.gd
## 도형님: "에너지파 말고 은은한 광원. 켜면 은은하게 밝아지고, 시간이 지나거나 다음 체크포인트로 넘어가면 빛을 좀 잃게."
## 확인: ① 켜진 직후 고리(에너지파) 없음 · 천천히 차오름 ② 다 밝아짐 ③ 시간이 지나면 은은함 ④ 다른 체크포인트가 켜지면 불씨
##   ⑤ 예전 체크포인트를 다시 저장하면 다시 밝아짐. 결과 PNG: res://tools/_진단/촛불빛/
## ============================================================================
const 씬 := "res://scenes/쳅터1/스테이지/쳅터1_01_방_시작방.tscn"
const 폴더 := "res://tools/_진단/촛불빛/"
var 실패 := 0


func _initialize() -> void:
	call_deferred("진행")


func 확인(조건: bool, 이름: String) -> void:
	print(("통과 " if 조건 else "실패 ") + 이름)
	if not 조건:
		실패 += 1


func 틱(n: int) -> void:
	for i in n:
		await physics_frame


func 찍기(이름: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(폴더 + 이름 + ".png"))


func 진행() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(폴더))
	root.size = Vector2i(1280, 720)
	var s: Node2D = load(씬).instantiate()
	root.add_child(s)
	current_scene = s
	await 틱(20)
	var p: CharacterBody2D = s.get_node("Player")
	var a: Area2D = s.get_node("체크포인트/체크02")
	var b: Area2D = s.get_node("체크포인트/체크01")
	for c in s.find_children("*", "Camera2D", true, false):
		c.enabled = false
		c.process_mode = Node.PROCESS_MODE_DISABLED
	var cam := Camera2D.new()
	cam.position = a.global_position + Vector2(60, -120)
	cam.zoom = Vector2(1.6, 1.6)
	s.add_child(cam)
	cam.make_current()
	for n in s.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	p.global_position = a.global_position + Vector2(-90, -2)
	await 틱(10)
	await 찍기("0_꺼짐")
	p.global_position = a.global_position + Vector2(0, -2)
	p.velocity = Vector2.ZERO
	await 틱(12)
	확인(a.활성, "착지로 켜짐")
	확인(a._펄스 == 0.0, "퍼지는 고리(에너지파) 없음")
	확인(a._밝기 < 0.5, "켜진 직후엔 아직 차오르는 중 (밝기 %.2f)" % a._밝기)
	await 찍기("1_켜지는중")
	p.global_position = a.global_position + Vector2(-90, -2)
	await 틱(120)
	확인(a._밝기 > 0.95, "2초 뒤 다 밝아짐 (밝기 %.2f)" % a._밝기)
	await 찍기("2_밝음")
	# 시간이 지남 — 12초를 기다리는 대신 켜진 시간을 넘겨 놓고 내려가는 것만 본다
	a._켜진시간 = a.밝음_유지 + 0.1
	await 틱(300)
	확인(absf(a._밝기 - a.은은함) < 0.03, "시간이 지나 은은함 (밝기 %.2f)" % a._밝기)
	await 찍기("3_은은함")
	# 다음 체크포인트
	b.켜기()
	await 틱(240)
	확인(absf(a._밝기 - a.남은불씨) < 0.03, "다음 체크포인트가 켜지면 불씨 (밝기 %.2f)" % a._밝기)
	확인(b._목표밝기 == 1.0, "새 체크포인트는 밝아지는 중")
	await 찍기("4_불씨")
	# 예전 체크포인트를 다시 저장
	a.켜기()
	await 틱(150)
	확인(a._밝기 > 0.95 and b._목표밝기 == b.남은불씨, "예전 것을 다시 저장하면 다시 밝아지고 다른 것은 불씨")
	print("촛불빛 실패 ", 실패)
	quit(1 if 실패 else 0)
