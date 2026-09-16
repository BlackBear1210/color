extends SceneTree
## 사용자 엔진 실행 허가 후 실행. 이 파일 작성만으로 테스트 완료라 보고하지 않는다.
const STAGE = preload("res://scenes/world_2_클로드/stage_2-1.tscn")
const CORE = preload("res://scripts/스마트월드/페인트_코어.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func frames(count: int) -> void:
	for i in count:
		await process_frame
		await physics_frame

func run() -> void:
	var source = STAGE.instantiate()
	var world := Node2D.new()
	var core := Node.new()
	core.set_script(CORE)
	core.add_to_group("페인트코어")
	world.add_child(core)
	var terrains: Array[Node2D] = []
	for name in ["A_바닥", "A_갤러리_슬래브", "A_샤프트_왼벽"]:
		var terrain_node := source.get_node("지형/" + name) as Node2D
		terrain_node.get_parent().remove_child(terrain_node)
		world.add_child(terrain_node)
		terrains.append(terrain_node)
	source.free()
	root.add_child(world)
	await frames(12)
	var stable: Array[int] = []
	for terrain_node in terrains:
		stable.append(int(terrain_node.get("마감_생성횟수")))
		var parts: Array = terrain_node.get("_마감_노드")
		check("노출 마감 생성", not parts.is_empty())
		var body_material: ShaderMaterial = terrain_node.get("shape_material").fill_mesh_material
		check("본체 픽셀 윤곽검사 제거", body_material.get_shader_parameter("cached_draw_mode") == 1 and body_material.get_shader_parameter("ground_edge_count") == 0)
		var collision: CollisionPolygon2D = terrain_node.get_node("StaticBody2D/CollisionPolygon2D")
		var original := collision.polygon.duplicate()
		for part in parts:
			check("장식 충돌 없음", part is MeshInstance2D and part.get_child_count() == 0)
			check("동일 물감 좌표", part.position == Vector2.ZERO and part.scale == Vector2.ONE)
			check("재로드 중복 방지", part.owner == null)
			check("물감 갱신 등록", terrain_node.get("_셰이더들").has(part.material))
			check("마감 한 변만 검사", part.material.get_shader_parameter("ground_edge_count") == 1 and part.material.get_shader_parameter("ground_cover_count") == 0)
		var triangles := Geometry2D.triangulate_polygon(original)
		check("실제 윤곽 삼각분할", triangles.size() >= 3)
		if triangles.size() < 3:
			continue
		var point := (original[triangles[0]] + original[triangles[1]] + original[triangles[2]]) / 3.0
		var hit := collision.to_global(point)
		var color: int = terrain_node.call("기본_아트색")
		core.call("발사_소모")
		var result: String = core.call("명중_처리", terrain_node, 1-color, hit)
		check("색칠 허용", result == "progress" or result == "painted")
		await frames(10)
		check("칠한 위치 판정", terrain_node.call("위치색_로컬", terrain_node.to_local(hit)) == 1-color)
		for part in parts:
			for uniform_name in ["seed_count", "seeds", "seed_r", "seed_a", "seed_c", "seed_d", "seed_v", "wet", "ghost_amount"]:
				check("본체/마감 물감 동기화 " + uniform_name, part.material.get_shader_parameter(uniform_name) == body_material.get_shader_parameter(uniform_name))
		check("회수 허용", core.call("수동_회수"))
		await frames(5)
		check("원래색 안전 복구", not terrain_node.call("위치_반대색인가", color, PackedVector2Array([hit])))
		check("충돌 원본 보존", collision.polygon == original)
	await frames(120)
	for i in terrains.size():
		check("정지 상태 재생성 0", int(terrains[i].get("마감_생성횟수")) == stable[i])
	var old_position := terrains[1].position
	terrain_move(terrains[1], old_position + Vector2(0, -64))
	await frames(5)
	check("배치 변경 본체 재생성", int(terrains[1].get("마감_생성횟수")) > stable[1])
	check("배치 변경 이웃 재생성", int(terrains[0].get("마감_생성횟수")) > stable[0])
	terrain_move(terrains[1], old_position)
	await frames(5)
	for terrain_node in terrains:
		var registered: Array = terrain_node.get("_셰이더들")
		var active_parts: Array = terrain_node.get("_마감_노드")
		check("재생성 재질 누적 없음", registered.size() == active_parts.size() + 1)
	world.free()
	print("CACHED_TRIM %d/%d PASS" % [checks-failures,checks])
	quit(1 if failures else 0)

func terrain_move(terrain_node: Node2D, at: Vector2) -> void:
	terrain_node.position = at
