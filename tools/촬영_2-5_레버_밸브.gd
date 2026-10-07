extends SceneTree
## [2026-09-30 Claude] 2-5 의 레버·밸브(장치/L*) 자리를 하나씩 찍는다. 게임 파일은 안 바꾼다.
##   G --path . -s res://tools/촬영_2-5_레버_밸브.gd      (창 모드)
## 결과: user://2-5_레버_밸브/<노드>.png


func _initialize() -> void:
	call_deferred("_실행")


func _실행() -> void:
	DirAccess.make_dir_recursive_absolute("user://2-5_레버_밸브")
	var 스테이지: Node = (load("res://scenes/world_2_클로드/stage_2-5.tscn") as PackedScene).instantiate()
	root.add_child(스테이지)
	for i in 20:
		await process_frame
	var 카메라: Camera2D = 스테이지.get("_카메라")
	카메라.set("target", null)
	for c in 스테이지.get_children():
		if c is CanvasLayer and c.owner == null:
			c.visible = false
	var 플레이어 := 스테이지.get_node("Player") as Node2D
	플레이어.process_mode = Node.PROCESS_MODE_DISABLED
	for n in 스테이지.get_node("장치").get_children():
		if not n.has_method("배관_포트"):
			continue
		카메라.zoom = Vector2.ONE
		카메라.global_position = (n as Node2D).global_position + Vector2(260, -220)
		카메라.reset_smoothing()
		for i in 10:
			await process_frame
		var 파일 := "user://2-5_레버_밸브/%s.png" % n.name
		root.get_texture().get_image().save_png(파일)
		print("SHOT ", ProjectSettings.globalize_path(파일), " 종류=", n.get("종류"), " 배관연결=", n.get("배관_연결됨"))
	quit(0)
