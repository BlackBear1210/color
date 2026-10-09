@tool
extends Node2D
## 복도의 옆방은 E로 들어가는 배경 문이다. 이동 충돌을 만들지 않고 기존 전경전환·부활 계약을 사용한다.
@export_file("*.tscn") var 다음_씬: String = ""
@export var 다음_연결: String = "왼쪽"
@export var 표제: String = "옆방"
@export var 방향: int = 1
@export var 되돌아가기: bool = true
var _글꼴: Font

func _ready() -> void:
	z_index = -2
	_글꼴 = load("res://assets/fonts/NotoSerifKR/NotoSerifKR.ttf")
	if not Engine.is_editor_hint():
		add_to_group("상호작용")
	queue_redraw()

func 옆방_문인가() -> bool:
	return true

func 닿아있나() -> bool:
	var p := get_tree().get_first_node_in_group("player") as CharacterBody2D
	return p != null and p.is_on_floor() and p.is_physics_processing() and absf(p.global_position.x - global_position.x) < 66.0 and absf(p.global_position.y - global_position.y) < 24.0

func 조작() -> void:
	var p := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if 닿아있나() and not 다음_씬.is_empty():
		load("res://scripts/쳅터1/전경전환.gd").연결로_이동(self, p)

func 안쪽_위치() -> Vector2:
	return global_position

func 도착_위치() -> Vector2:
	return global_position

func 도착시킴() -> void:
	pass # E를 눌러야 다시 들어가므로 자동 왕복 판정이 생기지 않는다.

func _draw() -> void:
	# 배경 문은 지형보다 뒤에 둔다. 밝은 테와 어두운 단면으로 입체감·동선을 읽히게 한다.
	draw_rect(Rect2(-53, -154, 106, 158), Color(0.035, 0.035, 0.035))
	draw_rect(Rect2(-49, -150, 98, 150), Color(0.23, 0.23, 0.23), false, 4.0)
	draw_rect(Rect2(-42, -144, 84, 144), Color(0.09, 0.09, 0.09))
	for y in [-132.0, -70.0]:
		draw_rect(Rect2(-33, y, 66, 50), Color(0.17, 0.17, 0.17), false, 2.0)
	draw_circle(Vector2(29, -67), 4.0, Color(0.7, 0.7, 0.7))
	if _글꼴:
		draw_string(_글꼴, Vector2(-80, -169), 표제, HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(0.72, 0.72, 0.72))
		if not Engine.is_editor_hint() and 닿아있나():
			draw_string(_글꼴, Vector2(-65, -199), "E · 들어가기", HORIZONTAL_ALIGNMENT_CENTER, 130, 17, Color.WHITE)

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		queue_redraw()
