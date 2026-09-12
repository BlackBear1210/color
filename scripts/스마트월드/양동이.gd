@tool
extends CharacterBody2D
## ============================================================================
## 양동이 — 플레이어가 옆에서 밀어 물을 싣고, E로 지정한 출구에 비우는 이동 장치.
## ---------------------------------------------------------------------------
## `RigidBody2D` 대신 CharacterBody2D를 쓴 이유:
##   물리 질량에 따라 밀림이 매번 달라지면 퍼즐의 정답 위치를 재현할 수 없다.
##   Player가 옆면에 닿은 뒤 `밀기()`를 부르면 같은 물리 프레임에 짧게 움직인다.
## ============================================================================

## 이 값은 양동이를 처음 만들 때만 정한다. 총알 명중은 항상 blocked라 플레이 중 바뀌지 않는다.
@export_enum("검정", "흰색", "회색") var 색: int = ColorDefs.BLACK:
	set(v):
		색 = clampi(v, ColorDefs.BLACK, ColorDefs.GRAY)
		queue_redraw()

@export_group("밀기")
@export_range(20.0, 600.0, 1.0) var 밀기_속도: float = 185.0
@export_range(0.0, 2400.0, 1.0) var 낙사_y: float = 1900.0
## 채운 양동이를 발판으로 쓰는 구간은 켜고, 물을 운반해야 하는 구간은 끈다.
@export var 채운뒤_밀수없음: bool = true

@export_group("물 운반")
## 채워진 상태에서 E를 누르면 이 유체를 켠다. 비워 두면 E로 비울 수 없다.
@export var 배출_유체: NodePath
@export var 물참: bool = false:
	set(v):
		물참 = v
		queue_redraw()
@export_enum("검정", "흰색", "회색") var 물색: int = ColorDefs.GRAY:
	set(v):
		물색 = clampi(v, ColorDefs.BLACK, ColorDefs.GRAY)
		queue_redraw()
@export_group("")

const 중력: float = 1200.0
const 최대_낙하속도: float = 1500.0
const 마찰: float = 900.0
const 상호작용_거리: float = 100.0

var _리스폰_월드좌표: Vector2 = Vector2.ZERO
@onready var _물감지: Area2D = get_node_or_null("물감지") as Area2D


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	add_to_group("양동이")
	_리스폰_월드좌표 = global_position
	# 양동이는 플레이어·지형과만 충돌하고, 물은 자식 Area2D가 따로 감지한다.
	collision_layer = 1
	collision_mask = 1
	queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not is_on_floor():
		velocity.y = minf(velocity.y + 중력 * delta, 최대_낙하속도)
	else:
		velocity.y = 0.0
	velocity.x = move_toward(velocity.x, 0.0, 마찰 * delta)
	move_and_slide()
	_물_담기_검사()
	# 구멍에 빠진 양동이가 길을 영구히 막지 않도록, 자기 시작 위치로만 되돌린다.
	if global_position.y > 낙사_y:
		global_position = _리스폰_월드좌표
		velocity = Vector2.ZERO


## Player가 수평 충돌 뒤 호출한다. 비어 있어도 같은 색이면 바로 민다.
## 채운 뒤 고정 발판으로 설정한 경우에만, 물을 담은 뒤에는 움직이지 않는다.
func 밀기(방향: float, 플레이어색: int) -> void:
	if 방향 == 0.0 or not 밀_수_있나(플레이어색):
		return
	if 물참 and 채운뒤_밀수없음:
		return
	# 다음 프레임의 velocity만 바꾸면 충돌한 플레이어가 먼저 밀려나 "안 밀린다"고 느껴진다.
	# 그래서 한 물리 프레임 거리만 즉시 이동하고, 충돌한 벽/다른 양동이 앞에서는 멈춘다.
	var 이동거리 := minf(밀기_속도 * get_physics_process_delta_time(), 14.0)
	move_and_collide(Vector2(signf(방향) * 이동거리, 0.0))
	velocity.x = 0.0


## 양동이는 플레이어와 **정확히 같은 색**일 때만 민다.
## 회색 플레이어는 없으므로, 회색 양동이는 장식/장애물로만 쓰고 진행 기믹에는 두지 않는다.
func 밀_수_있나(플레이어색: int) -> bool:
	return 색 == 플레이어색


## 월드.gd가 E 입력을 전달할 수 있는 거리인가.
func 닿아있나(플레이어: Node2D) -> bool:
	return 플레이어 != null and global_position.distance_to(플레이어.global_position) <= 상호작용_거리


## 물을 실었을 때만 지정된 출구 유체에 그 색을 넘긴다.
## 반환값은 월드가 E를 소비할지(성공) 평소 회수로 넘길지(실패) 결정하는 데 쓴다.
func 비우기() -> bool:
	if not 물참 or 배출_유체.is_empty():
		return false
	var 출구 := get_node_or_null(배출_유체) as 유체
	if 출구 == null:
		push_warning("[양동이:%s] 배출_유체 경로(%s)에서 유체를 못 찾음" % [name, 배출_유체])
		return false
	출구.색 = 물색
	출구.켜짐 = true
	물참 = false
	queue_redraw()
	return true


## 양동이 물감지 영역에 닿은 켜진 물 중 **양동이와 같은 색**만 싣는다.
## 유체 자체는 소비하지 않는다. 반대색/회색 물은 양동이를 채우지 못한다.
func _물_담기_검사() -> void:
	if 물참 or _물감지 == null:
		return
	for 영역 in _물감지.get_overlapping_areas():
		var 물 := 영역 as 유체
		if 물 != null and 물.켜짐 and 물.종류 == 유체.종류_.물 and 물.색 == 색:
			물참 = true
			물색 = 물.색
			queue_redraw()
			return


## 페인트 총의 대상이 되지 않는 기계 장치다. 색은 "밀기 조건"일 뿐 사망 판정용 색이 아니다.
func 명중(_색: int, _월드좌표: Vector2) -> String:
	return "blocked"


func 되돌리기() -> bool:
	return false


func 현재색() -> int:
	return 색


func 반대색인가(_플레이어색: int) -> bool:
	return false


func _draw() -> void:
	var 몸색 := Color(0.32, 0.33, 0.36)
	if 색 == ColorDefs.BLACK:
		몸색 = Color(0.12, 0.13, 0.15)
	elif 색 == ColorDefs.WHITE:
		몸색 = Color(0.78, 0.79, 0.82)
	# 바닥 원점 기준: 몸통은 위로, 손잡이는 더 위로 그려 플레이어가 올라설 면을 분명히 한다.
	draw_rect(Rect2(-46.0, -100.0, 92.0, 94.0), 몸색)
	draw_line(Vector2(-46.0, -6.0), Vector2(46.0, -6.0), Color(0.68, 0.69, 0.72), 4.0)
	draw_arc(Vector2(0.0, -98.0), 34.0, PI, TAU, 20, Color(0.68, 0.69, 0.72), 5.0)
	if 물참:
		var 액체색 := Color(0.12, 0.13, 0.15) if 물색 == ColorDefs.BLACK else Color(0.88, 0.90, 0.94)
		if 물색 == ColorDefs.GRAY:
			액체색 = Color(0.48, 0.50, 0.54)
		draw_rect(Rect2(-39.0, -82.0, 78.0, 17.0), Color(액체색.r, 액체색.g, 액체색.b, 0.88))
