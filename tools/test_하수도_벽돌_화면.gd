extends SceneTree
## 실제 렌더러로 색칠 전후·근접 반사·카메라 네 모서리의 배경 범위를 캡처한다.
var scene: Node2D
var camera: Camera2D
var player: Node2D
var failure := 0

func _initialize() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://.godot/sewer_" + name + ".png")
	print("SHOT ", name)

func run() -> void:
	scene = load("res://scenes/테스트/하수도_지형_v01/색칠_사망_플레이시험.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.set_physics_process(false)
	player = scene.get_node("Player")
	player.set_physics_process(false)
	var old_camera = scene.get_node("카메라")
	old_camera.set_process(false)
	old_camera.set_physics_process(false)
	old_camera.enabled = false
	camera = Camera2D.new()
	scene.add_child(camera)
	camera.position = Vector2(950,520)
	camera.zoom = Vector2(0.7,0.7)
	camera.make_current()
	player.position = Vector2(280,458)
	camera.zoom = Vector2.ONE
	await shot("zoom_1")
	camera.zoom = Vector2(0.7,0.7)
	await shot("overview")
	# 반사 비교 캡처에서 HUD나 플레이어 애니메이션이 차이 픽셀을 만들지 않게 숨긴다.
	for node in scene.get_children():
		if node is CanvasLayer:
			node.hide()
	player.hide()
	camera.position = Vector2(600,260)
	var terrain = scene.get_node("공중_얇은발판")
	player.position = Vector2(300,180)
	await shot("rim_on")
	terrain.set("근접반사_세기",0.0)
	await shot("rim_off")
	terrain.set("근접반사_세기",0.10)
	for i in int(terrain.call("필요횟수")):
		scene.get_node("페인트코어").call("발사_소모")
		scene.get_node("페인트코어").call("명중_처리",terrain,1,Vector2(300,190))
	await shot("painted")
	# 새 지형의 로컬 좌표와 세계 좌표 판정이 어긋나지 않는지도 눈으로 비교한다.
	for pos in [Vector2(0,0),Vector2(1950,0),Vector2(0,1100),Vector2(1950,1100)]:
		camera.position = pos
		camera.zoom = Vector2(0.55,0.55)
		await shot("edge_%d_%d" % [pos.x,pos.y])
		var viewport_rect := Rect2(Vector2.ZERO,root.get_visible_rect().size)
		var far: Sprite2D = scene.get_node("먼벽/그림")
		for corner in [viewport_rect.position, Vector2(viewport_rect.end.x,0),viewport_rect.end,Vector2(0,viewport_rect.end.y)]:
			var local: Vector2 = far.get_global_transform_with_canvas().affine_inverse() * corner
			if not far.get_rect().has_point(local):
				failure += 1
				print("FAIL_BACKGROUND ",pos," ",local)
	print("GRAPHICS_RESULT failures=",failure)
	quit(1 if failure else 0)
