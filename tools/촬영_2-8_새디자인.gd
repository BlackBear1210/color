extends SceneTree
## [2026-10-10] 2-8 v3(uvtt map_188x114 「두 갈래 탑」) 실제 게임 화면 촬영 — 2-6 촬영 도구와 같은 짜임.
##   창 모드로 돌린다(헤드리스는 그림이 안 나온다):
##   "C:/Users/Public/godot46/Godot_v4.6.3-stable_win64_console.exe" --path . --resolution 1920x1080 -s res://tools/촬영_2-8_새디자인.gd
##   결과: docs/visual_review/stage_2-8_20261010/view_N_이름.png (줌 1.0 · 1920×1080)
const 씬 := "res://scenes/world_2_클로드/stage_2-8.tscn"
const 폴더 := "res://docs/visual_review/stage_2-8_20261010/"
## [이름, 카메라 가운데] — 좌표 근거는 tools/build_하수도_2-8.gd (x = 칸×32+16 · y = 칸×32+224)
const 장면들 := [
	["시작_사다리", Vector2(2850, 3050)],      # 시작 바닥 · 가시 구덩이 · 격자 4 · 긴 격자 · 검정물_1
	["흰계단_몬스터", Vector2(2050, 2450)],    # 흰 계단 · 검정 몬스터
	["흰기둥밑_CP", Vector2(2150, 1800)],      # 작은 흰 발판 · 투명 발판 · CP · 흰물_2 · 흰물 웅덩이
	["흰ㄴ_양동이", Vector2(850, 1450)],       # 큰 흰 ㄴ · 양동이 · 박스 · 발판_1 · 흰물_1
	["점프대_가시", Vector2(900, 950)],        # 가시 발판 · 점프대 둘 · 흰 발판 43·46
	["사격몬스터_부서지는", Vector2(1950, 600)],  # 부서지는 발판 6 · 사격 몬스터 발판 · 흰물_2 출수
	["흰기둥_꼭대기", Vector2(3000, 500)],     # 흰 열쇠 조각 · 격자_기둥옆 · 위 격자 사다리 · 검정물_3
	["구조물_디딤바위", Vector2(4250, 2450)],  # 오른쪽 구조물 · 가시 바닥 · 디딤 바위
	["흰몬스터_CP", Vector2(3600, 1800)],      # 흰 몬스터 둘 · 검은 물 웅덩이 · CP · CP 위 바위 · 투명 지형
	["벨브", Vector2(4350, 1350)],             # 벨브_1 · 숨은 벨브_2(검정물_2 뒤) · 흰물_3
	["점프대_바위", Vector2(5250, 1200)],      # 바위 14·15 점프대 · 격자_점프대위
	["저장소", Vector2(4400, 750)],            # 저장소 · 관 · 흰물_4 · 검정물_3 · 격자_물
	["천장_도착", Vector2(5600, 450)],         # 천장 바위 · 도착 문 · 출구 통로
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
		player.global_position = 자리 + Vector2(-600, 2400)      # 화면 밖(몸이 장면을 가리지 않게)
		if camera != null:
			camera.global_position = 자리
			camera.reset_smoothing()
		for i in 90:
			await process_frame
		await RenderingServer.frame_post_draw
		var 길 := 폴더 + "view_%d_%s.png" % [n + 1, String(장면들[n][0])]
		root.get_texture().get_image().save_png(길)
		print("CAPTURE 2-8 ", 길)
	quit()
