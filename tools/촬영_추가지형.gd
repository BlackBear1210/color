extends SceneTree
## [2026-10-09 Claude] 추가지형(손본 씬에 끼운 흰·검정 둔덕) 실제 화면 확인용 촬영 — 창 모드
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1920, 1080)
	for 쌍 in [["쳅터1_10_복도_E", Vector2(20, 26)], ["쳅터1_13_복도_G", Vector2(22, 26)], ["쳅터1_03_방_서재", Vector2(70, 50)], ["쳅터1_11_거실", Vector2(192, 56)]]:
		var s = (load("res://scenes/쳅터1/스테이지/%s.tscn" % 쌍[0]) as PackedScene).instantiate()
		root.add_child(s)
		current_scene = s
		for i in 20: await physics_frame
		var p = s.get_node("Player")
		p.global_position = 쌍[1] * 32.0
		p.set_physics_process(false)
		for i in 40: await physics_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/_진단/추가지형/"))
		root.get_texture().get_image().save_png("res://tools/_진단/추가지형/%s.png" % 쌍[0])
		s.queue_free()
		await process_frame
	quit()
