extends SceneTree
## 실제 2-9에서 수심/색/호퍼 연결/잔물결을 검사한다. 촬영용 위치·물색은 실행 중에만 바꾼다.
var OUT := "res://docs/visual_review/water_stage5_20260929/"
var failures := 0

func _initialize() -> void:
	# 재질 수정 전후 촬영본을 덮어쓰지 않도록 출력 폴더를 선택할 수 있게 한다.
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		OUT = args[0].trim_suffix("/") + "/"
	Engine.max_fps = 60
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:
		failures += 1

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(OUT+label+".png") == OK, "capture "+label)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.content_scale_size = Vector2i(1920,1080)
	root.size = Vector2i(1920,1080)
	var stage: Node = load("res://scenes/world_2_클로드/stage_2-9.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	for i in range(25):
		await process_frame
	var player := get_first_node_in_group("player") as Node2D
	stage.set_physics_process(false)
	player.set_physics_process(false)
	player.set_process(false)
	player.set("velocity",Vector2.ZERO)
	for sprite in player.find_children("*","AnimatedSprite2D",true,false):
		sprite.set_process(false)
		sprite.set_physics_process(false)
		sprite.pause()
	for old in stage.find_children("*","Camera2D",true,false):
		old.set_process(false)
		old.set_physics_process(false)
		old.enabled = false
	var camera := Camera2D.new()
	camera.position = Vector2(1216,4320)
	camera.zoom = Vector2(0.8,0.8)
	stage.add_child(camera)
	camera.make_current()
	var pool: Node2D = stage.get_node("장치/A_낙하물받이")
	var size: Vector2 = pool.get("크기")
	_check(is_equal_approx(size.y,32.0),"pool depth stays 32")
	var visual: Node2D = pool.get("_white_visual")
	_check(visual.z_index > player.z_index,"water covers submerged legs")
	for tone in [0,1,2]:
		pool.set("색",tone)
		player.position = Vector2(1216,4250)
		await create_timer(0.1).timeout
		player.position = Vector2(1216,4320)
		await create_timer(0.15).timeout
		_check(pool.get("_잔물결").size()>0,"entry ripple tone %s" % tone)
		await _shot("pool_%s" % tone)
		player.position.x += 36
		await create_timer(0.15).timeout
		_check(pool.get("_잔물결").size()>=2,"walking ripple tone %s" % tone)
	await _shot("pool_walk")
	await create_timer(1.4).timeout
	_check(pool.get("_잔물결").is_empty(),"stationary ripples expire")
	pool.set("켜짐",false)
	await create_timer(0.1).timeout
	_check(pool.get("_잔물결").is_empty() and not visual.visible,"disabled pool clears effects")
	pool.set("켜짐",true)
	await create_timer(0.1).timeout
	_check(not pool.get("_잔물결").is_empty(),"reenabled pool reacts")
	# 실제 호퍼 입력을 껐다 켜서 혼합/출구 폭/접점/낙수 색을 확인한다.
	camera.position = Vector2(1536,3400)
	player.position = Vector2(2130,3712)
	var black: Node = stage.get_node("장치/C_검정공급")
	var white: Node = stage.get_node("장치/C_흰공급")
	var hopper: Node2D = stage.get_node("장치/C_혼합호퍼")
	var outlet: Node2D = stage.get_node("장치/D_호퍼출력")
	var inlet: Node = hopper.get_node("InletWaterSurface")
	for tone in [0,1,2]:
		black.set("켜짐",tone != 1)
		white.set("켜짐",tone != 0)
		await create_timer(0.5).timeout
		_check(inlet.get("_색")==tone and outlet.get("색")==tone,"inlet/outlet tone %s" % tone)
		_check(is_equal_approx(outlet.get("크기").x,64.0),"nozzle width 64")
		_check(outlet.global_position.distance_to(hopper.get_node("출구_포트").global_position)<0.1,"no outlet gap")
		var stream: Node2D = outlet.get("_white_visual")
		_check(stream.material.get_shader_parameter("colored_splash")==true,"tone-aware splash")
		await _shot("hopper_%s" % tone)
	print("WATER_STAGE5_FAILURES=",failures)
	quit(1 if failures else 0)
