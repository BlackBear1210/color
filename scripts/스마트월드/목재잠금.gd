@tool
extends Node2D
## 떨어진 방의 목재를 지정 색으로 칠하면 출구 빗장이 열린다.
## 완성한 장치는 장면 안에서 래치된다. 페인트 회수/사망으로 길이 닫혀 갇히는 일을 막는다.
## 장면을 다시 불러오면 초기화된다. 저장 게임의 영구 해금은 이 스크립트의 책임이 아니다.
@export var targets: Array[NodePath] = []
@export var required_colors: Array[int] = [1,0]
@export var gate: NodePath
var solved: Array[bool] = []
var opened: bool = false

func _ready() -> void:
	solved.resize(targets.size())
	solved.fill(false)
	set_physics_process(not Engine.is_editor_hint())
	queue_redraw()

func _physics_process(_delta:float) -> void:
	if opened or targets.is_empty() or targets.size()!=required_colors.size():
		return
	for i in targets.size():
		var target := get_node_or_null(targets[i])
		if target != null and target.has_method("현재색") and int(target.call("현재색"))==required_colors[i]:
			solved[i] = true
	if solved.all(func(v:bool)->bool: return v):
		var door := get_node_or_null(gate) as Node2D
		if door != null:
			# 물리 순회 도중 충돌을 바꾸지 않는다. 시각/물리 해제는 같은 deferred 호출로 묶는다.
			call_deferred("_open",door)
			opened = true
	queue_redraw()

func _open(door:Node2D) -> void:
	for node in door.find_children("*","CollisionPolygon2D",true,false):
		(node as CollisionPolygon2D).disabled = true
	for node in door.find_children("*","CollisionShape2D",true,false):
		(node as CollisionShape2D).disabled = true
	door.visible = false

func _draw() -> void:
	# 두 잠금의 요구 색과 완료 상태를 출구에 표시한다. 새로운 아트/광원은 만들지 않는다.
	for i in required_colors.size():
		var at := Vector2(0, i*56)
		var ink := Color.WHITE if required_colors[i]==1 else Color(0.08,0.08,0.08)
		draw_circle(at,22,Color(0.5,0.5,0.5))
		draw_circle(at,17,ink)
		if i<solved.size() and solved[i]:
			draw_line(at+Vector2(-9,0),at+Vector2(-1,9),Color.WHITE,3)
			draw_line(at+Vector2(-1,9),at+Vector2(12,-9),Color.WHITE,3)
