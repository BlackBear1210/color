extends SceneTree
## [2026-09-30 Claude] 가이드 문서용 게임 화면 촬영 — HUD 없이, 카메라를 지정한 자리에 고정해 찍는다.
##   G --path . -s res://tools/촬영_가이드장면.gd -- <씬경로> <카메라x> <카메라y> <줌> <파일이름> [플레이어x 플레이어y]
## 결과: user://가이드장면/<파일이름>.png (창 모드 · 1920×1080 기준)
## 게임 파일은 바꾸지 않는다.

func _initialize() -> void:
	call_deferred("_실행")


func _실행() -> void:
	var 전체 := OS.get_cmdline_user_args()
	var a: Array = Array(전체).filter(func(s): return not String(s).begins_with("--"))
	var 씬: Node = (load(a[0]) as PackedScene).instantiate()
	# --앞지형끔 : 앞 지형 명도 처리(시안_명도조율 · 앞지형_깊이)를 끈 비교 사진. 재질이 ready 때 만들어지므로 트리에 넣기 전에 끈다.
	if 전체.has("--앞지형끔"):
		var 쌓기: Array[Node] = [씬]
		while not 쌓기.is_empty():
			var n: Node = 쌓기.pop_back()
			쌓기.append_array(n.get_children())
			if "앞지형_깊이" in n:
				n.set("앞지형_깊이", false)
				n.set("시안_명도조율", false)
	root.add_child(씬)
	for i in 30:
		await process_frame
	var 플레이어 := 씬.get_node_or_null("Player") as Node2D
	if 플레이어 and a.size() >= 7:
		플레이어.global_position = Vector2(float(a[5]), float(a[6]))
		for i in 30:   # 발이 바닥에 닿도록 물리를 조금 돌린 뒤 멈춘다
			await physics_frame
	if 플레이어:
		플레이어.process_mode = Node.PROCESS_MODE_DISABLED
	var 카메라: Camera2D = 씬.get("_카메라")
	카메라.set("target", null)
	카메라.zoom = Vector2(float(a[3]), float(a[3]))
	카메라.global_position = Vector2(float(a[1]), float(a[2]))
	카메라.reset_smoothing()
	# 게임 중에만 붙는 HUD(CanvasLayer)는 문서 사진에서 뺀다. 화면효과(비네트·입자)는 남긴다.
	for c in 씬.get_children():
		if c is CanvasLayer and c.owner == null:
			c.visible = false
	for i in 120:
		await process_frame
	DirAccess.make_dir_recursive_absolute("user://가이드장면")
	var 경로 := "user://가이드장면/%s.png" % a[4]
	root.get_texture().get_image().save_png(경로)
	print("SHOT ", ProjectSettings.globalize_path(경로))
	quit(0)
