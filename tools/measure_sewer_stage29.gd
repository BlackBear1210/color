extends SceneTree
## 창 모드에서만 GPU/프레임 비교용으로 실행한다. headless 수치는 그래픽 성능이 아니다.
## 2-9 B 격자 구간: --jump는 플레이어 물리와 점프 입력을 켠다. 기본은 플레이어만 고정한다.
var frame_ms: Array[float] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var stage = load("res://scenes/world_2_클로드/stage_2-9.tscn").instantiate()
	stage.set("시작_위치", Vector2(2272, 3700))
	# 같은 실행 조건에서 깊이 효과만 끄는 비교군이다.
	if OS.get_cmdline_user_args().has("--no-depth"):
		stage.get_node("하수도배경").set("표면_입체감", false)
		stage.get_node("하수도배경").set("지형_그림자", false)
	if OS.get_cmdline_user_args().has("--live-background"):
		stage.get_node("하수도배경").set_script(null)
	root.add_child(stage)
	await process_frame
	stage.set_physics_process(true)
	var player = stage.get_node("Player")
	player.set_physics_process(OS.get_cmdline_user_args().has("--jump"))
	player.set("player_color", 0)
	player.global_position = Vector2(2272, 3700)
	for i in 90:
		await process_frame
	var args := OS.get_cmdline_user_args()
	if args.has("--no-background"):
		stage.get_node("하수도배경").hide()
	if args.has("--no-terrain-process"):
		for terrain in stage.get_node("지형").get_children():
			terrain.set_process(false)
	var legacy := args.has("--legacy-trim")
	if legacy:
		legacy_gpu(stage.get_node("지형"))
	for i in 60:
		await process_frame
	var previous := Time.get_ticks_usec()
	var process_ms := 0.0
	var physics_ms := 0.0
	var draws := 0.0
	for i in 900:
		if OS.get_cmdline_user_args().has("--jump"):
			if i % 120 == 0:
				Input.action_press("jump")
			elif i % 120 == 20:
				Input.action_release("jump")
		await process_frame
		var now := Time.get_ticks_usec()
		frame_ms.append(float(now-previous)/1000.0)
		previous = now
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
		physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	frame_ms.sort()
	var report := {
		"mode": "legacy_gpu_only" if legacy else "cached_trim",
		"args": str(OS.get_cmdline_user_args()), "display": DisplayServer.get_name(),
		"window": str(root.size),
		"vsync": DisplayServer.window_get_vsync_mode(),
		"median_frame_ms": frame_ms[450], "p95_frame_ms": frame_ms[855], "p99_frame_ms": frame_ms[891], "max_frame_ms": frame_ms[899],
		"mean_process_ms": process_ms/900.0, "mean_physics_ms": physics_ms/900.0,
		"mean_draw_calls": draws/900.0,
		"note": "900 frames after warmup; world physics enabled; player physics enabled only with --jump; compare identical resolution/vsync."
	}
	root.get_texture().get_image().save_png("user://stage29_benchmark.png")
	print("SEWER_PERFORMANCE ", JSON.stringify(report))
	quit()

func legacy_gpu(folder: Node) -> void:
	# 본체의 예전 GPU 경계 검사만 되살린다. 디스크 파일/충돌/색 규칙은 수정하지 않는다.
	for terrain_node in folder.get_children():
		if not terrain_node.has_method("_접합_갱신") or terrain_node.get("땅지형") != true or terrain_node.get("석조선반") == true:
			continue
		var points: PackedVector2Array = terrain_node.get_point_array().get_tessellated_points()
		var edges: Array[Vector4] = []
		for i in points.size():
			var a := points[i]
			var b := points[(i+1)%points.size()]
			edges.append(Vector4(a.x,a.y,b.x,b.y))
		var bounds := Rect2(points[0], Vector2.ZERO)
		for point in points:
			bounds = bounds.expand(point)
		var covers: Array[Vector4] = []
		for other in folder.get_children():
			if other == terrain_node or not other.has_method("get_point_array"):
				continue
			var polygon := PackedVector2Array()
			for point in other.get_point_array().get_tessellated_points():
				polygon.append(terrain_node.to_local(other.to_global(point)))
			if polygon.size() < 3:
				continue
			var other_bounds := Rect2(polygon[0],Vector2.ZERO)
			for point in polygon:
				other_bounds = other_bounds.expand(point)
			if not bounds.grow(8.0).intersects(other_bounds,true):
				continue
			for i in polygon.size():
				var a := polygon[i]
				var b := polygon[(i+1)%polygon.size()]
				covers.append(Vector4(a.x,a.y,b.x,b.y))
		if edges.size()>128 or covers.size()>256:
			push_error("Legacy comparison exceeds original geometry limits")
			continue
		for part in terrain_node.get("_마감_노드"):
			part.visible = false
		var body: ShaderMaterial = terrain_node.shape_material.fill_mesh_material
		body.set_shader_parameter("cached_draw_mode",0)
		body.set_shader_parameter("ground_edges",edges)
		body.set_shader_parameter("ground_edge_count",edges.size())
		body.set_shader_parameter("ground_cover_edges",covers)
		body.set_shader_parameter("ground_cover_count",covers.size())
		body.set_shader_parameter("ground_top_enabled",terrain_node.get("윗면표시"))
		body.set_shader_parameter("ground_side_enabled",terrain_node.get("옆면마감"))
