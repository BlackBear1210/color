@tool
extends "res://scripts/스마트월드/웅덩이.gd"
## 기존 수심/낙하 받기/색 판정은 유지하고 선택된 웅덩이의 흰색 외관만 교체한다.
const WHITE_POOL = preload("res://scenes/장식/유체/흰물_디자인.tscn")
var _white_visual: Node2D
var _visual_state: Array = []
var _침수대상: Array[Node] = []

## 오른쪽 경사로와 그림/물 접촉 판정을 일치시킨다.
@export var 오른쪽_안쪽폭: float = 0.0:
	set(value):
		오른쪽_안쪽폭 = maxf(0.0, value)
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
	var polygon := PackedVector2Array([Vector2(-half,-크기.y), Vector2(half,-크기.y), Vector2(half-inset,0), Vector2(-half,0)])
	if shape.polygon != polygon:
		shape.polygon = polygon

func _ready() -> void:
	super._ready()
	_white_visual = WHITE_POOL.instantiate()
	_white_visual.name = "WhitePoolV2"
	_white_visual.set("형태", 3)
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
	_침수마감_갱신()

func _침수마감_갱신() -> void:
	var polygon := PackedVector2Array()
	if 켜짐:
		# 바닥 24px, 옆면 18px 마감 두께까지 포함하되 수면 위는 가리지 않는다.
		var left := -크기.x * 0.5 - 19.0
		var right := 크기.x * 0.5 + 19.0
		for point in [Vector2(left, -크기.y), Vector2(right, -크기.y), Vector2(right, 25.0), Vector2(left, 25.0)]:
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
	var state: Array = [크기, 색, 켜짐, global_transform, 오른쪽_안쪽폭]
	if state == _visual_state:
		return
	_visual_state = state
	_white_visual.visible = 켜짐
	_white_visual.set("크기", 크기)
	_white_visual.set("웅덩이_오른쪽_안쪽폭", 오른쪽_안쪽폭)
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
