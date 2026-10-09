extends SceneTree
## ============================================================================
## [2026-10-10 Claude] 새 열쇠 스테이지(04·08·11·14) · 반딧불(02·10·12) 화면 촬영 — 창 모드여야 찍힌다
##   조각이 보이게 그 색 몸으로 조각 근처 바닥에 세우고 찍는다. 반딧불은 첫 정지점에서 빛을 낼 때.
## 실행: Godot_console --fixed-fps 60 --path . -s res://tools/촬영_열쇠_반딧불_추가.gd   → tools/_진단/열쇠반딧불/
## ⚠ 진행 파일을 쓰지 않는다(기록_허용 = 0).
## ============================================================================
const OUT := "res://tools/_진단/열쇠반딧불/"
const C := 32.0


func _initialize() -> void:
	call_deferred("run")


func 찍기(이름: String, 칸: Vector2, 색: int, 파일: String, 기다림: int = 50) -> void:
	for c in root.get_children():
		if c.get_node_or_null("Player") != null:
			c.queue_free()
	await process_frame
	var s := (load("res://scenes/쳅터1/스테이지/" + 이름 + ".tscn") as PackedScene).instantiate()
	root.add_child(s)
	current_scene = s
	s.set_physics_process(false)          # 사진용 — 사망 판정을 멈춘다
	var p := s.get_node("Player") as CharacterBody2D
	for i in 10:
		await physics_frame
	for i in 기다림:
		p.global_position = 칸 * C + Vector2(0, -1)
		p.velocity = Vector2.ZERO
		p.set("player_color", 색)
		await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + 파일)
	print("저장 ", 파일)


func run() -> void:
	게임진행.기록_허용 = 0
	root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var B := ColorDefs.BLACK
	var W := ColorDefs.WHITE
	await 찍기("쳅터1_04_복도_B", Vector2(115, 21), W, "04_윗갈래_흰조각.png")
	await 찍기("쳅터1_04_복도_B", Vector2(115, 21), B, "04_검정몸_아래갈래_검정조각.png")
	await 찍기("쳅터1_08_복도_D", Vector2(73, 23), W, "08_흰선반_흰조각.png")
	await 찍기("쳅터1_08_복도_D", Vector2(112.5, 25), B, "08_흰판위_검정조각(검정몸).png")
	await 찍기("쳅터1_11_거실", Vector2(74, 49), B, "11_샹들리에길_검정조각.png")
	await 찍기("쳅터1_11_거실", Vector2(212, 34), W, "11_발코니_흰조각.png")
	await 찍기("쳅터1_14_굴뚝", Vector2(34, 64), B, "14_체크포인트위_검정조각(검정몸).png")
	await 찍기("쳅터1_02_복도_A", Vector2(80.5, 31), W, "02_반딧불_입문.png", 70)
	await 찍기("쳅터1_10_복도_E", Vector2(108, 20), W, "10_반딧불_윗선반.png", 70)
	await 찍기("쳅터1_12_복도_F", Vector2(110, 31), W, "12_반딧불_긴바닥.png", 70)
	quit()
