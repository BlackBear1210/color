extends SceneTree
## ============================================================================
## [2026-10-10 Claude] 거미방 C 풀이 촬영 — 거미를 깨워 물러나면 영역 끝에서 노려보고, 반딧불 빛이 켜지면 탄다
## 실행(창 모드): Godot_console --fixed-fps 60 --path . -s res://tools/촬영_거미방_풀이.gd → tools/_진단/거미방_풀이/
## ⚠ 진행 파일을 쓰지 않는다(기록_허용 = 0).
## ============================================================================
const OUT := "res://tools/_진단/거미방_풀이/"
const C := 32.0


func _initialize() -> void:
	call_deferred("run")


func 찍기(이름: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + 이름)
	print("저장 ", 이름)


func run() -> void:
	게임진행.기록_허용 = 0
	root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var s := (load("res://scenes/쳅터1/스테이지/쳅터1_19_거미방.tscn") as PackedScene).instantiate()
	root.add_child(s)
	current_scene = s
	var p := s.get_node("Player") as CharacterBody2D
	var 거미 := s.get_node("추가기믹/거미01") as Node2D
	for i in 20:
		await physics_frame
	p.global_position = Vector2(152 * C, 55 * C - 1)
	p.velocity = Vector2.ZERO
	p.set("player_color", ColorDefs.WHITE)
	for i in 40:
		await physics_frame
	await 찍기("01_줄너머_거미깨어남.png")
	p.set("자동_걷기", -1.0)
	for i in 240:
		await physics_frame
		if p.global_position.x <= 140 * C:
			break
	p.set("자동_걷기", 0.0)
	for i in 90:
		await physics_frame
	await 찍기("02_영역끝_대치.png")
	for i in 60 * 45:
		await physics_frame
		if int(거미.get("지금")) == 6:          # 탐
			for k in 12:
				await physics_frame
			await 찍기("03_반딧불빛에_거미탐.png")
			break
	for i in 90:
		await physics_frame
	await 찍기("04_줄삭음_빛받이.png")
	quit()
