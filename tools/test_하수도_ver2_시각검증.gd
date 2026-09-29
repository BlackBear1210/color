extends SceneTree
## 허용받은 경우에만 창모드로 실행: Godot --path . -s res://tools/test_하수도_ver2_시각검증.gd -- <stage경로> <출력폴더>
## 실제 게임 프레임과 효과의 수량/수명을 저장한다. 생성 이미지나 헤드리스 더미 렌더는 검증으로 쓰지 않는다.
var _scene: Node

func _initialize() -> void:
	Engine.max_fps = 60
	call_deferred("_검사")

func _저장(path: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	return not image.is_empty() and image.save_png(path) == OK

func _검사() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("stage경로와 출력폴더가 필요합니다")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(args[1])
	var packed := load(args[0]) as PackedScene
	if packed == null:
		quit(1)
		return
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1920, 1080)
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	for i in range(100):
		await process_frame
	var fx := _scene.get_node_or_null("하수도화면효과/효과")
	if fx == null or fx.get_script() == null:
		push_error("ver.2 효과 노드/스크립트 누락")
		quit(1)
		return
	var ok := await _저장(args[1].path_join("gameplay.png"))
	# 실제 입수와 별도로 효과 단위 호출을 검사한다. 실제 진입 검증과 구분해 기록한다.
	fx.call("_입수", 1)
	var drops: Array = fx.get("_물방울")
	ok = ok and drops.size() >= 3 and drops.size() <= 5
	for drop in drops:
		ok = ok and float(drop["life"]) >= 0.3 and float(drop["life"]) <= 0.5
	await create_timer(0.12).timeout
	ok = await _저장(args[1].path_join("splash_unit_012.png")) and ok
	await create_timer(0.5).timeout
	var remaining: Array = fx.get("_물방울")
	ok = ok and remaining.is_empty()
	ok = await _저장(args[1].path_join("splash_unit_clear.png")) and ok
	var report := FileAccess.open(args[1].path_join("report.txt"), FileAccess.WRITE)
	report.store_string("stage=%s\nsize=%s\nsplash_unit=%s\nActual entry, death, HUD and visual similarity require review of captures and gameplay.\n" % [args[0], root.size, ok])
	print("VER2_CAPTURE ", "PASS" if ok else "FAIL", " ", args[1])
	quit(0 if ok else 1)
