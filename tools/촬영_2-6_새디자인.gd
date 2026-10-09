extends SceneTree
## [2026-10-09] 2-6 v3(uvtt map_242x120) 실제 게임 화면 촬영 — 도형님 10-09 새 디자인
##   (지형·격자 `챕터1_원근` · 물 삼색 프레임 + 정면 배관 출수구)이 2-6 에서 실제로 어떻게 보이는지 본다.
##   창 모드로 돌린다(헤드리스는 그림이 안 나온다):
##   "C:/Users/Public/godot46/Godot_v4.6.3-stable_win64_console.exe" --path . --resolution 1920x1080 -s res://tools/촬영_2-6_새디자인.gd
##   결과: docs/visual_review/stage_2-6_20261009/view_N_이름.png (줌 1.0 · 1920×1080)
const 씬 := "res://scenes/world_2_클로드/stage_2-6.tscn"
const 폴더 := "res://docs/visual_review/stage_2-6_20261009/"
## [이름, 카메라 가운데] — 좌표 근거는 tools/build_하수도_2-6.gd
const 장면들 := [
	["수갱_물받이", Vector2(1850, 560)],    # 천장 물받이 4 (물_1~4 정면 배관)
	["수갱_위", Vector2(1800, 900)],        # 시작 복도 끝 · 위쪽 격자
	["수갱_가운데", Vector2(1850, 1900)],   # 격자 사이 물기둥 · 번갈이
	["수갱_아래", Vector2(2300, 2700)],     # 긴 격자 · L 바위 밑 · 아래 블록 왼끝
	["벨브_호퍼", Vector2(3500, 900)],      # 벨브_1 · 흰물_1 물받이 · 호퍼
	["곁길", Vector2(4800, 900)],           # 세로 가시 · 흰물_3 정면 배관 · 흰 공중발판
	["열쇠복도", Vector2(6400, 750)],        # 천장 톱 · 검정 열쇠
	["아래블록", Vector2(3700, 2800)],      # 흰물_2 · 양동이 · 발판_1 · CP
	["도착", Vector2(6600, 2900)],          # 움직이는 발판 · 기둥 · 투명 발판 · 도착 문
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(폴더))
	var stage := (load(씬) as PackedScene).instantiate()
	root.add_child(stage)
	for i in 40:
		await process_frame
	var player := stage.get_node("Player") as Node2D
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var camera := stage.get("_카메라") as Camera2D
	if camera != null:
		camera.set("target", null)
		camera.zoom = Vector2.ONE
	for n in 장면들.size():
		var 자리: Vector2 = 장면들[n][1]
		player.global_position = 자리 + Vector2(-600, 2000)      # 화면 밖(몸이 장면을 가리지 않게)
		if camera != null:
			camera.global_position = 자리
			camera.reset_smoothing()
		# 물 앞끝이 다 내려오고 번갈이가 한 번 돌 만큼 기다린다(3 초 주기 · 출수 1.4 배속)
		for i in 90:
			await process_frame
		await RenderingServer.frame_post_draw
		var 길 := 폴더 + "view_%d_%s.png" % [n + 1, String(장면들[n][0])]
		root.get_texture().get_image().save_png(길)
		print("CAPTURE 2-6 ", 길)
	quit()
