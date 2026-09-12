@tool
extends CharacterBody2D
## 색이 없는 무게 상자. 어느 플레이어든 밀 수 있고 압력 버튼을 계속 누를 수 있다.

@export_range(20.0, 600.0, 1.0) var 밀기_속도: float = 220.0
@export_range(0.0, 2400.0, 1.0) var 낙사_y: float = 1900.0

const 중력: float = 1200.0
const 최대_낙하속도: float = 1500.0
var _리스폰_월드좌표: Vector2 = Vector2.ZERO


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	add_to_group("박스")
	_리스폰_월드좌표 = global_position
	# 상자는 플레이어·지형과만 충돌한다. 버튼의 Area2D는 그룹으로 따로 감지한다.
	collision_layer = 1
	collision_mask = 1


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not is_on_floor():
		velocity.y = minf(velocity.y + 중력 * delta, 최대_낙하속도)
	else:
		velocity.y = 0.0
	move_and_slide()
	if global_position.y > 낙사_y:
		global_position = _리스폰_월드좌표
		velocity = Vector2.ZERO


## 색이 없는 물체라 플레이어색은 받기만 하고 판정에는 쓰지 않는다.
func 밀기(방향: float, _플레이어색: int) -> void:
	if 방향 == 0.0:
		return
	# 플레이어가 밀었는데 한 프레임 뒤에 움직이면 손맛이 끊기므로 즉시 짧게 이동한다.
	var 이동거리 := minf(밀기_속도 * get_physics_process_delta_time(), 14.0)
	move_and_collide(Vector2(signf(방향) * 이동거리, 0.0))
	velocity.x = 0.0


func 명중(_색: int, _월드좌표: Vector2) -> String:
	return "blocked"


func 되돌리기() -> bool:
	return false


func 현재색() -> int:
	return -1


func 반대색인가(_플레이어색: int) -> bool:
	return false


func _draw() -> void:
	draw_rect(Rect2(-48, -96, 96, 96), Color(0.28, 0.27, 0.25), true)
	draw_rect(Rect2(-48, -96, 96, 96), Color(0.68, 0.66, 0.60), false, 3.0)
	draw_line(Vector2(-42, -88), Vector2(42, -8), Color(0.14, 0.13, 0.12), 4.0)
	draw_line(Vector2(42, -88), Vector2(-42, -8), Color(0.14, 0.13, 0.12), 4.0)
