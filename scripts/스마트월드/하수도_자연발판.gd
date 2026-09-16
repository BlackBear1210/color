@tool
extends "res://scripts/스마트월드/하수도_벽돌지형.gd"

const 자연면_셰이더 = preload("res://shaders/sewer_natural_platform.gdshader")
const 선반_셰이더 = preload("res://shaders/sewer_ledge_v03.gdshader")
const 상면_그림 = preload("res://assets/textures/smartshape/sewer_ledge_v03/black/fill.png")
const 마감_생성기 = preload("res://scripts/스마트월드/하수도_마감메시.gd")
signal 마감_배치변경

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
var _마감_필요: bool = true
var _접합_서명: int = 0
var _마감_노드: Array[MeshInstance2D] = []
var _관찰대상: Array[Node2D] = []
var 마감_생성횟수: int = 0

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
		_마감_요청()
		마감_배치변경.emit()

func _셰이더_설치() -> void:
	super._셰이더_설치()
	# 부모가 물감 재질 목록을 새로 만들면 마감도 새 목록에 다시 등록한다.
	_접합_서명 = 0
	_마감_요청()

func _마감_요청() -> void:
	_마감_필요 = true

func _process(delta: float) -> void:
	super._process(delta)
	if _마감_필요 and 땅지형 and not 석조선반 and is_inside_tree():
		_마감_필요 = false
		_접합_갱신()

func _이웃_연결() -> void:
	# 이웃 점/변환/표시가 바뀔 때만 갱신 요청한다. 렌더 갱신 신호는 서명으로 걸러낸다.
	for other in _관찰대상:
		if not is_instance_valid(other):
			continue
		for event in ["points_modified", "item_rect_changed", "visibility_changed", "마감_배치변경"]:
			if other.has_signal(event) and other.is_connected(event, _마감_요청):
				other.disconnect(event, _마감_요청)
	_관찰대상.clear()
	for other in get_parent().get_children():
		if other == self or not other is Node2D or not other.has_method("get_point_array"):
			continue
		_관찰대상.append(other as Node2D)
		for event in ["points_modified", "item_rect_changed", "visibility_changed", "마감_배치변경"]:
			if other.has_signal(event) and not other.is_connected(event, _마감_요청):
				other.connect(event, _마감_요청)

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
	for other in _관찰대상:
		if not other.is_visible_in_tree():
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
	var signature := hash([points, others, global_transform, 윗면표시, 옆면마감, shape_material.get_instance_id(),
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
	_마감_노드 = 마감_생성기.생성(self, points, others, 윗면표시, 옆면마감)
	for part in _마감_노드:
		# 생성물은 저장하지 않는다. owner를 변경하지 않아 씬 재로드 중복을 막는다.
		add_child(part)
		if not Engine.is_editor_hint():
			_셰이더들.append(part.material)
	if not Engine.is_editor_hint():
		_유니폼_갱신()
	마감_생성횟수 += 1

func _셰이더_만들기(source: Texture2D, quiet: bool = false, edge: bool = false) -> ShaderMaterial:
	var result := super._셰이더_만들기(source, quiet, edge)
	if result == null:
		return null
	result.shader = 선반_셰이더 if 석조선반 else 자연면_셰이더
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
