@tool
extends "res://scripts/스마트월드/웅덩이.gd"
## 기존 수심/낙하 받기/색 판정은 유지하고 선택된 웅덩이의 흰색 외관만 교체한다.
const WHITE_POOL = preload("res://scenes/장식/유체/흰물_디자인.tscn")
var _white_visual: Node2D
var _visual_state: Array = []
var _침수대상: Array[Node] = []
## 판정은 원래 홈 안에 두고 그림만 지형과 같은 원근 면으로 맞춘다.
var _원근수면 := false

## 오른쪽 경사로와 그림/물 접촉 판정을 일치시킨다.
@export var 오른쪽_안쪽폭: float = 0.0:
	set(value):
		오른쪽_안쪽폭 = maxf(0.0, value)
		if is_node_ready():
			_모양_갱신()

## ★[2026-10-03] 왼쪽 경사 — 도형님 2-1 흰 웅덩이 = 양쪽이 비스듬한 사다리꼴. 예전엔 오른쪽만 알아 왼쪽이 늘 수직이었다.
@export var 왼쪽_안쪽폭: float = 0.0:
	set(value):
		왼쪽_안쪽폭 = maxf(0.0, value)
		if is_node_ready():
			_모양_갱신()

func _모양_갱신() -> void:
	super._모양_갱신()
	var rectangle := get_node_or_null("모양") as CollisionShape2D
	if rectangle != null:
		rectangle.disabled = true
	var shape := get_node_or_null("PoolPolygonV2") as CollisionPolygon2D
	if shape == null:
		shape = CollisionPolygon2D.new()
		shape.name = "PoolPolygonV2"
		add_child(shape)
	var half := 크기.x * 0.5
	var inset := minf(오른쪽_안쪽폭, 크기.x * 0.75)
	# 왼쪽 경사는 오른쪽과 합쳐 바닥 폭이 남게(전체의 0.75 를 넘지 않게) 자른다.
	var left_inset := minf(왼쪽_안쪽폭, 크기.x * 0.75 - inset)
	var polygon := PackedVector2Array([Vector2(-half,-크기.y), Vector2(half,-크기.y), Vector2(half-inset,0), Vector2(-half+left_inset,0)])
	if shape.polygon != polygon:
		shape.polygon = polygon

func _ready() -> void:
	super._ready()
	_white_visual = WHITE_POOL.instantiate()
	_white_visual.name = "WhitePoolV2"
	_white_visual.set("형태", 3)
	# 승인된 하수도 수면만 교체하고 다른 챕터의 웅덩이는 유지한다.
	var stage: Node = self
	while stage != null:
		if stage.scene_file_path.begins_with("res://scenes/world_2_클로드/stage_"):
			_white_visual.set("웅덩이_전용셰이더", preload("res://shaders/sewer_pool_shallow.gdshader"))
			break
		stage = stage.get_parent()
	add_child(_white_visual)
	_외관_맞추기()
	# 형제 지형이 ready를 마친 후 한 번 수집한다. 매 프레임 지형 검색을 하지 않는다.
	call_deferred("_침수대상_찾기")

func _침수대상_찾기() -> void:
	if not is_inside_tree() or get_parent() == null:
		return
	var root := get_parent().get_parent()
	if root == null:
		return
	var terrain_root := root.get_node_or_null("지형")
	if terrain_root == null:
		return
	_침수대상.clear()
	for terrain in terrain_root.get_children():
		if terrain.has_method("침수마감_설정"):
			_침수대상.append(terrain)
		# 홈의 바닥 중앙을 실제 지형 점과 대조한다. 이름·스테이지 번호에 의존하지 않는다.
		if terrain.has_method("발_그림_깊이") and terrain.has_method("get_point_array"):
			var points: PackedVector2Array = terrain.get_point_array().get_tessellated_points()
			if Geometry2D.is_point_in_polygon(terrain.to_local(to_global(Vector2(0, 0.5))), points):
				_원근수면 = float(terrain.call("발_그림_깊이")) > 0.0
	_white_visual.set("원근_수면", _원근수면)
	queue_redraw()
	_침수마감_갱신()

func 물그림_다각형() -> PackedVector2Array:
	# 물 그림·침수 마감·플레이어 가림이 하나의 경계를 공유해야 가장자리에서 발이나 돌이 새지 않는다.
	var half := 크기.x * 0.5
	var right := minf(오른쪽_안쪽폭, 크기.x * 0.75)
	var left := minf(왼쪽_안쪽폭, 크기.x * 0.75 - right)
	if _원근수면:
		return PackedVector2Array([Vector2(-half - 18, -크기.y - 4), Vector2(half - 18, -크기.y - 4), Vector2(half, -크기.y + 18), Vector2(half - right, 18), Vector2(-half + left, 18), Vector2(-half, -크기.y + 18)])
	return PackedVector2Array([Vector2(-half, -크기.y), Vector2(half, -크기.y), Vector2(half - right, 0), Vector2(-half + left, 0)])

func 수면_그림깊이() -> float:
	# 낙수는 새 수면의 뒤·앞 경계(-4…18) 가운데인 +7px에 앉힌다.
	return 7.0 if _원근수면 else 0.0

func _침수마감_갱신() -> void:
	var polygon := PackedVector2Array()
	if 켜짐:
		# 넓은 사각형으로 주변 갓돌까지 지우지 않는다. 물이 실제 채운 사선 내부만 마감을 숨긴다.
		for point in 물그림_다각형():
			polygon.append(to_global(point))
	for terrain in _침수대상:
		if is_instance_valid(terrain):
			terrain.call("침수마감_설정", get_instance_id(), polygon)

func _exit_tree() -> void:
	# 물을 삭제하면 원래 마감이 복구된다. 다른 웅덩이가 가린 부분은 남긴다.
	for terrain in _침수대상:
		if is_instance_valid(terrain) and terrain.is_inside_tree():
			terrain.call("침수마감_설정", get_instance_id(), PackedVector2Array())

func _외관_맞추기() -> void:
	if not is_instance_valid(_white_visual):
		return
	var state: Array = [크기, 색, 켜짐, global_transform, 오른쪽_안쪽폭, 왼쪽_안쪽폭]
	if state == _visual_state:
		return
	_visual_state = state
	_white_visual.visible = 켜짐
	_white_visual.set("크기", 크기)
	_white_visual.set("웅덩이_오른쪽_안쪽폭", 오른쪽_안쪽폭)
	_white_visual.set("웅덩이_왼쪽_안쪽폭", 왼쪽_안쪽폭)
	_white_visual.set("웅덩이_색", 색)
	# 웅덩이는 바닥 원점, 새 수면은 윗면 원점이므로 수심만큼 올린다.
	_white_visual.position = Vector2(0.0, -크기.y)
	_침수마감_갱신()
	queue_redraw()

func _process(_delta: float) -> void:
	# 모든 색의 사선 수면을 셰이더로 그리므로 기존 직사각형 물결 재그리기는 생략한다.
	_외관_맞추기()

func _draw() -> void:
	# 사선 웅덩이를 직사각형 코드 그림으로 덮어 그리지 않는다.
	pass
