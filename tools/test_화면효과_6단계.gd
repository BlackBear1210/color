extends SceneTree
## 실제 2-9의 플레이어를 통제해 입수 경계를 통과시킨다. 효과 함수를 직접 호출해 입수를 대신하지 않는다.
const OUT := "res://docs/visual_review/ver2_stage6/"
var failures := 0
var player: Node2D
var fx: Control

func _initialize() -> void:
	Engine.max_fps = 60
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT + label + ".png") == OK, label)

func move_to(pos: Vector2) -> void:
	player.global_position = pos
	await physics_frame
	await physics_frame

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.content_scale_size = Vector2i(1920,1080)
	root.size = Vector2i(1920,1080)
	var stage: Node = load("res://scenes/world_2_클로드/stage_2-9.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	for i in range(25):
		await process_frame
	player = get_first_node_in_group("player") as Node2D
	fx = stage.get_node("하수도화면효과/효과")
	stage.set_physics_process(false)
	player.set_physics_process(false)
	player.set_process(false)
	player.set("velocity", Vector2.ZERO)
	for old in stage.find_children("*", "Camera2D", true, false):
		old.set_process(false)
		old.set_physics_process(false)
		old.enabled = false
	var camera := Camera2D.new()
	camera.position = Vector2(1216,4320)
	camera.zoom = Vector2(0.8,0.8)
	stage.add_child(camera)
	camera.make_current()
	var pool: Node2D = stage.get_node("장치/A_낙하물받이")
	# 입자 수는 재현 가능하게 고정하되 실제 시간 경과와 정상 그리기를 유지한다.
	fx.set("_난수", RandomNumberGenerator.new())
	fx.get("_난수").seed = 20260929
	await move_to(Vector2(1216,4250))
	await create_timer(0.6).timeout
	fx.visible = false
	await shot("effects_off")
	fx.visible = true
	await shot("effects_on")
	for tone in [0,1,2]:
		pool.set("색",tone)
		await move_to(Vector2(1216,4250))
		await create_timer(0.6).timeout
		await move_to(Vector2(1216,4310))
		var drops: Array = fx.get("_물방울")
		check(drops.size() >= 3 and drops.size() <= 5, "entry count tone %s" % tone)
		var valid := not drops.is_empty()
		for drop in drops:
			valid = valid and drop.tone == tone and drop.life >= 0.3 and drop.life <= 0.5 and drop.radius <= 4.0
		check(valid, "tone lifetime size %s" % tone)
		await create_timer(0.08).timeout
		await shot("entry_%s" % tone)
		await move_to(Vector2(1250,4310))
		await create_timer(0.55).timeout
		check(fx.get("_물방울").is_empty(), "walking does not retrigger %s" % tone)
	await shot("expired")
	# 수평 경계 진입은 기존 코드의 하강 조건으로 놓치던 경우다.
	await move_to(Vector2(500,4310))
	await create_timer(0.6).timeout
	await move_to(Vector2(520,4310))
	check(not fx.get("_물방울").is_empty(), "horizontal entry")
	await create_timer(0.08).timeout
	await shot("horizontal_entry")
	await move_to(Vector2(500,4310))
	await create_timer(0.6).timeout
	await move_to(Vector2(520,4310))
	check(not fx.get("_물방울").is_empty(), "reentry")
	# 실제 월드 리스폰 경로를 호출하되 안전점을 같은 물 안으로 지정해 거리 추정에 의존하지 않는지 본다.
	stage.set("안전지점_자동저장",true)
	stage.set("_안전점",player.global_position)
	stage.call("_리스폰")
	check(fx.get("_물방울").is_empty(), "actual respawn clears immediately")
	await physics_frame
	await physics_frame
	check(fx.get("_물방울").is_empty(), "respawn in water does not splash")
	await shot("respawn_clear")
	await move_to(Vector2(500,4310))
	await move_to(Vector2(520,4310))
	check(not fx.get("_물방울").is_empty(), "entry after respawn")
	await move_to(Vector2(1216,4310))
	check(fx.get("_물방울").is_empty(), "teleport clears")
	await move_to(Vector2(1216,4250))
	await create_timer(0.6).timeout
	fx.set("입수_물방울", false)
	await move_to(Vector2(1216,4310))
	check(fx.get("_물방울").is_empty(), "disabled effect")
	check(fx.get_parent().layer == 5, "overlay below HUD layer 100")
	check(fx.mouse_filter == Control.MOUSE_FILTER_IGNORE, "no input interception")
	print("STAGE6_FAILURES=",failures)
	quit(0 if failures == 0 else 1)

