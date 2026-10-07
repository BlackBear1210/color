extends SceneTree
## [2026-09-30 Claude] 스테이지 안의 투명발판(무색일때_통과)을 제자리에서 하나씩 찍는다. 게임 파일은 안 바꾼다.
##   G --path . -s res://tools/촬영_투명발판_스테이지.gd -- res://scenes/world_2_클로드/stage_2-5.tscn [...]
##   (창 모드 — 그리기가 필요하다)
## 결과: user://투명발판_스테이지/<스테이지>_<노드>.png


func _initialize() -> void:
	call_deferred("_실행")


func _실행() -> void:
	DirAccess.make_dir_recursive_absolute("user://투명발판_스테이지")
	for 경로 in OS.get_cmdline_user_args():
		var 스테이지: Node = (load(경로) as PackedScene).instantiate()
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
		for n in 스테이지.get_node("지형").get_children():
			if not n.get("무색일때_통과"):
				continue
			카메라.zoom = Vector2.ONE
			카메라.global_position = (n as Node2D).global_position
			카메라.reset_smoothing()
			for i in 12:
				await process_frame
			var 파일 := "user://투명발판_스테이지/%s_%s.png" % [String(경로).get_file().get_basename(), n.name]
			root.get_texture().get_image().save_png(파일)
			print("SHOT ", ProjectSettings.globalize_path(파일), " 밟기=", n.call("밟을_수_있나"))
		스테이지.queue_free()
		await process_frame
	quit(0)
