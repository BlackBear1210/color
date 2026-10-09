extends SceneTree
## 같은 스테이지/줌/해상도에서 적용 전후를 비교하기 위한 실제 엔진 캡처.
const SHOTS = [[4, Vector2(10536, 1650)]]
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var label := args[0] if args.size() > 0 else "detail"
	var dir := "res://docs/visual_review/water_reference_20261008/"
	DirAccess.make_dir_recursive_absolute(dir)
	for shot in SHOTS:
		var stage := (load("res://scenes/world_2_클로드/stage_2-%d.tscn" % shot[0]) as PackedScene).instantiate()
		root.add_child(stage)
		for i in 35:
			await process_frame
		var player := stage.get_node("Player") as Node2D
		player.process_mode = Node.PROCESS_MODE_DISABLED
		player.global_position = shot[1] + Vector2(-280, 80)
		var camera := stage.get("_카메라") as Camera2D
		camera.set("target", null)
		camera.zoom = Vector2.ONE
		camera.global_position = shot[1]
		camera.reset_smoothing()
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(dir + "stage_2-%d_%s.png" % [shot[0], label])
		print("CAPTURE ", shot[0], " ", label)
		stage.queue_free()
		for i in 5:
			await process_frame
	quit()
