extends SceneTree
## 사용자에게 엔진 실행을 명시적으로 요청받은 뒤 실행할 실제 색칠 회귀 검사.
## 저장 씬의 지형을 그대로 꺼내 검사하며 장치/카메라/자동 리스폰의 간섭을 배제한다.
const STAGE = preload("res://scenes/world_2_클로드/stage_2-2.tscn")
const CORE = preload("res://scripts/스마트월드/페인트_코어.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func frames(count: int = 8) -> void:
	for i in count:
		await physics_frame
		await process_frame

func run() -> void:
	var source = STAGE.instantiate()
	var world := Node2D.new()
	var core := Node.new()
	core.name = "페인트코어"
	core.set_script(CORE)
	core.add_to_group("페인트코어")
	world.add_child(core)
	var names := ["좌상_덩어리", "탑_왼벽", "좌하_채움", "탑_바닥"]
	var terrains: Array[Node2D] = []
	for name in names:
		var terrain := source.get_node("지형/" + name) as Node2D
		terrain.get_parent().remove_child(terrain)
		world.add_child(terrain)
		terrains.append(terrain)
	source.free()
	root.add_child(world)
	await frames(35)
	for terrain in terrains:
		var color: int = terrain.call("기본_아트색")
		var polygon: CollisionPolygon2D = terrain.get_node("StaticBody2D/CollisionPolygon2D")
		check(terrain.name + " 충돌/그룹", polygon.polygon.size() > 4 and terrain.is_in_group("칠할수있음"))
		# 모든 맞물림 변 바로 안쪽을 실제 위치 판정 API로 검사한다.
		var samples := PackedVector2Array()
		for i in polygon.polygon.size():
			var a := polygon.polygon[i]
			var b := polygon.polygon[(i + 1) % polygon.polygon.size()]
			var tangent := (b-a).normalized()
			var point := (a+b)*0.5 + Vector2(-tangent.y,tangent.x)*2.0
			if Geometry2D.is_point_in_polygon(point, polygon.polygon):
				samples.append(polygon.to_global(point))
		check(terrain.name + " 원래색 안전", not terrain.call("위치_반대색인가",color,samples))
		check(terrain.name + " 반대색 위험", terrain.call("위치_반대색인가",1-color,samples))
		# 색칠 중심을 매 경계 변 안쪽에 놓고 코어를 거쳐 칠하기/회수한다.
		for point in samples:
			check("발사 소모",core.call("발사_소모"))
			var result: String = core.call("명중_처리",terrain,1-color,point)
			check("맞물림 명중 허용",result == "progress" or result == "painted")
			await frames()
			check("맞물림 위치 색칠",terrain.call("위치색_로컬",terrain.to_local(point)) == 1-color)
			var contact := PackedVector2Array([point])
			check("칠한색 안전",not terrain.call("위치_반대색인가",1-color,contact))
			check("이전색 위험",terrain.call("위치_반대색인가",color,contact))
			check("회수 성공",core.call("수동_회수"))
			await frames()
			check("회수 원래색 복구",not terrain.call("위치_반대색인가",color,contact))
			check("탄약 복구",core.get("남은_탄약") == core.get("최대_탄약"))
		for material in terrain.get("_셰이더들"):
			check("흑백 텍스처 유지",material.get_shader_parameter("alt_tex") != null)
			# 새 마감 방식은 본체 0변, 좁은 마감 메시 1변으로 같은 색칠을 공유한다.
			check("캐시 마감 계산 제한",int(material.get_shader_parameter("ground_edge_count")) <= 1)
	world.free()
	print("STAGE22_JOINT_PAINT %d/%d PASS" % [checks-failures,checks])
	quit(1 if failures else 0)
