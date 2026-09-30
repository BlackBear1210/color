extends Node2D
## 2-9 전용. 벽등 좌표는 월드 격자에 고정하고 화면에 필요한 등만 생성한다.
## 플레이어 좌표로 광원을 이동하지 않는다. 노멀/그림자는 Godot의 실시간 조명이 계산한다.
const TILE := Vector2(998.4, 665.6)
# [2026-09-29 Claude · 도형님 "너무 평면적"] 넓은 채움광(반경 320)이 벽 전체를 고르게 밝혀 명암이 사라졌다.
# 시안 ver.2 처럼 어두운 공간 속 작고 진한 빛 웅덩이로 — 반경을 줄이고 중심 세기를 올린다(ENERGY).
# 시안 실측: 등에서 40px 45 · 80px 28(벽 바탕 35) — 빛이 빨리 떨어진다.
const RADIUS := 230.0
const ENERGY := 3.0
# 광원을 벽에 가깝게(낮게) 두면 빛이 벽을 비스듬히 스쳐 벽돌 윗면/아랫면 명암(노멀)이 드러난다.
# 128 에서는 거의 정면이라 노멀을 켜도 차이가 2/255 뿐이었다.
const HEIGHT := 90.0
var _등들: Dictionary = {}
var _광원텍스처: GradientTexture2D
## [2026-09-30] 번짐 전용 텍스처. 광원용 그라데이션은 빛 웅덩이를 작게 하려고 가파르게 바꿔서(0.12/0.40),
## 같이 쓰던 번짐이 유리 본체 밖으로 거의 안 나왔다 → 번짐은 넓고 완만한 것을 따로 쓴다.
var _번짐텍스처: GradientTexture2D
var _갱신대기 := 0.0
var _벽재질: ShaderMaterial

func _ready() -> void:
	# 벽에서 돌출된 등 하우징의 투사 계산은 벽 재질의 실제 light() 패스가 담당한다.
	var wall := get_parent().get_node_or_null("벽돌벽/그림") as Sprite2D
	if wall != null:
		벽재질_설정(wall)
	var gradient := Gradient.new()
	# 가장자리로 빨리 떨어지는 빛(중심 진하고 바깥은 금방 어둠) — 평면적인 넓은 채움을 피한다.
	gradient.offsets = PackedFloat32Array([0.0, 0.12, 0.40, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1,1,1,0.62), Color(1,1,1,0.12), Color(1,1,1,0)])
	_광원텍스처 = GradientTexture2D.new()
	_광원텍스처.gradient = gradient
	_광원텍스처.width = 256
	_광원텍스처.height = 256
	_광원텍스처.fill = GradientTexture2D.FILL_RADIAL
	_광원텍스처.fill_from = Vector2(0.5,0.5)
	_광원텍스처.fill_to = Vector2(1,0.5)
	# [2026-09-30] 발밑 접지 그림자 — 이 배경을 쓰는 하수도 스테이지에서만 생긴다(다른 챕터 Player 는 그대로).
	# 발밑 그림자는 Player 자식으로(배경 안이나 스테이지 루트에 두면 지형 마감 메시에 덮였다).
	call_deferred("_발밑그림자_설치")
	# [2026-09-30] 하수도 효과음(발소리 · 입수 · 떨어지는 물) — 이 배경을 쓰는 스테이지에만.
	call_deferred("_물소리_설치")
	var soft := Gradient.new()
	soft.offsets = PackedFloat32Array([0.0, 0.22, 0.55, 1.0])
	soft.colors = PackedColorArray([Color.WHITE, Color(1,1,1,0.55), Color(1,1,1,0.16), Color(1,1,1,0)])
	_번짐텍스처 = GradientTexture2D.new()
	_번짐텍스처.gradient = soft
	_번짐텍스처.width = 256
	_번짐텍스처.height = 256
	_번짐텍스처.fill = GradientTexture2D.FILL_RADIAL
	_번짐텍스처.fill_from = Vector2(0.5,0.5)
	_번짐텍스처.fill_to = Vector2(1,0.5)
	call_deferred("_가림막_설치")

func _등_생성(at: Vector2) -> Node2D:
	var lamp := Node2D.new()
	lamp.position = at
	lamp.z_index = -90
	add_child(lamp)
	# 작은 발광 번짐만 몸체 뒤에 더한다. 넓은 벽 조명이나 방향성 그림자를 대신하지 않는다.
	var halo := Sprite2D.new()
	halo.texture = _번짐텍스처
	# [2026-09-30] 시안 ver.2 등은 유리 주변(지름 약 110px)이 은은하게 번진다. 유리 본체(48×76)가 가운데를 덮으므로
	# 번짐은 그 밖으로 충분히 나오게 크게(지름 약 150×180) · 세기 0.45. 등 모양처럼 세로로 조금 길게.
	halo.scale = Vector2(0.60, 0.72)
	halo.modulate = Color(1, 1, 1, 0.45)
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
	light.energy = ENERGY
	light.height = HEIGHT
	light.shadow_enabled = true
	light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	# [2026-09-30] 플레이어 그림자가 너무 옅었다(명암차 10~17/255) → 0.60 → 0.80.
	light.shadow_color = Color(0,0,0,0.80)
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
			# [2026-09-30] 등 자리가 지형 속이면 만들지 않는다 — 등 몸체는 지형에 가려지는데 빛은 지형 앞면을 비춰
			# 어두운 지형 덩어리 위에 "등 없는 동그란 빛" 이 떠 보였다(2-2·2-4·2-7·2-10·2-11 실화면).
			if _지형속(at):
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
	# [2026-09-29] 광원을 낮추자(HEIGHT) 하우징 투사가 커져 등 바로 옆이 오히려 어두워졌다(시안은 등 옆이 가장 밝다).
	# 돌출 깊이를 18 → 7 로 줄여 그림자는 등 테두리 가까이에만 남긴다.
	_벽재질.set_shader_parameter("housing_depth", 7.0 * zoom_scale.x)

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


func _발밑그림자_설치() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node
	if player == null or player.has_node("발밑그림자"):
		return
	var foot := preload("res://scripts/스마트월드/하수도_발밑그림자.gd").new()
	foot.name = "발밑그림자"
	player.add_child(foot)
	player.move_child(foot, 0)   # 캐릭터 그림보다 먼저 그린다 → 발 뒤

func _물소리_설치() -> void:
	var stage := get_parent().get_parent()
	if stage == null or stage.has_node("하수도물소리"):
		return
	var sound := preload("res://scripts/스마트월드/하수도_물소리.gd").new()
	sound.name = "하수도물소리"
	stage.add_child(sound)

## 등 몸체(48×76)의 가운데와 위아래 끝 중 하나라도 지형(레이어 1) 안이면 지형 속으로 본다.
func _지형속(at: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsPointQueryParameters2D.new()
	q.collision_mask = 1
	for dy in [-30.0, 0.0, 30.0]:
		q.position = at + Vector2(0.0, dy)
		if not space.intersect_point(q, 1).is_empty():
			return true
	return false
