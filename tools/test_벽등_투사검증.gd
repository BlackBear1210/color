extends SceneTree
## 실제 2-9 렌더링 비교. 씬 파일은 저장하지 않고 플레이어/카메라만 검사 위치에 둔다.
const OUT := "res://docs/visual_review/lamp_shadow_20260929/"
var stage: Node
var player: Node2D
var manager: Node

func _initialize() -> void:
	Engine.max_fps = 60
	call_deferred("_run")

func _shot(label: String) -> void:
	for i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OUT + label + ".png")
	assert(result == OK)

func _run() -> void:
	root.content_scale_size = Vector2i(1920,1080)
	root.size = Vector2i(1920,1080)
	stage = load("res://scenes/world_2_클로드/stage_2-9.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	for i in range(25):
		await process_frame
	player = get_first_node_in_group("player") as Node2D
	assert(player != null)
	stage.set_physics_process(false)
	player.set_physics_process(false)
	player.set_process(false)
	player.set("velocity", Vector2.ZERO)
	# 충돌 판정/낙하를 멈추고 같은 카메라에서 그림자 유무만 비교한다.
	for old_camera in stage.find_children("*", "Camera2D", true, false):
		old_camera.set_process(false)
		old_camera.set_physics_process(false)
		old_camera.enabled = false
	var camera := Camera2D.new()
	camera.position = Vector2(1430,3550)
	camera.zoom = Vector2(0.8,0.8)
	stage.add_child(camera)
	camera.make_current()
	manager = stage.find_child("실시간벽등",true,false)
	assert(manager != null)
	var occluder := player.get_node_or_null("CollisionPolygon2D/벽등가림막") as LightOccluder2D
	assert(occluder != null)
	var sprite := player.get_node("CharacterSprite") as AnimatedSprite2D
	sprite.pause()
	sprite.set_process(false)
	sprite.set_physics_process(false)
	# 시간에 따라 바뀌는 화면 입자가 픽셀 차이에 섞이지 않도록 비교 촬영에서만 숨긴다.
	var fx := stage.get_node_or_null("하수도화면효과")
	if fx is CanvasLayer:
		fx.visible = false
	var wall_material: ShaderMaterial = manager.get("_벽재질")
	assert(wall_material != null)
	player.position = Vector2(1280,3610)
	await _shot("near_right_on")
	occluder.visible = false
	await _shot("near_right_off")
	occluder.visible = true
	# 같은 광원을 통과해 반대쪽으로 이동시켜 그림자 방향 변화를 확인한다.
	for i in range(31):
		player.position = Vector2(1280,3610).lerp(Vector2(1090,3610), float(i)/30.0)
		await process_frame
	await _shot("near_left_on")
	occluder.visible = false
	await _shot("near_left_off")
	occluder.visible = true
	wall_material.set_shader_parameter("housing_shadows", false)
	await _shot("housing_off")
	wall_material.set_shader_parameter("housing_shadows", true)
	await _shot("housing_on")
	wall_material.set_shader_parameter("relief_depth", 0.0)
	await _shot("normal_off")
	wall_material.set_shader_parameter("relief_depth", 0.65)
	await _shot("normal_on")
	# 검사에서만 광원을 좌우로 옮겨 투사 방향이 이미지에 고정되지 않았음을 비교한다.
	var nearest: Node2D
	for lamp in manager.get("_등들").values():
		if lamp.global_position.distance_to(Vector2(1188.4,3473)) < 1.0:
			nearest = lamp
	assert(nearest != null)
	var light := nearest.find_children("*", "PointLight2D", false, false)[0] as PointLight2D
	light.position.x = -70
	await _shot("projection_light_left")
	light.position.x = 70
	await _shot("projection_light_right")
	light.position.x = 0
	print("LAMP_CHECK player_occluder=",occluder.is_visible_in_tree()," mask=",occluder.occluder_light_mask,
		" lights=",manager.get("_등들").size()," player=",player.position)
	quit(0)
