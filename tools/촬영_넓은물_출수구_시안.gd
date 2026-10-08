extends SceneTree
## [2026-10-04 Claude] 넓은 물(관 40px 보다 훨씬 넓은 물)이 어디서 나오는지 — 출수구 시안을 제자리에서 찍는다.
##   도형님: "배관 입구는 작은데 물의 너비는 큰 경우" 가 어색하다 → 후보 몇 가지를 실제 스테이지 위에서 비교한다.
##   게임 파일(씬)은 안 바꾼다. 스테이지를 띄운 뒤 메모리에서만 원래 관을 숨기고 시안 부품을 얹는다.
##   G --path . -s res://tools/촬영_넓은물_출수구_시안.gd -- [시안이름 ...] [2-2_물1_576 ...]   (창 모드 · 비우면 전부)
## 결과: user://넓은물_출수구_시안/<장소>_<시안>.png

const 장소들 := [
	# [이름, 스테이지, 물 노드, 원래 관 노드, 화면 위로 더 볼 여유]
	["2-2_물1_576", "2-2", "장치/흰색물_1", "장치/관_밸브_물1", 320.0],
	["2-2_물4_192", "2-2", "장치/흰색물_4", "장치/관_흰색물_4", 160.0],
	["2-2_검2_224", "2-2", "장치/검정물_2", "장치/관_검정물_2", 160.0],
	["2-2_물3_96", "2-2", "장치/흰색물_3", "장치/관_흰색물_3", 200.0],
	["2-2_물2_64", "2-2", "장치/흰색물_2", "장치/관_흰색물_2", 200.0],
]


func _initialize() -> void:
	call_deferred("_실행")


func _실행() -> void:
	var 폴더 := "user://넓은물_출수구_시안"
	DirAccess.make_dir_recursive_absolute(폴더)
	var 고른 := Array(OS.get_cmdline_user_args())
	var 시안들: Array = ["현재"]
	var 출수구 = load("res://scripts/스마트월드/하수도_출수구_시안.gd")
	if 출수구 != null:
		시안들 += 출수구.시안_목록()
	# 인자: 시안 이름들 + (선택) "2-" 로 시작하는 자리 이름들 — 자리를 주면 그 자리만 찍는다
	var 고른자리: Array = 고른.filter(func(s): return s.begins_with("2-"))
	var 고른시안: Array = 고른.filter(func(s): return not s.begins_with("2-"))
	if not 고른시안.is_empty():
		시안들 = 시안들.filter(func(s): return 고른시안.has(s))
	var 열린: Dictionary = {}
	for 장 in 장소들:
		if not 고른자리.is_empty() and not 고른자리.has(장[0]):
			continue
		var 스테이지: Node = 열린.get(장[1])
		if 스테이지 == null:
			스테이지 = (load("res://scenes/world_2_클로드/stage_%s.tscn" % 장[1]) as PackedScene).instantiate()
			root.add_child(스테이지)
			for i in 20:
				await process_frame
			var 카메라0: Camera2D = 스테이지.get("_카메라")
			카메라0.set("target", null)
			for c in 스테이지.get_children():
				if c is CanvasLayer and c.owner == null:
					c.visible = false
			# 번갈이 물(흰↔검 3 초)이 찍는 도중 바뀌면 출수구와 물 색이 엇갈린다 → 멈춘다
			for n in 스테이지.find_children("*", "Node", true, false):
				var sc: Script = n.get_script()
				if sc != null and sc.resource_path.get_file().begins_with("번갈이"):
					n.process_mode = Node.PROCESS_MODE_DISABLED
			(스테이지.get_node("Player") as Node2D).visible = false
			(스테이지.get_node("Player") as Node2D).process_mode = Node.PROCESS_MODE_DISABLED
			열린[장[1]] = 스테이지
		var 카메라: Camera2D = 스테이지.get("_카메라")
		var 물 := 스테이지.get_node(장[2]) as Node2D
		var 관 := 스테이지.get_node_or_null(장[3]) as Node2D
		물.set("켜짐", true)
		# 같은 자리에 겹친 짝 물(번갈이)은 끈다
		for 짝 in 물.get_parent().get_children():
			if 짝 != 물 and 짝 is Node2D and "크기" in 짝 and (짝 as Node2D).global_position.distance_to(물.global_position) < 1.0:
				짝.set("켜짐", false)
		var 크기: Vector2 = 물.get("크기")
		# 물 윗부분 + 위로 여유만 본다(출수구가 주인공)
		var 틀 := Rect2(물.global_position + Vector2(-크기.x * 0.5, -장[4]), Vector2(크기.x, 장[4] + minf(크기.y, 360.0)))
		틀 = 틀.grow_individual(maxf(260.0, 크기.x * 0.35), 40, maxf(260.0, 크기.x * 0.35), 40)
		var 배 := clampf(minf(1920.0 / 틀.size.x, 1080.0 / 틀.size.y), 0.5, 2.0)
		카메라.zoom = Vector2(배, 배)
		카메라.global_position = 틀.get_center()
		카메라.reset_smoothing()
		for 시안 in 시안들:
			var 얹은: Node2D = null
			if 시안 == "현재":
				if 관: 관.visible = true
			else:
				if 관: 관.visible = false
				얹은 = 출수구.new()
				얹은.name = "시안_출수구"
				물.get_parent().add_child(얹은)
				if not 얹은.call("물에_맞추기", 물, 시안, 관):
					print("SKIP %s %s — 이 자리에 맞지 않는 시안" % [장[0], 시안])
					얹은.queue_free()
					if 관: 관.visible = true
					continue
			for i in 30:
				await process_frame
			var 파일 := "%s/%s_%s.png" % [폴더, 장[0], 시안]
			root.get_texture().get_image().save_png(파일)
			print("SHOT ", ProjectSettings.globalize_path(파일))
			if 얹은:
				얹은.queue_free()
			if 관: 관.visible = true
			await process_frame
	quit(0)
