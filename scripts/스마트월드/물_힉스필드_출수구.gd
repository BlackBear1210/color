@tool
extends Node2D
## 지형 안에 들어가는 출수구만 그려 배관·물·지형의 접점을 일치시킨다.
const VISUAL = preload("res://scripts/스마트월드/물_힉스필드_삼색프레임.gd")
@export var 대상_유체: NodePath
var _water: Node2D
var _pipe: Texture2D
var _support := Rect2()
var _support_valid := false
var _fit_position := Vector2(INF, INF)
var _fit_width := -1.0
func _ready() -> void:
	_water = get_node_or_null(대상_유체) as Node2D
	# 꺼진 배관의 회색 물 잔재·네모 꼬리를 없앤 빈 입구를 쓴다. 물은 아래 별도 층으로만 표시한다.
	_pipe = VISUAL.read_texture(VISUAL.ASSET_DIR + "pipe_joint_dry_v2.png")
	z_index = 5
	_update()
func _process(_delta: float) -> void:
	_update()
func _terrain_polygons(node: Node, result: Array[PackedVector2Array]) -> void:
	# 지형 대신 장식의 크기를 바꾼다. SS2D 원본 점을 읽기만 하고 충돌·owner는 수정하지 않는다.
	if node is Node2D and node.has_method("get_point_array"):
		var points: Resource = node.call("get_point_array")
		if points != null and (node as Node2D).is_visible_in_tree():
			var polygon := PackedVector2Array()
			for point in points.call("get_tessellated_points"):
				polygon.append(to_local((node as Node2D).to_global(point)))
			if polygon.size() >= 3:
				result.append(polygon)
	for child in node.get_children():
		_terrain_polygons(child, result)

func _span(polygon: PackedVector2Array, y: float) -> Vector2:
	# 오목한 지형은 바운딩 박스로 재면 허공까지 포함되므로 실제 가로 단면을 사용한다.
	var hits: Array[float] = []
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		if (a.y <= y and y < b.y) or (b.y <= y and y < a.y):
			hits.append(lerpf(a.x, b.x, (y - a.y) / (b.y - a.y)))
	hits.sort()
	for i in range(0, hits.size() - 1, 2):
		if hits[i] <= 0.0 and hits[i + 1] >= 0.0:
			return Vector2(hits[i], hits[i + 1])
	return Vector2.ZERO

func _fit_terrain(width: float) -> void:
	# 물의 원점에 바로 닿은 지형만 고른다. 멀리 있는 천장에 장식을 붙여 물과 떨어뜨리지 않는다.
	_support_valid = false
	var scene := self as Node
	while scene.get_parent() != null and not scene.has_node("지형"):
		scene = scene.get_parent()
	var terrain := scene.get_node_or_null("지형")
	if terrain == null:
		return
	var polygons: Array[PackedVector2Array] = []
	_terrain_polygons(terrain, polygons)
	for polygon in polygons:
		if not Geometry2D.is_point_in_polygon(Vector2(0.0, -2.0), polygon):
			continue
		var half_width := maxf(width * 0.5 + 12.0, width / .42 * .5) if width < 160.0 else width * .5 + 12.0
		var depth := 0.0
		# 가장자리·모따기까지 안으로 들어가도록 매 단면의 좁은 쪽을 택한다.
		for step in range(2, 363, 2):
			var span := _span(polygon, -float(step))
			var available := minf(-span.x, span.y) - 2.0
			if available < width * 0.5 + 2.0:
				break
			half_width = minf(half_width, available)
			depth = float(step)
		if depth >= 8.0 and depth > _support.size.y:
			_support = Rect2(-half_width, -depth, half_width * 2.0, depth)
			_support_valid = true
func _update() -> void:
	_water = get_node_or_null(대상_유체) as Node2D
	if is_instance_valid(_water) and not bool(_water.get("켜짐")):
		# 같은 자리의 교대 물은 현재 켜진 물의 색을 연결부에 표시한다.
		for candidate in _water.get_parent().get_children():
			if candidate is Node2D and "힉스필드_삼색프레임" in candidate and bool(candidate.get("켜짐")):
				if candidate.global_position.is_equal_approx(_water.global_position):
					_water = candidate
					break
	if not is_instance_valid(_water):
		return
	global_position = _water.global_position
	var water_size: Vector2 = _water.get("크기")
	if not _fit_position.is_equal_approx(global_position) or not is_equal_approx(_fit_width, water_size.x) or Engine.is_editor_hint():
		_support = Rect2()
		_fit_terrain(water_size.x)
		_fit_position = global_position
		_fit_width = water_size.x
		_restore_connection()
	# 원본 출수 폭과 본체 폭을 일치시켜 관 아래에서 갑자기 벌어지는 어깨를 없앤다.
	var main_visual := _water.get_node_or_null("WhiteWaterV2") as CanvasItem
	if main_visual != null and main_visual.material is ShaderMaterial:
		var body_material := main_visual.material as ShaderMaterial
		body_material.set_shader_parameter("inlet_ratio", 1.0)
		body_material.set_shader_parameter("inlet_height", 40.0)
	var size: Vector2 = _water.get("크기")
	var enabled := bool(_water.get("켜짐"))
	if main_visual != null and main_visual.has_method("배관입구_설정"):
		var depth := _pipe_diameter(size.x) * .36 if _round_pipe(size.x) else _slot_depth()
		# 지형 안의 고정 입구에서 출발하도록 본체와 입구가 같은 깊이·재질을 사용한다.
		if _water.has_method("배관_선두설정"):
			_water.call("배관_선두설정", depth)
		main_visual.call("배관입구_설정", depth, _그림_층(), enabled)
	queue_redraw()

