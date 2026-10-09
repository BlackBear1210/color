extends SceneTree
## 2-5의 두 물받이와 바닥을 같은 줌과 해상도로 전후 촬영한다.
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var label := args[0] if args.size() > 0 else "after"
	var dir := "res://docs/visual_review/water_reference_20261008/"
	var path := "res://scenes/world_2_클로드/stage_2-5.tscn"
	if label == "before":
		path = dir + "stage_2-5_original.tscn"
	var stage := (load(path) as PackedScene).instantiate()
	root.add_child(stage)
	for i in 35:
		await process_frame
	var player := stage.get_node("Player") as Node2D
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var camera := stage.get("_카메라") as Camera2D
	camera.set("target", null)
	camera.zoom = Vector2.ONE
	var views := [Vector2(1824, 640), Vector2(1824,1100), Vector2(2608,2350), Vector2(2608,2830)]
	for n in views.size():
		camera.global_position = views[n]
		player.global_position = views[n] + Vector2(-280,80)
		camera.reset_smoothing()
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(dir + "stage_2-5_view_%d_%s.png" % [n+1,label])
		print("CAPTURE 2-5 view ",n+1," ",label)
	quit()
