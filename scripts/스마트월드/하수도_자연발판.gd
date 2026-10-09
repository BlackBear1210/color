@tool
extends "res://scripts/스마트월드/하수도_벽돌지형.gd"

const 자연면_셰이더 = preload("res://shaders/sewer_natural_platform.gdshader")
const 선반_셰이더 = preload("res://shaders/sewer_ledge_v03.gdshader")
const 상면_그림 = preload("res://assets/textures/smartshape/sewer_ledge_v03/black/fill.png")
const 마감_생성기 = preload("res://scripts/스마트월드/하수도_마감메시.gd")
const 원근_생성기 = preload("res://scripts/스마트월드/하수도_원근마감.gd")
## 2-1~2-5와 신규 제작용. 돌 재질을 유지하며 챕터1처럼 윗면/왼 옆면을 같은 방향으로 투영한다.
## 기본은 꺼서 이번 요청 밖 스테이지의 외관을 바꾸지 않는다.
@export var 챕터1_원근: bool = false:
	set(value):
		if 챕터1_원근 == value:
			return
		챕터1_원근 = value
		set_as_dirty()
		_마감_요청()

func 발_그림_깊이() -> float:
	# 실제 몸/충돌은 움직이지 않고 발 그림만 22px 윗면의 가운데에 맞춘다.
	return 7.0 if 챕터1_원근 and 땅지형 and not 석조선반 and 윗면표시 else 0.0

func _build_fill_mesh(points: PackedVector2Array, s_mat: SS2D_Material_Shape, mesh_buffer: Array[SS2D_Mesh], buffer_idx: int) -> int:
	if 챕터1_원근 and 땅지형 and not 석조선반 and 윗면표시:
		# 본체 모서리도 덮개와 같은 사선으로 잘라 네모 앞면이 윗면 밖으로 튀어나오지 않게 한다.
		# 충돌/편집 점은 그대로 두며 그림용 복사본만 쓴다.
		points = 원근_생성기.투영.깎은_윤곽(원근_생성기.윤곽(points), 원근_생성기.이웃(self, points))
	return super._build_fill_mesh(points, s_mat, mesh_buffer, buffer_idx)
## [2026-09-30] 보낸이를 싣는다 — 받는 쪽이 경계를 보고 자기와 닿을 때만 재계산한다.
signal 마감_배치변경(보낸이: Node2D)
var _마지막_변환 := Transform2D()
var _월드경계_캐시 := Rect2()
var _월드경계_유효 := false
var _이동전_경계 := Rect2()

# 웅덩이에 잠긴 부분의 입체 마감만 가린다. 본체/페인트/충돌은 그대로 유지한다.
var _침수_가림: Dictionary = {}

# 발판 양옆 돌은 원본의 사선 줄눈 대신 금속 윤곽으로 끝나도록 별도 접합 UV를 쓴다.
var _매립_접합: Dictionary = {}

func 매립접합_설정(source_id: int, world_rect: Rect2) -> void:
	if not world_rect.has_area():
		if not _매립_접합.erase(source_id):
			return
	elif _매립_접합.get(source_id) == world_rect:
		return
	else:
		_매립_접합[source_id] = world_rect
	_매립_유니폼_갱신()

func _매립_유니폼_갱신() -> void:
	var 접합: Array[Vector4] = []
	for rect: Rect2 in _매립_접합.values():
		var 시작 := to_local(rect.position)
		var 끝 := to_local(rect.end)
		접합.append(Vector4(시작.x, 끝.x, 시작.y, (끝.x - 시작.x) / 3.0))
		if 접합.size() == 8:
			break
	var 개수 := 접합.size()
	접합.resize(8)
	for part in _마감_노드:
		part.material.set_shader_parameter("socket_joint_count", 개수)
		part.material.set_shader_parameter("socket_joints", 접합)

func 침수마감_설정(source_id: int, world_polygon: PackedVector2Array) -> void:
	if world_polygon.is_empty():
		if _침수_가림.erase(source_id):
			_마감_요청()
	elif _침수_가림.get(source_id) != world_polygon:
		_침수_가림[source_id] = world_polygon
		_마감_요청()