func _restore_connection() -> void:
	# 원래부터 천장과 떨어져 밸브 관으로 공급되는 물은 기존 연결관을 복원해 허공 출수를 막는다.
	for node in _water.get_parent().get_children():
		if node is Node2D and "끝_장치" in node and "점들" in node:
			var target: NodePath = node.get("끝_장치")
			if not target.is_empty() and node.get_node_or_null(target) == get_node_or_null(대상_유체):
				node.visible = not _support_valid
func _그림_층() -> int:
	# 부모의 상대 z값까지 합쳐 입구 물만 배관 테두리 앞에 놓는다. 낙수 본체의 층은 보존한다.
	var layer := 0
	var item: Node = self
	while item != null:
		if item is CanvasItem:
			var canvas_item := item as CanvasItem
			layer += canvas_item.z_index
			if not canvas_item.z_as_relative:
				break
		item = item.get_parent()
	return clampi(layer + 1, -4096, 4096)

func _draw_pipe(rect: Rect2) -> void:
	# 정적인 입구 물 덧그림을 제거했다. 같은 프레임 재질의 입구 자식이 물을 그린다.
	draw_texture_rect(_pipe, rect, false)
func _pipe_diameter(width: float) -> float:
	return minf(clampf(width / .42, 56.0, 360.0), minf(_support.size.x, _support.size.y - 2.0))

func _round_pipe(width: float) -> bool:
	# 원형 관의 출수 폭을 수용할 두께가 없으면 억지로 축소하지 않고 얕은 배수구를 쓴다.
	return _support_valid and width < 160.0 and _pipe_diameter(width) >= width / .42

func _slot_depth() -> float:
	return minf(24.0, maxf(_support.size.y - 4.0, 0.0)) if _support_valid else 0.0

func _draw_slot(width: float) -> void:
	# 수조 원본의 검은 배경·옆 기둥 대신 주철 테의 내부 조각만 쓴다. 외곽은 지형 안에서 끝난다.
	var depth := _slot_depth()
	var half_width := minf(width * .5 + 6.0, _support.size.x * .5)
	# 원본은 1280px이므로 고정 픽셀 좌표로 자르면 투명·검은 바깥 여백이 다시 섞인다.
	var texture_size := _pipe.get_size()
	var source := Rect2(texture_size * Vector2(.40, .10), texture_size * Vector2(.20, .035))
	var border := minf(3.0, depth * .25)
	# 검은 관 속은 테 안에만 둔다. 물이 꺼졌을 때에도 벽 위 물자국이 아니라 실제 입구로 읽힌다.
	draw_rect(Rect2(-half_width + border, -depth + border, half_width * 2.0 - border * 2.0, depth - border), Color(.025, .025, .025))
	# 영역 그리기는 일반 사각형 그리기와 달리 텍스처·목적 사각형·원본 영역 순서로 전달한다.
	draw_texture_rect_region(_pipe, Rect2(-half_width, -depth, half_width * 2.0, border), source)
	for side in [-1.0, 1.0]:
		var x := -half_width if side < 0.0 else half_width - border
		draw_texture_rect_region(_pipe, Rect2(x, -depth, border, depth), source)
func _draw() -> void:
	if not is_instance_valid(_water) or _pipe == null or not _support_valid:
		return
	var size: Vector2 = _water.get("크기")
	if _round_pipe(size.x):
		## 원본 출수 폭은 배관 지름의 약 42%다. 이 비례를 맞춰 양옆 턱과 급격한 벌어짐을 없앤다.
		var diameter := _pipe_diameter(size.x)
		# 관의 아랫변을 지형 하단(물 원점)에 붙여 이전의 10% 돌출을 없앤다.
		_draw_pipe(Rect2(-diameter*.5, -diameter, diameter, diameter))
	else:
		_draw_slot(size.x)
