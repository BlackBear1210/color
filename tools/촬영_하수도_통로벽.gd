extends SceneTree
## [2026-10-08 Claude] 하수도 11 스테이지의 통로 둘레를 찍는다 — 구멍 메움 전(끔)/후(켬).
##   실행(창 모드): Godot --path . -s res://tools/촬영_하수도_통로벽.gd [-- 2-1 2-5 ...]
##   결과: tools/_진단/하수도_통로벽/<스테이지>_<통로>_<전|후>.png + 콘솔에 잰 구멍 크기
const OUT := "res://tools/_진단/하수도_통로벽/"
const 폴더 := "res://scenes/world_2_클로드/"


func _initialize() -> void:
	call_deferred("run")


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.get_texture().get_image().save_png(OUT + label + ".png")


func 통로들(n: Node) -> Array:
	var r: Array = []
	for c in n.find_children("*", "", true, false):
		if c.has_method("걸어나올_위치") and c.has_method("안쪽_위치"):
			r.append(c)
	return r


func run() -> void:
	root.size = Vector2i(1920, 1080)
	var 목록: Array = Array(OS.get_cmdline_user_args())
	if 목록.is_empty():
		for i in range(1, 12):
			목록.append("2-%d" % i)
	for 이름 in 목록:
		for 메움 in [false, true]:
			var 씬: Node = load(폴더 + "stage_%s.tscn" % 이름).instantiate()
			for t in 통로들(씬):
				t.set("통로_구멍_메움", 메움)
			root.add_child(씬)
			current_scene = 씬
			await wait(20)
			var p := 씬.get_node_or_null("Player") as CharacterBody2D
			for t in 통로들(씬):
				var d: float = t.call("방향")
				if 메움:
					print("%s %s: %s" % [이름, t.name, t.get("얇은벽_정보")])
				if p:
					p.global_position = (t as Node2D).global_position + Vector2(-d * 260.0, -4.0)
					p.velocity = Vector2.ZERO
				await wait(120)
				await shot("%s_%s_%s" % [이름, t.name, "후" if 메움 else "전"])
			씬.queue_free()
			await process_frame
	quit(0)