## 2-9 비교 구간의 명도 조율만 선택적으로 적용한다. 색 판정/페인트 데이터는 바꾸지 않는다.
@export var 시안_명도조율: bool = false
## [2026-09-29 Claude] ver.2 앞 지형 깊이감: 검정 몸통을 어둡고 차분하게(시안 실측 몸통 20 · 대비 12 — 지금 43 · 31).
## 윗면 갓돌(별도 마감 메시)은 그대로 밝게 남아 윤곽이 선다. 흰 지형 색은 안 바꾼다(색 판정 가독성).
## 2-9 에서 먼저 확인하려고 기본은 끔 — 도형님이 확인 후 전 스테이지 적용 여부를 정한다.
@export var 앞지형_깊이: bool = false
@export var 석조선반: bool = false
@export var 땅지형: bool = false
@export var 윗면표시: bool = true:
	set(value):
		윗면표시 = value
		_마감_요청()
@export var 옆면마감: bool = true:
	set(value):
		옆면마감 = value
		_마감_요청()
## ★[2026-09-30] 투명발판 v2 — 벽돌 배경 앞에서 "투명발판" 으로 읽히게(도형님 시안 확정값은 투명발판 프리팹에 박혀 있다).
##   모자이크/번짐/반투명도는 부모(`지형.gd` 유령 발판 그룹) 값을 그대로 쓰고, 여기서는 구분용 세 가지만 더한다.
##   기본값은 전부 "예전 그대로"(끔) — 이미 찍힌 기본지형 유령(2-11 등)의 모습이 몰래 바뀌지 않게.
@export_group("유령 발판")
## 윗면 선을 빛나게, 나머지 테두리는 옅게. 0 = 끔.
@export_range(0.0, 1.0, 0.05) var 유령_가장자리빛: float = 0.0:
	set(v): 유령_가장자리빛 = v; _유니폼_갱신()
## 모자이크가 좌우로 살짝 흔들리고 밝기가 숨 쉬듯 변한다. 움직이지 않는 배경 벽돌과 갈라 보이게.
@export var 유령_일렁임: bool = false:
	set(v): 유령_일렁임 = v; _유니폼_갱신()
## 차가운 푸른빛 섞는 양(셰이더 ghost_tint_amount). 배경 벽돌은 따뜻한 회색이라 이것만으로도 떠 보인다.
@export_range(0.0, 1.0, 0.05) var 유령_푸른빛: float = 0.30:
	set(v): 유령_푸른빛 = v; _유니폼_갱신()
@export_group("")

func _유니폼_갱신() -> void:
	super._유니폼_갱신()
	for mat in _셰이더들:
		mat.set_shader_parameter("ghost_edge", 유령_가장자리빛)
		mat.set_shader_parameter("ghost_wobble", 유령_일렁임)
		mat.set_shader_parameter("ghost_tint_amount", 유령_푸른빛)

var _마감_필요: bool = true
var _접합_서명: int = 0
var _마감_노드: Array[MeshInstance2D] = []
var _관찰대상: Array[Node2D] = []
var 마감_생성횟수: int = 0

func bake_collision() -> void:
	super.bake_collision()
	# 공중 돌 지형은 격자와 달리 아래·옆에서도 막혀야 한다.
	# 씬에 남은 단방향 설정도 SS2D 최초 굽기와 점 편집 때마다 해제한다.
	var 폴리 := get_collision_polygon_node()
	if 폴리 != null:
		폴리.one_way_collision = false

func _ready() -> void:
	super._ready()
	if not points_modified.is_connected(_마감_요청):
		points_modified.connect(_마감_요청)
	if not on_dirty_update.is_connected(_마감_요청):
		on_dirty_update.connect(_마감_요청)
	set_notify_transform(true)
	if get_parent() != null and not get_parent().child_order_changed.is_connected(_마감_요청):
		get_parent().child_order_changed.connect(_마감_요청)
	_마감_요청()

func _notification(what: int) -> void:
	# 고정 지형은 폴링하지 않고 실제 배치 변경에만 반응한다.
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		# ★[2026-09-30 Claude 실측] 같은 position 을 다시 대입해도 이 알림이 온다(압력버튼이 매 물리 틱 그랬다).
		#   그대로 믿으면 이웃 전부가 매 프레임 마감을 재계산해 2-9 가 60FPS 밑으로 떨어졌다 → 실제로 바뀐 때만.
		var 지금 := global_transform
		if 지금 == _마지막_변환:
			return
		_마지막_변환 = 지금
		# 이웃이 "내가 떠난 자리" 도 검사할 수 있게 옮기기 전 경계를 남기고 새 경계는 다음에 다시 잰다.
		_이동전_경계 = _월드경계_캐시 if _월드경계_유효 else Rect2()
		_월드경계_유효 = false
		_마감_요청()
		마감_배치변경.emit(self)

func _셰이더_설치() -> void:
	super._셰이더_설치()
	# 부모가 물감 재질 목록을 새로 만들면 마감도 새 목록에 다시 등록한다.
	_접합_서명 = 0
	_마감_요청()

