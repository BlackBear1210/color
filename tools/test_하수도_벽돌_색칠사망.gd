extends SceneTree
## 신규 SS2D 실물 씬으로 페인트코어, 색 복구, 위치 판정과 월드의 실제 접촉 판정을 확인한다.
const WORLD = preload("res://scripts/스마트월드/월드.gd")
const CORE = preload("res://scripts/스마트월드/페인트_코어.gd")
const PLAYER = preload("res://scenes/player/Player.tscn")
const BULLET = preload("res://scripts/스마트월드/총알.gd")
const DIR = "res://scenes/테스트/하수도_지형_v01/"
var failures := 0
var checks := 0

func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func _initialize() -> void:
	call_deferred("run")

func frames(count: int = 3) -> void:
	for i in count:
		await physics_frame
		await process_frame

func dead(world: Node2D, player: Node2D, at: Vector2, color: int) -> bool:
	player.global_position = at
	player.set("player_color", color)
	player.set("velocity", Vector2.ZERO)
	await frames()
	return bool(world.call("_사망_판정"))

func run() -> void:
	for name in ["공중_얇은발판", "공중_두꺼운발판", "공중_경사발판"]:
		for color in [0, 1]:
			await inspect(name, color)
	print("SEWER_RESULT %d/%d PASS" % [checks - failures, checks])
	quit(1 if failures else 0)

func inspect(name: String, color: int) -> void:
	var world := Node2D.new()
	world.set_script(WORLD)
	world.set("안전지점_자동저장", false)
	world.set("시작_위치", Vector2(-1000, -1000))
	world.set("치명_낙하거리", 0.0)
	var core := Node.new()
	core.name = "페인트코어"
	core.set_script(CORE)
	core.add_to_group("페인트코어")
	world.add_child(core)
	var player = PLAYER.instantiate()
	player.name = "Player"
	world.add_child(player)
	var filename := name + ("_흰색" if color == 1 else "")
	var terrain = load(DIR + filename + ".tscn").instantiate()
	var sibling = load(DIR + filename + ".tscn").instantiate()
	sibling.position = Vector2(2000, 0)
	world.add_child(terrain)
	world.add_child(sibling)
	root.add_child(world)
	# 리스폰과 자동 이동이 검사 좌표를 바꾸지 않게 하되 물리 질의는 실제 월드를 사용한다.
	world.set_physics_process(false)
	player.set_physics_process(false)
	await frames(5)
	var top := Vector2(150, 40 if name.contains("경사") else 0)
	var inside := top + Vector2(0, 12)
	var label := filename + " "
	print("START_STATE ", terrain.get("시작상태"), " / ", terrain.call("현재색"))
	check(label + "게임 지형 등록", terrain.is_in_group("칠할수있음") and terrain.is_in_group("스마트지형"))
	check(label + "시작 색", terrain.call("현재색") == color)
	check(label + "충돌 유지", terrain.get_node("StaticBody2D").collision_layer == 1)
	check(label + "같은 색 접촉 안전", not await dead(world, player, top + Vector2(0, -1), color))
	check(label + "다른 색 접촉 사망", await dead(world, player, top + Vector2(0, -1), 1-color))
	check(label + "공중 비접촉 안전", not await dead(world, player, top + Vector2(0, -200), 1-color))
	check(label + "옆벽 반대색 사망", await dead(world, player, Vector2(-4, 110 if name.contains("경사") else 40), 1-color))
	# 머리 높이는 실제 플레이어 충돌 다각형에서 읽어 얇은 발판과 경사 하단 모두 검사한다.
	var body: CollisionPolygon2D = player.get_node("CollisionPolygon2D")
	var head_y := 0.0
	for point in body.polygon:
		head_y = minf(head_y, (body.to_global(point) - player.global_position).y)
	var bottom := 110.0 if name.contains("경사") else (120.0 if name.contains("두꺼운") else 48.0)
	var under := Vector2(150, bottom - head_y - 3.0)
	check(label + "아래쪽 같은 색 안전", not await dead(world, player, under, color))
	check(label + "아래쪽 반대색 사망", await dead(world, player, under, 1-color))
	# 실제 총알이 충돌한 콜라이더에서 부모 지형까지 연결되는지 물리 레이로 확인한다.
	var query := PhysicsRayQueryParameters2D.create(top + Vector2(0, -100), inside, 1)
	query.exclude = [player.get_rid()]
	var hit := world.get_world_2d().direct_space_state.intersect_ray(query)
	check(label + "발사 경로의 지형 충돌", not hit.is_empty() and hit.collider.get_parent() == terrain)
	var result := ""
	for i in int(terrain.call("필요횟수")):
		core.call("발사_소모")
		result = str(core.call("명중_처리", terrain, 1-color, inside))
	await frames(8)
	check(label + "코어 명중으로 반대색 전환", result == "painted" and terrain.call("현재색") == 1-color)
	check(label + "칠한 색 접촉 안전", not await dead(world, player, top + Vector2(0, -1), 1-color))
	check(label + "이전 색 접촉 사망", await dead(world, player, top + Vector2(0, -1), color))
	check(label + "다른 인스턴스 색 보존", sibling.call("현재색") == color)
	var materials_ok := true
	for mesh in terrain.get("_meshes"):
		if mesh.texture != null:
			var material = mesh.material
			materials_ok = materials_ok and material is ShaderMaterial
			if material is ShaderMaterial:
				materials_ok = materials_ok and material.get_shader_parameter("alt_tex") != null and material.get_shader_parameter("alt_invert") != true
	check(label + "내부와 모서리 흑백 셰이더 연결", materials_ok)
	check(label + "회수 성공", bool(core.call("수동_회수")))
	await frames()
	check(label + "회수 후 원래 색", terrain.call("현재색") == color)
	# 코어 직접 호출과 구분해 실제 투사체가 날아가 충돌 부모를 찾는 경로도 검증한다.
	player.global_position = Vector2(-1000, -1000)
	for i in int(terrain.call("필요횟수")):
		core.call("발사_소모")
		var bullet := Area2D.new()
		bullet.set_script(BULLET)
		world.add_child(bullet)
		bullet.call("시작", top + Vector2(0,-150), Vector2.DOWN, 700.0, 1-color, core)
		await frames(30)
	check(label + "실제 투사체 비행 명중 색 전환", terrain.call("현재색") == 1-color)
	var reclaimed := bool(core.call("수동_회수"))
	await frames()
	check(label + "실제 투사체 페인트 회수 복구", reclaimed and terrain.call("현재색") == color)
	# 긴 지형처럼 부분칠만 설정한 경우에는 한 점과 멀리 떨어진 점의 판정을 구분한다.
	terrain.set("칠하기_방식", 1)
	terrain.call("명중", 1-color, Vector2(25, 95 if name.contains("경사") else 12))
	await frames(8)
	check(label + "부분칠 지점 반대색", terrain.call("위치색_로컬", Vector2(25, 95 if name.contains("경사") else 12)) == 1-color)
	var outside := PackedVector2Array([terrain.to_global(Vector2(280, 25))])
	check(label + "부분칠 밖 원래색 안전", not bool(terrain.call("위치_반대색인가", color, outside)))
	check(label + "부분칠 밖 반대색 위험", bool(terrain.call("위치_반대색인가", 1-color, outside)))
	world.free()
	await frames()
