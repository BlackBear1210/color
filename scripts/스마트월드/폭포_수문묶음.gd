@tool
extends Node2D
## 기존 원형 레버의 `켜짐` 계약으로 여러 폭포와 수문 하나를 함께 제어한다.
## 물 색만 바꿔 폭포를 통과해도 닫힌 수문은 남으므로 밸브를 잠그는 목적이 유지된다.

@export var 유체들: Array[NodePath] = []
@export var 수문: NodePath
@export var 열림_이동량: Vector2 = Vector2(0, -640)
@export_range(40.0, 1200.0) var 수문_속도: float = 400.0
@export var 켜짐: bool = true:
	set(v):
		켜짐 = v
		if is_node_ready() and not Engine.is_editor_hint():
			_물_반영()

var _문: Node2D
var _닫힌위치: Vector2


func _ready() -> void:
	# 에디터에서는 물과 문을 움직이지 않고 배치된 초기 모습만 보여준다.
	set_physics_process(not Engine.is_editor_hint())
	if Engine.is_editor_hint():
		return
	_문 = get_node_or_null(수문) as Node2D
	if _문:
		_닫힌위치 = _문.position
	_물_반영()


func _물_반영() -> void:
	for 경로 in 유체들:
		var 물 := get_node_or_null(경로)
		if 물 != null and "켜짐" in 물:
			물.set("켜짐", 켜짐)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_instance_valid(_문):
		return
	# 독립 SS2D 문만 이동한다. 플레이어가 타는 다리는 기존 AnimatableBody2D를 쓴다.
	var 목표 := _닫힌위치 if 켜짐 else _닫힌위치 + 열림_이동량
	_문.position = _문.position.move_toward(목표, 수문_속도 * delta)