func _마감_요청() -> void:
	_마감_필요 = true
	# 점이 바뀌었을 수도 있으니 경계는 다음에 다시 잰다(쓸 때만 계산하므로 싸다).
	_월드경계_유효 = false

## [2026-09-30] 월드 좌표 경계(테셀레이션 점 기준). 이웃 필터용 — 캐시해 두고 점·변환이 바뀔 때만 다시 잰다.
func 월드경계() -> Rect2:
	if _월드경계_유효:
		return _월드경계_캐시
	var 점들: PackedVector2Array = get_point_array().get_tessellated_points()
	if 점들.is_empty():
		_월드경계_캐시 = Rect2(global_position, Vector2.ZERO)
	else:
		var 변환 := global_transform
		_월드경계_캐시 = Rect2(변환 * 점들[0], Vector2.ZERO)
		for 점 in 점들:
			_월드경계_캐시 = _월드경계_캐시.expand(변환 * 점)
	_월드경계_유효 = true
	return _월드경계_캐시

## 로컬 24px 여유(`_접합_갱신` 의 bounds.grow(24))를 월드로 옮긴 값. 배율이 있어도 기존보다 덜 거르지 않게 크게 잡는다.
func _이웃_여유() -> float:
	return 24.0 * maxf(absf(global_scale.x), absf(global_scale.y)) + 1.0

## 이웃 지형이 움직였다. 그 지형의 지금/옮기기 전 경계가 내 마감 범위(+24)에 닿을 때만 재계산한다.
## ★[2026-09-30] 예전에는 형제 지형 전부가 무조건 재계산했다(27 개 × 26 이웃의 점 변환 = 한 바퀴 ≈10ms).
func _이웃_배치변경(보낸이: Node2D) -> void:
	if not is_instance_valid(보낸이) or not 보낸이.has_method("월드경계"):
		_마감_요청()
		return
	var 내범위 := 월드경계().grow(_이웃_여유())
	var 이전: Rect2 = 보낸이.get("_이동전_경계")
	if 내범위.intersects(보낸이.call("월드경계"), true) or (이전.has_area() and 내범위.intersects(이전, true)):
		_마감_요청()

func _process(delta: float) -> void:
	super._process(delta)
	# 일렁임 시간은 게임 중·아직 유령일 때만 민다(셰이더 TIME 금지 규칙 — 에디터가 쉬지 못한다).
	#   칠해서 굳으면 _유령_세기값() 이 0 이 되어 더 이상 매 프레임 값을 보내지 않는다.
	if 유령_일렁임 and not Engine.is_editor_hint() and _유령_세기값() > 0.0:
		var 시각 := fmod(float(Time.get_ticks_msec()) * 0.001, 3600.0)
		for mat in _셰이더들:
			mat.set_shader_parameter("anim_time", 시각)
	if _마감_필요 and 땅지형 and not 석조선반 and is_inside_tree():
		_마감_필요 = false
		_접합_갱신()

func _이웃_연결() -> void:
	# 이웃 점/변환/표시가 바뀔 때만 갱신 요청한다. 렌더 갱신 신호는 서명으로 걸러낸다.
	for other in _관찰대상:
		if not is_instance_valid(other):
			continue
		for event in ["points_modified", "item_rect_changed", "visibility_changed"]:
			if other.has_signal(event) and other.is_connected(event, _마감_요청):
				other.disconnect(event, _마감_요청)
		if other.has_signal("마감_배치변경") and other.is_connected("마감_배치변경", _이웃_배치변경):
			other.disconnect("마감_배치변경", _이웃_배치변경)
	_관찰대상.clear()
	for other in get_parent().get_children():
		if other == self or not other is Node2D or not other.has_method("get_point_array"):
			continue
		_관찰대상.append(other as Node2D)
		for event in ["points_modified", "item_rect_changed", "visibility_changed"]:
			if other.has_signal(event) and not other.is_connected(event, _마감_요청):
				other.connect(event, _마감_요청)
		# 이동 신호는 경계 검사를 거친다 — 멀리 있는 지형이 움직여도 나는 재계산하지 않는다.
		if other.has_signal("마감_배치변경") and not other.is_connected("마감_배치변경", _이웃_배치변경):
			other.connect("마감_배치변경", _이웃_배치변경)

