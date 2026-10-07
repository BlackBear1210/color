extends SceneTree
## [2026-09-30 Claude] 2-9 E 구간의 기본지형 공중발판(E_연결발판)과 쇠사슬 승강기(E_승강발판)를 찍는다.
##   게임 파일은 안 바꾼다. 창 모드로 돌린다(그리기가 필요하다):
##   G --path . -s res://tools/촬영_2-9_공중발판_승강기.gd
## 결과: user://2-9_공중발판_승강기/*.png

const 씬 := "res://scenes/world_2_클로드/stage_2-9.tscn"
const 폴더 := "user://2-9_공중발판_승강기"


func _initialize() -> void:
	call_deferred("_실행")


func _찍기(이름: String) -> void:
	for i in 6:
		await process_frame
	var 파일 := "%s/%s.png" % [폴더, 이름]
	root.get_texture().get_image().save_png(파일)
	print("SHOT ", ProjectSettings.globalize_path(파일))


func _실행() -> void:
	DirAccess.make_dir_recursive_absolute(폴더)
	var 스테이지: Node = (load(씬) as PackedScene).instantiate()
	root.add_child(스테이지)
	for i in 20:
		await process_frame
	var 카메라: Camera2D = 스테이지.get("_카메라")
	카메라.set("target", null)
	var 플레이어 := 스테이지.get_node("Player") as Node2D
	for c in 스테이지.get_children():
		if c is CanvasLayer and c.owner == null:
			c.visible = false
	var 발판 := 스테이지.get_node("지형/E_연결발판") as Node2D

	# 1) 버튼 안 밟음: 공중발판이 아래(3968)에 있다.
	플레이어.global_position = Vector2(3300, 3690)
	카메라.zoom = Vector2.ONE
	카메라.global_position = Vector2(3650, 3800)
	카메라.reset_smoothing()
	for i in 60:
		await physics_frame
	print("발판 y(안 밟음) = ", 발판.global_position.y)
	await _찍기("1_공중발판_아래")

	# 2) 버튼 밟음: 256 올라와 기계실 윗면(3712)에 맞는다.
	플레이어.global_position = Vector2(3530, 3690)
	for i in 120:
		await physics_frame
	print("발판 y(밟음) = ", 발판.global_position.y)
	await _찍기("2_공중발판_위")

	# 3) 승강기 위·가운데·아래(왕복 5 초 → 위상 0 · 1.25 · 2.5 초). 천장(2624)까지 보이게 넓게.
	플레이어.global_position = Vector2(3300, 3690)
	var 승강기 := 스테이지.get_node("장치/E_승강발판") as Node2D
	카메라.zoom = Vector2(0.75, 0.75)
	카메라.global_position = Vector2(4064, 3170)
	카메라.reset_smoothing()
	for 판 in [["위", 0.0], ["가운데", 1.25], ["아래", 2.5]]:
		승강기.call("위상_초기화")
		승강기.set("_t", 판[1])
		await _찍기("3_승강기_" + 판[0])
		print("승강기 y(", 판[0], ") = ", 승강기.global_position.y, " 명중=", 승강기.call("명중", 1, Vector2.ZERO), " 현재색=", 승강기.call("현재색"))
	quit(0)
