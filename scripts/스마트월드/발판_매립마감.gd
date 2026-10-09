@tool
extends Node2D
## 고정 프레임에 겹친 돌 덮개만 걷어낸다. 기존 지형의 침수 차집합 API를 공유해 충돌을 바꾸지 않는다.
const 원근그림 = preload("res://scripts/스마트월드/발판_원근그림.gd")
var _지형들: Array[Node2D] = []
var _서명: int = 0
var _갱신필요 := true

func _ready() -> void:
	var button := get_parent() as Node2D
	if button == null or button.get_parent() == null:
		return
	var stage := button.get_parent().get_parent()
	if stage == null:
		return
	# 스테이지의 지형/장치 안에서 마감 API가 있는 노드만 한 번 모은다. 프레임마다 전체 트리를 찾지 않는다.
	for node in stage.find_children("*", "", true, false):
		if node is Node2D and node.has_method("침수마감_설정"):
			_지형들.append(node as Node2D)
			if node.has_signal("마감_배치변경"):
				node.connect("마감_배치변경", _이웃변경)
	_갱신()

func _이웃변경(_node: Node2D) -> void:
	_갱신필요 = true

func _process(_delta: float) -> void:
	_갱신()

func _갱신() -> void:
	var button := get_parent() as Node2D
	if button == null:
		return
	var width := float(button.get("폭"))
	var height := float(button.get("높이"))
	# 그림 생성보다 돌 차집합이 먼저 적용되면 버튼 자리만 뚫린다. 준비된 그림에만 마감을 맞춘다.
	var enabled := button.has_method("원근_그림_준비됨") and bool(button.call("원근_그림_준비됨"))
	var signature := hash([button.global_transform, width, height,
		enabled, button.is_visible_in_tree()])
	if signature == _서명 and not _갱신필요:
		return
	_서명 = signature
	_갱신필요 = false
	var polygon := PackedVector2Array()
	var bounds := Rect2()
	if enabled and button.is_visible_in_tree():
		# 금속 안쪽 0.6px까지 돌을 남겨 필터링 때문에 두 재질 사이에 검은 틈이 벌어지지 않게 한다.
		var inset := Geometry2D.offset_polygon(원근그림.윤곽(width, height), -0.6)
		if not inset.is_empty():
			for point in inset[0]:
				polygon.append(button.to_global(point))
			bounds = Rect2(polygon[0], Vector2.ZERO)
			for point in polygon:
				bounds = bounds.expand(point)
	for terrain in _지형들:
		if not is_instance_valid(terrain):
			continue
		var intersects := not polygon.is_empty() and terrain.has_method("월드경계") and bounds.intersects(terrain.call("월드경계"), true)
		# 같은 도형은 지형 API가 거른다. 버튼 눌림 애니메이션은 고정 프레임의 마감을 다시 만들지 않는다.
		terrain.call("침수마감_설정", get_instance_id(), polygon if intersects else PackedVector2Array())

func _exit_tree() -> void:
	# 발판이 숨거나 제거되면 잘라 둔 돌 마감이 복원되어 구멍이 남지 않는다.
	for terrain in _지형들:
		if is_instance_valid(terrain):
			terrain.call("침수마감_설정", get_instance_id(), PackedVector2Array())
			if terrain.has_signal("마감_배치변경") and terrain.is_connected("마감_배치변경", _이웃변경):
				terrain.disconnect("마감_배치변경", _이웃변경)