func _접합_갱신() -> void:
	if get_parent() == null or shape_material == null:
		return
	_이웃_연결()
	var points: PackedVector2Array = get_point_array().get_tessellated_points()
	if points.size() > 1 and points[0].is_equal_approx(points[-1]):
		points.remove_at(points.size() - 1)
	if points.size() < 3:
		return
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	var others: Array[PackedVector2Array] = []
	# [2026-09-30] 캐시된 월드 경계로 먼저 거른다 — 멀리 있는 이웃의 점을 하나하나 변환하지 않는다.
	#   (아래 bounds.grow(24) 검사와 같은 기준이라 결과는 같고, 한 번 재계산 비용만 준다.)
	var 내범위 := 월드경계().grow(_이웃_여유())
	for other in _관찰대상:
		if not other.is_visible_in_tree():
			continue
		if other.has_method("월드경계") and not 내범위.intersects(other.call("월드경계"), true):
			continue
		var array: Resource = other.call("get_point_array") as Resource
		if array == null:
			continue
		var polygon := PackedVector2Array()
		var other_points: PackedVector2Array = array.call("get_tessellated_points")
		for point in other_points:
			polygon.append(to_local(other.to_global(point)))
		if polygon.size() < 3:
			continue
		var other_bounds := Rect2(polygon[0], Vector2.ZERO)
		for point in polygon:
			other_bounds = other_bounds.expand(point)
		if bounds.grow(24.0).intersects(other_bounds, true):
			others.append(polygon)
	var submerged: Array[PackedVector2Array] = []
	for world_polygon: PackedVector2Array in _침수_가림.values():
		var local_polygon := PackedVector2Array()
		for point in world_polygon:
			local_polygon.append(to_local(point))
		submerged.append(local_polygon)
	var signature := hash([points, others, submerged, global_transform, 챕터1_원근, 윗면표시, 옆면마감, shape_material.get_instance_id(),
		shape_material.fill_texture_scale, shape_material.fill_texture_offset,
		shape_material.fill_texture_absolute_position, shape_material.fill_texture_angle_offset,
		shape_material.fill_texture_absolute_rotation, shape_material.fill_textures])
	if signature == _접합_서명:
		return
	_접합_서명 = signature
	for part in _마감_노드:
		_셰이더들.erase(part.material)
		remove_child(part)
		part.queue_free()
	if 챕터1_원근:
		_마감_노드 = 원근_생성기.생성(self, points, others, 윗면표시, 옆면마감, submerged)
		# 이웃/침수 변경으로 덮개가 바뀌면 본체 절단도 다시 굽는다. 같은 서명에서는 반복하지 않는다.
		set_as_dirty()
	else:
		_마감_노드 = 마감_생성기.생성(self, points, others, 윗면표시, 옆면마감, submerged)
	for part in _마감_노드:
		# 생성물은 저장하지 않는다. owner를 변경하지 않아 씬 재로드 중복을 막는다.
		add_child(part)
		if not Engine.is_editor_hint():
			_셰이더들.append(part.material)
	# 지형 편집으로 마감 메시가 재생성되어도 접합용 돌의 UV 설정을 복구한다.
	_매립_유니폼_갱신()
	if not Engine.is_editor_hint():
		_유니폼_갱신()
	마감_생성횟수 += 1

func _셰이더_만들기(source: Texture2D, quiet: bool = false, edge: bool = false) -> ShaderMaterial:
	var result := super._셰이더_만들기(source, quiet, edge)
	if result == null:
		return null
	result.shader = 선반_셰이더 if 석조선반 else 자연면_셰이더
	# 선반은 별도 셰이더이므로 땅 본체에만 새 유니폼을 전달한다.
	if not 석조선반:
		result.set_shader_parameter("reference_tone", 시안_명도조율)
		result.set_shader_parameter("front_depth", 앞지형_깊이)
	if 석조선반:
		result.set_shader_parameter("ledge_top_half_depth", 4.0)
	else:
		# 넓은 본체는 윤곽/가림 루프를 실행하지 않는다. 마감은 별도 좁은 메시다.
		result.set_shader_parameter("cached_draw_mode", 1)
		result.set_shader_parameter("ground_edge_count", 0)
		result.set_shader_parameter("ground_cover_count", 0)
		result.set_shader_parameter("ground_top_half_depth", 4.0)
		result.set_shader_parameter("ground_cap_tex", 상면_그림)
	result.set_shader_parameter("ground_platform", 땅지형)
	var polygon := get_collision_polygon_node()
	if polygon != null and not polygon.polygon.is_empty():
		var bounds := Rect2(polygon.polygon[0], Vector2.ZERO)
		for point in polygon.polygon:
			bounds = bounds.expand(point)
		result.set_shader_parameter("surface_bounds", Vector4(bounds.position.x, bounds.position.y, bounds.end.x, bounds.end.y))
	return result
