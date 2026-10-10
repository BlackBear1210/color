extends SceneTree
## 도안 수가 아니라 실제 입력·충돌로 초반 거미 제거, 마루 회복, 흰 선반과 색 도약대를 검증한다.
## 저장 데이터를 보호하고 사망 판정은 직접 읽어 한 실패의 리스폰이 다음 검사에 섞이지 않게 한다.
const FOLDER := "res://scenes/쳅터1/스테이지/"
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for frame in count:
		await physics_frame


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1


func stage(name: String) -> Node2D:
	var scene := (load(FOLDER + name + ".tscn") as PackedScene).instantiate() as Node2D
	root.add_child(scene)
	current_scene = scene
	scene.set_physics_process(false)
	scene.set("_무적", 0.0)
	await frames(20)
	return scene


func run() -> void:
	게임진행.기록_허용 = 0
	for name in ["쳅터1_01_방_시작방", "쳅터1_02_복도_A", "쳅터1_03_방_서재", "쳅터1_16_복도_썩은마루",
			"쳅터1_04_복도_B", "쳅터1_05_방_침실", "쳅터1_06_복도_C", "쳅터1_07_방_수납실", "쳅터1_08_복도_D", "쳅터1_09_계단_중앙"]:
		var early := await stage(name)
		var spiders := get_nodes_in_group("그을음").filter(func(node): return early.is_ancestor_of(node))
		check(spiders.is_empty(), name + " 초반 거미 없음")
		early.queue_free()
		await process_frame
	var scene := await stage("쳅터1_01_방_시작방")
	var player := scene.get_node("Player") as CharacterBody2D
	player.set("player_color", ColorDefs.BLACK)
	player.global_position = Vector2(71.5 * 32.0, 49.0 * 32.0 - 2.0)
	player.velocity = Vector2.ZERO
	await frames(150)
	check(player.is_on_floor() and absf(player.global_position.y - 52.0 * 32.0) < 6.0,
		"첫 마루가 부서지면 3칸 아래 회복 바닥에 착지")
	check(not bool(scene.call("_사망_판정")), "첫 마루 낙하에 가시·색 사망 없음")
	Input.action_press("jump")
	Input.action_press("move_right")
	await frames(24)
	Input.action_release("jump")
	Input.action_release("move_right")
	await frames(40)
	check(player.global_position.x > 73.0 * 32.0 and player.global_position.y < 50.0 * 32.0,
		"실제 점프 입력으로 회복 구덩이에서 탈출 @%s" % player.global_position)
	scene.queue_free()
	await process_frame
	scene = await stage("쳅터1_09_계단_중앙")
	player = scene.get_node("Player") as CharacterBody2D
	player.global_position = Vector2(45.0 * 32.0, 58.0 * 32.0 - 2.0)
	player.velocity = Vector2.ZERO
	player.set("player_color", ColorDefs.WHITE)
	await frames(8)
	check(player.is_on_floor() and not bool(scene.call("_사망_판정")), "새 층계참 흰 선반에 흰 몸 착지")
	player.set("player_color", ColorDefs.BLACK)
	await frames(2)
	check(bool(scene.call("_사망_판정")), "층계참 흰 선반은 검정 몸에 위험해 색 전환을 유도")
	scene.queue_free()
	await process_frame
	scene = await stage("쳅터1_13_복도_G")
	player = scene.get_node("Player") as CharacterBody2D
	# 색 도약대의 판은 중립이다. 검정 몸으로 기다렸다가 흰색으로 바꾸면 튀어야 한다.
	for spider in get_nodes_in_group("그을음"):
		spider.queue_free()
	await process_frame
	player.global_position = Vector2(112.0 * 32.0, 30.0 * 32.0 - 2.0)
	player.velocity = Vector2.ZERO
	player.set("player_color", ColorDefs.BLACK)
	await frames(10)
	check(player.is_on_floor() and player.velocity.y >= 0.0, "검정 몸으로 색 도약대 위에서 기다릴 수 있음")
	player.set("player_color", ColorDefs.WHITE)
	await frames(3)
	check(player.velocity.y < -400.0, "흰색 전환이 도약대를 작동시킴")
	player.set("player_color", ColorDefs.BLACK)
	scene.queue_free()
	await process_frame
	scene = await stage("쳅터1_11_거실")
	var first_spider: Node = get_nodes_in_group("그을음").filter(func(node): return scene.is_ancestor_of(node))[0]
	check(is_equal_approx(float(first_spider.get("덮침_예고")), 0.8) and
		is_equal_approx(float(first_spider.get("영역_칸")), 6.0), "첫 거미는 0.8초 예고·6칸 영역으로 시작")
	var candles := scene.find_children("촛불*", "", true, false)
	check(not candles.is_empty() and bool(candles[-1].get("켜짐")) and bool(candles[-1].get("영원")),
		"첫 거미 앞 촛불 피난처는 꺼지지 않음")
	scene.queue_free()
	await process_frame
	print("학습흐름 실패 %d" % failures)
	quit(0 if failures == 0 else 1)
