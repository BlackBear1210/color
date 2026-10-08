extends SceneTree
## [2026-09-30 Claude] 기본지형 투명발판(v2) 시안을 실제 게임 화면으로 찍는다. 게임 파일은 안 바꾼다.
##   2-9 의 빈 벽(E 승강기 오른쪽) 앞에 임시로 놓고 찍는다:
##     윗줄 = 칠 전: 기존 선반 유령(비교) · 새 검정 · 새 흰색
##     아랫줄 = 칠 후: 새 검정을 검정으로 · 새 흰색을 흰색으로
##   G --path . -s res://tools/촬영_투명발판_기본지형.gd      (창 모드 — 그리기가 필요하다)
## 결과: user://투명발판_기본지형/*.png

const 씬 := "res://scenes/world_2_클로드/stage_2-9.tscn"
const 폴더 := "user://투명발판_기본지형"
const 새_검정 := "res://scenes/지형/하수도/하수도_투명발판_기본지형_검정.tscn"
const 새_흰색 := "res://scenes/지형/하수도/하수도_투명발판_기본지형_흰색.tscn"
const 옛_선반 := "res://scenes/지형/하수도/하수도_공중선반_검정.tscn"


func _initialize() -> void:
	call_deferred("_실행")


func _놓기(부모: Node, 경로: String, 자리: Vector2, 유령: bool) -> Node2D:
	var n := (load(경로) as PackedScene).instantiate() as Node2D
	n.position = 자리
	if 유령:
		n.set("시작상태", 0)
		n.set("무색일때_통과", true)
	부모.add_child(n)
	return n


func _실행() -> void:
	DirAccess.make_dir_recursive_absolute(폴더)
	var 스테이지: Node = (load(씬) as PackedScene).instantiate()
	root.add_child(스테이지)
	for i in 20:
		await process_frame
	var 카메라: Camera2D = 스테이지.get("_카메라")
	카메라.set("target", null)
	var 플레이어 := 스테이지.get_node("Player") as Node2D
	플레이어.global_position = Vector2(3300, 3690)   # 화면 밖(기계실)
	for c in 스테이지.get_children():
		if c is CanvasLayer and c.owner == null:
			c.visible = false
	var 지형 := 스테이지.get_node("지형")
	var 옛 := _놓기(지형, 옛_선반, Vector2(4420, 3200), true)
	var 검 := _놓기(지형, 새_검정, Vector2(4760, 3200), false)
	var 흰 := _놓기(지형, 새_흰색, Vector2(5100, 3200), false)
	var 검칠 := _놓기(지형, 새_검정, Vector2(4760, 3500), false)
	var 흰칠 := _놓기(지형, 새_흰색, Vector2(5100, 3500), false)
	for i in 10:
		await process_frame
	# 아랫줄은 필요한 발 수만큼 가운데를 맞혀 굳힌다(실제 총알과 같은 입구 `명중`).
	for 짝 in [[검칠, 0], [흰칠, 1]]:
		var n: Node2D = 짝[0]
		for k in int(n.call("필요횟수")):
			n.call("명중", 짝[1], n.global_position + Vector2(96, 20))
	# 윗줄 흰 발판은 1 발만 맞혀 "생겨나는 중" 을 보여준다.
	흰.call("명중", 1, 흰.global_position + Vector2(40, 20))
	for i in 90:
		await process_frame
	print("밟을 수 있나: 옛=", 옛.call("밟을_수_있나"), " 검=", 검.call("밟을_수_있나"), " 흰=", 흰.call("밟을_수_있나"),
		" 검칠=", 검칠.call("밟을_수_있나"), " 흰칠=", 흰칠.call("밟을_수_있나"))
	for 판 in [["x1_a", 1.0, 0], ["x1_b", 1.0, 40], ["x2", 2.0, 0]]:
		카메라.zoom = Vector2(판[1], 판[1])
		카메라.global_position = Vector2(4880, 3380) if 판[1] < 1.5 else Vector2(4950, 3260)
		카메라.reset_smoothing()
		for i in 6 + int(판[2]):
			await process_frame
		var 파일 := "%s/%s.png" % [폴더, 판[0]]
		root.get_texture().get_image().save_png(파일)
		print("SHOT ", ProjectSettings.globalize_path(파일))
	quit(0)
