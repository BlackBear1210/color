extends SceneTree
## [2026-10-10 Claude] 10-10 보강(구조 검정 · 달빛 깔개 · 기믹 4개 이상) 실제 화면 확인용 촬영 — **창 모드**
##   Godot_console --path . -s res://tools/촬영_보강_20261010.gd
##   결과: res://tools/_진단/보강_20261010/<씬>_<이름>.png (git 무시 폴더)
##   플레이어를 그 자리(칸)에 세우고 물리를 멈춘 뒤 80 프레임(빛 점멸·반딧불이 한 번 움직일 시간) 뒤에 찍는다.
##   진행·기록 파일은 쓰지 않는다(SceneTree 시험 실행).
const 폴더 := "res://tools/_진단/보강_20261010/"
const 자리들 := [
	["쳅터1_02_복도_A", "달빛깔개", Vector2(44, 28)],
	["쳅터1_08_복도_D", "달빛깔개", Vector2(90, 28)],
	["쳅터1_12_복도_F", "달빛깔개_점멸", Vector2(118, 31)],
	["쳅터1_10_복도_E", "출구깔개", Vector2(160, 29)],
	["쳅터1_06_복도_C", "흰받침_유령판", Vector2(140, 27)],
	["쳅터1_01_방_시작방", "천장틈빛_흰바닥", Vector2(56, 49)],
	["쳅터1_01_방_시작방", "썩은마루_가시", Vector2(80, 49)],
	["쳅터1_03_방_서재", "색바뀌는빛_섬", Vector2(76, 56)],
	["쳅터1_07_방_수납실", "창문달빛_점멸", Vector2(14, 26)],
	["쳅터1_05_방_침실", "흰다리_색빛", Vector2(42, 18)],
	["쳅터1_04_복도_B", "점멸빛_그을음", Vector2(30, 31)],
	["쳅터1_14_굴뚝", "갇힘_메움", Vector2(37, 163)],
]


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(폴더))
	for 항목 in 자리들:
		var s = (load("res://scenes/쳅터1/스테이지/%s.tscn" % 항목[0]) as PackedScene).instantiate()
		root.add_child(s)
		current_scene = s
		for i in 20:
			await physics_frame
		var p = s.get_node("Player")
		p.global_position = 항목[2] * 32.0
		p.set("player_color", ColorDefs.BLACK)
		p.set_physics_process(false)
		s.set_physics_process(false)          # 사망 판정을 멈춰 그 자리에 그대로
		for i in 80:
			await physics_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(폴더 + "%s_%s.png" % [항목[0], 항목[1]])
		s.queue_free()
		await process_frame
	quit()
