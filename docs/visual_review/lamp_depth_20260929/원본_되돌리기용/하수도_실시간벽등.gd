extends Node2D
## 2-9 전용. 벽등 좌표는 월드 격자에 고정하고 화면에 필요한 등만 생성한다.
## 플레이어 좌표로 광원을 이동하지 않는다. 노멀/그림자는 Godot의 실시간 조명이 계산한다.
const TILE := Vector2(998.4, 665.6)
# 기존 260 범위의 가장자리에서 그림자 명암차가 5/255 이하로 사라져 통행 영역까지 빛을 확보한다.
const RADIUS := 320.0
var _등들: Dictionary = {}
var _광원텍스처: GradientTexture2D
var _갱신대기 := 0.0
var _벽재질: ShaderMaterial

func _ready() -> void:
	# 벽에서 돌출된 등 하우징의 투사 계산은 벽 재질의 실제 light() 패스가 담당한다.
	var wall := get_parent().get_node_or_null("벽돌벽/그림") as Sprite2D
	if wall != null:
		벽재질_설정(wall)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1,1,1,0.70), Color(1,1,1,0.18), Color(1,1,1,0)])
	_광원텍스처 = GradientTexture2D.new()
	_광원텍스처.gradient = gradient
	_광원텍스처.width = 256
	_광원텍스처.height = 256
	_광원텍스처.fill = GradientTexture2D.FILL_RADIAL
	_광원텍스처.fill_from = Vector2(0.5,0.5)
	_광원텍스처.fill_to = Vector2(1,0.5)
	call_deferred("_가림막_설치")

func _등_생성(at: Vector2) -> Node2D:
	var lamp := Node2D.new()
	lamp.position = at
	lamp.z_index = -90
	add_child(lamp)
	# 작은 발광 번짐만 몸체 뒤에 더한다. 넓은 벽 조명이나 방향성 그림자를 대신하지 않는다.
	var halo := Sprite2D.new()
	halo.texture = _광원텍스처
	halo.scale = Vector2(0.30, 0.40)
	halo.modulate = Color(1, 1, 1, 0.10)
	var halo_material := CanvasItemMaterial.new()
	halo_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	halo.material = halo_material
	lamp.add_child(halo)
	# 유리 발광과 금속을 별도 패스로 분리해 발광부가 검게 음영 처리되지 않게 한다.
	for shader in [preload("res://shaders/sewer_lamp_glass.gdshader"), preload("res://shaders/sewer_lamp_realtime.gdshader")]:
		var body := ColorRect.new()
		body.position = Vector2(-24,-38)
		body.size = Vector2(48,76)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = shader
		body.material = mat
		lamp.add_child(body)
	var light := PointLight2D.new()
	light.texture = _광원텍스처
	light.texture_scale = RADIUS / 128.0
	light.energy = 1.15
	light.height = 128.0
	light.shadow_enabled = true
	light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	light.shadow_color = Color(0,0,0,0.60)
	light.shadow_item_cull_mask = 16
	lamp.add_child(light)
	return lamp

func _process(delta: float) -> void:
	# 카메라 이동 프레임마다 좌표를 갱신해 그림자가 벽에서 미끄러지지 않게 한다.
	_벽그림자_갱신()
	_갱신대기 -= delta
	if _갱신대기 > 0.0:
		return
	_갱신대기 = 0.1
	var inverse := get_viewport().get_canvas_transform().affine_inverse()
	var visible_rect := Rect2(inverse * Vector2.ZERO, Vector2.ZERO)
	visible_rect = visible_rect.expand(inverse * get_viewport_rect().size).grow(RADIUS + 80.0)
	var needed: Dictionary = {}
	for y in range(int(floor(visible_rect.position.y/TILE.y))-1, int(ceil(visible_rect.end.y/TILE.y))+1):
		for x in range(int(floor(visible_rect.position.x/TILE.x))-1, int(ceil(visible_rect.end.x/TILE.x))+1):
			# 불규칙한 간격은 고정된 셀 번호로 결정. 카메라가 움직여도 배치는 바뀌지 않는다.
			var offset := Vector2(190,145) if posmod(x+y,2)==0 else Vector2(735,465)
			var at := Vector2(x,y)*TILE+offset
			if not visible_rect.has_point(at):
				continue
			var key := Vector2i(x,y)
			needed[key] = true
			if not _등들.has(key):
				_등들[key] = _등_생성(at)
	for key in _등들.keys():
		if not needed.has(key):
			_등들[key].queue_free()
			_등들.erase(key)
	_벽그림자_갱신()

func 벽재질_설정(wall: Sprite2D) -> void:
	# Compatibility 렌더러는 수신 CanvasItem의 light_mask도 shadow_item_cull_mask와 비교한다.
	# 광원/가림막만 16으로 맞추면 기본값 1인 벽에는 그림자가 전혀 표시되지 않는다.
	wall.light_mask |= 16
	# 씬 공유 재질을 복제하여 다른 배경 인스턴스의 광원 좌표를 덮어쓰지 않는다.
	_벽재질 = wall.material.duplicate() as ShaderMaterial
	wall.material = _벽재질

func _벽그림자_갱신() -> void:
	if _벽재질 == null:
		return
	var housings := PackedVector4Array()
	var canvas := get_viewport().get_canvas_transform()
	var zoom_scale := Vector2(canvas.x.length(), canvas.y.length())
	for lamp in _등들.values():
		if housings.size() == 32:
			break
		var center: Vector2 = canvas * lamp.global_position
		housings.append(Vector4(center.x, center.y, 15.5 * zoom_scale.x, 25.0 * zoom_scale.y))
	var count := housings.size()
	housings.resize(32)
	_벽재질.set_shader_parameter("lamp_housings", housings)
	_벽재질.set_shader_parameter("lamp_housing_count", count)
	_벽재질.set_shader_parameter("housing_depth", 18.0 * zoom_scale.x)

func _가림막_추가(shape: CollisionPolygon2D) -> void:
	if shape == null or shape.polygon.size() < 3 or shape.has_node("벽등가림막"):
		return
	var occluder := LightOccluder2D.new()
	occluder.name = "벽등가림막"
	occluder.occluder_light_mask = 16
	occluder.show_behind_parent = true
	var polygon := OccluderPolygon2D.new()
	polygon.polygon = shape.polygon
	occluder.occluder = polygon
	shape.add_child(occluder) # 실제 충돌 노드에 붙여 움직이는 물체의 변환을 따라간다.

func _가림막_설치() -> void:
	# SS2D의 지연 메시/충돌 생성이 끝난 뒤 실제 다각형을 받는다.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var stage := get_parent().get_parent()
	var terrain := stage.get_node_or_null("지형")
	if terrain != null:
		for node in terrain.get_children():
			if node.has_method("get_collision_polygon_node"):
				_가림막_추가(node.call("get_collision_polygon_node") as CollisionPolygon2D)
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		_가림막_추가(player.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D)
