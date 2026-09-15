extends SceneTree
## 기존 시험 배치를 보존하면서 시차 배경 위의 연결·정식 아트를 실제 렌더러로 캡처한다.
var scene: Node2D
var camera: Camera2D
func _initialize() -> void:
	call_deferred("run")
func shot(label: String, at: Vector2, zoom_value: float) -> void:
	camera.position = at
	camera.zoom = Vector2.ONE * zoom_value
	for i in 15:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/support_" + label + ".png")
	print("SHOT ", label)
func run() -> void:
	scene = load("res://scenes/테스트/하수도_지지구조/쇠사슬_지지대_시험.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.set_physics_process(false)
	scene.get_node("Player").set_physics_process(false)
	scene.get_node("Player").hide()
	var previous = scene.get_node("카메라")
	previous.set_process(false)
	previous.set_physics_process(false)
	previous.enabled = false
	for child in scene.get_children():
		if child is CanvasLayer:
			child.hide()
	# 배경 시차가 고정구와 체인의 월드 위치에 영향을 주지 않는지 실제 배경으로 비교한다.
	var source = load("res://scenes/테스트/하수도_지형_v01/색칠_사망_플레이시험.tscn").instantiate()
	for key in ["먼벽", "아치배관"]:
		var layer = source.get_node(key).duplicate()
		scene.add_child(layer)
		layer.get_node("그림").position = Vector2(-1600,-800)
		layer.get_node("그림").scale = Vector2(5,5)
	source.free()
	camera = Camera2D.new()
	scene.add_child(camera)
	camera.make_current()
	await shot("brackets",Vector2(850,1320),1.5)
	await shot("chain_detail",Vector2(2640,480),2.0)
	await shot("lift_a",Vector2(3300,800),0.8)
	await shot("lift_b",Vector2(3450,1000),0.8)
	print("SUPPORT_ART_GRAPHICS_DONE")
	quit()
