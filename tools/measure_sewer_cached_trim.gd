extends SceneTree
## 창 모드에서만 GPU/프레임 비교용으로 실행한다. headless 수치는 그래픽 성능이 아니다.
## --legacy-trim은 같은 위치에서 구형 픽셀 마감 계산만 복원하는 GPU 대조군이다.
var frame_ms: Array[float] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var stage = load("res://scenes/world_2_클로드/stage_2-1.tscn").instantiate()
	stage.set("시작_위치", Vector2(2920, 1024))
	root.add_child(stage)
	await process_frame
	stage.set_physics_process(false)
	var player = stage.get_node("Player")
	player.set_physics_process(false)
	player.set("player_color", 0)
	player.global_position = Vector2(2920, 1024)
	for i in 90:
		await process_frame
	var legacy := OS.get_cmdline_user_args().has("--legacy-trim")
	if legacy:
		legacy_gpu(stage.get_node("지형"))
	for i in 60:
		await process_frame
	var previous := Time.get_ticks_usec()
	var process_ms := 0.0
	var physics_ms := 0.0
	var draws := 0.0
	for i in 240:
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
		"display": DisplayServer.get_name(),
		"window": str(root.size),
		"vsync": DisplayServer.window_get_vsync_mode(),
		"median_frame_ms": frame_ms[120], "p95_frame_ms": frame_ms[228],
		"mean_process_ms": process_ms/240.0, "mean_physics_ms": physics_ms/240.0,
		"mean_draw_calls": draws/240.0,
		"note": "CPU old polling is not restored in legacy mode; compare identical resolution/vsync."
	}
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
