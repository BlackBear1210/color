extends SceneTree
## [2026-09-30 Claude] 하수도 스테이지의 주철 배관(`하수도_주철배관.gd`)을 제자리에서 찍는다. 게임 파일은 안 바꾼다.
##   G --path . -s res://tools/촬영_하수도_주철배관.gd -- 1 3 4 [...]      (창 모드 · 스테이지 번호)
## 결과: user://하수도_주철배관/2-N_<배관>.png — 스테이지마다 앞의 3 개까지


func _initialize() -> void:
	call_deferred("_실행")


func _실행() -> void:
	DirAccess.make_dir_recursive_absolute("user://하수도_주철배관")
	var 관스크립트 := load("res://scripts/스마트월드/하수도_주철배관.gd")
	for 번호 in OS.get_cmdline_user_args():
		var 스테이지: Node = (load("res://scenes/world_2_클로드/stage_2-%s.tscn" % 번호) as PackedScene).instantiate()
		root.add_child(스테이지)
		for i in 20:
			await process_frame
		var 카메라: Camera2D = 스테이지.get("_카메라")
		카메라.set("target", null)
		for c in 스테이지.get_children():
			if c is CanvasLayer and c.owner == null:
				c.visible = false
		(스테이지.get_node("Player") as Node2D).process_mode = Node.PROCESS_MODE_DISABLED
		var 수 := 0
		for n in 스테이지.find_children("*", "Node2D", true, false):
			if n.get_script() != 관스크립트 or 수 >= 3:
				continue
			수 += 1
			var 점들: PackedVector2Array = n.get("점들")
			var 틀 := Rect2(n.to_global(점들[0]), Vector2.ZERO)
			for p in 점들:
				틀 = 틀.expand(n.to_global(p))
			틀 = 틀.grow(260)
			var 배 := clampf(minf(1920.0 / 틀.size.x, 1080.0 / 틀.size.y), 0.45, 1.0)
			카메라.zoom = Vector2(배, 배)
			카메라.global_position = 틀.get_center()
			카메라.reset_smoothing()
			for i in 10:
				await process_frame
			var 파일 := "user://하수도_주철배관/2-%s_%s.png" % [번호, n.name]
			root.get_texture().get_image().save_png(파일)
			print("SHOT ", ProjectSettings.globalize_path(파일))
		스테이지.queue_free()
		await process_frame
	quit(0)
