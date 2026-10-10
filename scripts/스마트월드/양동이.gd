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
## ★[2026-09-21 Claude · 2-6] 비우기를 **이 자리 근처에서만** 받는다. 비워 두면 예전처럼 어디서든 비운다.
##   왜: `비우기()` 는 양동이가 어디 있든 `배출_유체` 를 켰다 — 물을 받자마자 그 자리에서 E 를 누르면 끝이라
##   "실어 나른다" 가 성립하지 않았다(2-6 「무거운 것」 이 산책이 된 원인 중 하나). 배출구(관 입구)를 지정하면
##   양동이가 그 안(`배출_거리`)에 있을 때만 비워진다. 2-7 의 양동이는 이 값을 안 써서 동작이 안 바뀐다.
@export var 배출_지점: NodePath
@export_range(40.0, 600.0, 1.0) var 배출_거리: float = 140.0
## 가득 찼나. 씬·주행검사·압력버튼이 읽는 값이라 이름을 안 바꾼다.
## ★[2026-09-30] 켜고 끄면 `수위` 도 1 / 0 으로 맞춘다(에디터에서 켜 두면 가득 찬 그림으로 보인다).
@export var 물참: bool = false:
	set(v):
		물참 = v
		수위 = 1.0 if v else 0.0
		queue_redraw()
## ★[2026-09-30 Claude] 빈 양동이가 가득 차기까지 걸리는 시간(초).
##   왜: 도형님 "양동이 안에 물이 차는 걸 보고 싶다" — 예전엔 물에 닿는 순간 한 프레임에 가득 찼다.
##   물을 받는 동안은 그 자리에 **붙잡혀** 안 밀린다(`밀기()`). 그래서 양동이가 서는 자리는 예전과 같고,
##   2-6·2-7·2-8 맵은 그대로 둔 채 "채워지는 시간" 만 늘었다. 쏴서 채우기는 없다(도형님 결정 · 총알은 여전히 blocked).
@export_range(0.1, 5.0, 0.05) var 채움_시간: float = 1.0
@export_enum("검정", "흰색", "회색") var 물색: int = ColorDefs.GRAY:
	set(v):
		물색 = clampi(v, ColorDefs.BLACK, ColorDefs.GRAY)
		queue_redraw()
## ★[2026-10-08 Claude · 2-5] 페인트를 쏘면 그 색으로 가득 찬다(무게추가 된다) · E 회수로 비운다.
##   왜: 2-5 도면 "발판_1 에 색을 채운 양동이를 밀어 올려두면 … 양동이에 있는 페인트를 회수하면 양동이는 가벼워져서
##   발판의 홀드가 풀린다" — 가운데 방에는 물줄기가 없어 페인트로 채워야 한다.
##   09-30 "쏴서 채우기 없음" 은 물 양동이 규칙이라 **이 값을 켠 양동이만** 바뀐다(기본 끔 → 2-6·2-7·2-8 그대로).
##   채운 페인트는 페인트 코어의 회수줄에 들어간다 → E 회수(FIFO)·사망 리셋 때 `되돌리기()` 로 빈다.
@export var 페인트로_채움: bool = false
@export_group("")

const 중력: float = 1200.0
const 최대_낙하속도: float = 1500.0
const 마찰: float = 900.0
const 상호작용_거리: float = 100.0
const 접지그림 = preload("res://scripts/스마트월드/이동물체_접지그림.gd")
var _그림보정 := 0.0
var _바닥깊이 := 0.0

var _리스폰_월드좌표: Vector2 = Vector2.ZERO
## 0 = 빔 · 1 = 가득. 가득 차면 `물참` 이 켜진다. 물줄기가 도중에 꺼지면 그 높이에서 멈춘다.
var 수위: float = 0.0
## 이번 물리 프레임에 같은 색 물을 받고 있나 — 받는 동안은 안 밀린다.
var _물받는중: bool = false
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
	# 몸통 충돌 바닥(-6)과 유리 들통 밑테를 같은 상판 중앙에 둔다. 물 그림도 함께 이동한다.
	var 접지 := 접지그림.보정(self, -6.0, _바닥깊이)
	_바닥깊이 = 접지.y
	if not is_equal_approx(_그림보정, 접지.x):
		_그림보정 = 접지.x
		queue_redraw()
	_물_담기_검사(delta)
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
	# ★[2026-09-30] 물을 받는 중에는 붙잡힌다 — 예전에 "닿자마자 가득" 이던 그 자리에 서서 차오른다.
	#   안 붙잡으면 미는 속도(185)로 물줄기를 0.5 초 만에 지나쳐 반만 찬 채 벽까지 밀려 가, 맵의 굳는 자리가 어긋난다.
	if _물받는중 and not 물참:
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


## 배출구 안에 있나 — 주행검사·HUD 가 "여기서 E 가 먹히나" 를 물을 때 쓴다.
func 배출구_안인가() -> bool:
	if 배출_지점.is_empty():
		return true
	var 지점 := get_node_or_null(배출_지점) as Node2D
	return 지점 == null or global_position.distance_to(지점.global_position) <= 배출_거리


## 물을 실었을 때만 지정된 출구 유체에 그 색을 넘긴다.
## 반환값은 월드가 E를 소비할지(성공) 평소 회수로 넘길지(실패) 결정하는 데 쓴다.
func 비우기() -> bool:
	if not 물참 or 배출_유체.is_empty():
		return false
	if not 배출_지점.is_empty():
		var 지점 := get_node_or_null(배출_지점) as Node2D
		if 지점 != null and global_position.distance_to(지점.global_position) > 배출_거리:
			return false          # 배출구에서 멀다 — E 는 평소 회수로 넘어간다
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
func _물_담기_검사(delta: float) -> void:
	var 받는중 := false
	if not 물참 and _물감지 != null:
		for 영역 in _물감지.get_overlapping_areas():
			var 물 := 영역 as 유체
			if 물 != null and 물.켜짐 and 물.종류 == 유체.종류_.물 and 물.색 == 색:
				받는중 = true
				물색 = 물.색
				break
	_물받는중 = 받는중
	if not 받는중:
		return
	# ★[2026-09-30] 한 번에 가득이 아니라 `채움_시간` 에 걸쳐 차오른다. 가득 차는 순간에만 물참을 켠다
	#   (물참 setter 가 수위를 1 로 맞추므로 순서가 바뀌어도 값은 같다).
	수위 = minf(1.0, 수위 + delta / maxf(채움_시간, 0.01))
	if 수위 >= 1.0:
		물참 = true
		_물받는중 = false
	queue_redraw()          # 차오르는 동안만 다시 그린다(가만히 있을 땐 안 그린다 — 프레임 드랍 재발 방지 규칙)


## 페인트 총의 대상이 되지 않는 기계 장치다. 색은 "밀기 조건"일 뿐 사망 판정용 색이 아니다.
## ★[2026-10-08] `페인트로_채움` 이 켜진 양동이만 예외 — 빈 양동이에 맞으면 그 색으로 가득 찬다("painted" → 회수줄).
##   이미 차 있으면 "wasted"(환급) — 반대색으로 덮어 다시 칠하는 규칙은 두지 않는다(무게는 색과 상관없다).
func 명중(색_: int, _월드좌표: Vector2) -> String:
	if not 페인트로_채움:
		return "blocked"
	if 물참:
		return "wasted"
	물색 = 색_
	물참 = true
	return "painted"


## 페인트 코어가 E 회수·사망 리셋 때 부른다. 페인트로 채운 양동이만 비울 수 있다(물 양동이는 그대로 false).
func 되돌리기() -> bool:
	if not 페인트로_채움 or not 물참:
		return false
	물참 = false
	return true


func 현재색() -> int:
	return 색


func 반대색인가(_플레이어색: int) -> bool:
	return false


## ★[2026-09-30 Claude] 쇠살 유리 들통(시안 A 확정). 그림 = `tools/생성_양동이_유리.py` 가 굽는 아틀라스(손으로 그리지 말 것).
##   아틀라스는 색마다 두 겹 — 뒤(유리) · 앞(쇠살·테·광택·손잡이). **물은 두 겹 사이에 코드로 그린다** — 수위가 실시간으로 변하니까.
##   preload 가 아니라 load: PNG 가 아직 임포트 안 됐으면 preload 는 스크립트 전체를 파싱 실패시켜 양동이가 사라진다.
const 유리_그림_경로 := "res://assets/textures/obstacles/bucket/glass_v1/bucket_atlas.png"
const 칸_크기 := Vector2(150.0, 170.0)
const 칸_원점 := Vector2(75.0, 160.0)           # 칸 안에서 노드 원점(바닥 중앙)
const 몸_위 := -100.0                             # 몸통 위(입구) y · 반폭 47
const 몸_아래 := -8.0                             # 몸통 아래 y · 반폭 39
const 몸_위_반폭 := 47.0
const 몸_아래_반폭 := 39.0
static var _유리_그림: Texture2D = null

## 켜면 예전 코드 그림(사각형 + 물 띠)으로 돌아간다 — 비교·문제 확인용.
@export var 옛_그림: bool = false:
	set(v):
		옛_그림 = v
		queue_redraw()


func _물_색(c: int) -> Color:
	if c == ColorDefs.BLACK:
		return Color(0.05, 0.05, 0.06)
	if c == ColorDefs.WHITE:
		return Color(0.93, 0.95, 0.97)
	return Color(0.50, 0.52, 0.55)


func _반폭(y: float) -> float:
	return 몸_위_반폭 + (몸_아래_반폭 - 몸_위_반폭) * (y - 몸_위) / (몸_아래 - 몸_위)


## 얇은 타원 점들 — Godot 에 타원 그리기가 없어서 직접 만든다. 앞(아래) 반쪽만 원하면 `앞만`.
func _타원점(cy: float, rx: float, ry: float, 앞만: bool) -> PackedVector2Array:
	var 점 := PackedVector2Array()
	var n := 24
	for i in n + 1:
		var t := (PI * float(i) / n) if 앞만 else (TAU * float(i) / n)
		점.append(Vector2(rx * cos(t), cy + ry * sin(t)))
	return 점


func _유리_그리기() -> void:
	var 열 := float(clampi(색, 0, 2)) * 칸_크기.x
	var 자리 := Rect2(-칸_원점, 칸_크기)
	draw_texture_rect_region(_유리_그림, 자리, Rect2(Vector2(열, 0.0), 칸_크기))            # 뒤 겹(유리)
	var 물 := _물_색(물색)
	var 밝은선 := Color(0.95, 0.96, 0.98, 0.85) if 물색 != ColorDefs.WHITE else Color(0.55, 0.57, 0.60, 0.85)
	# 차오르는 동안 수면이 살짝 출렁인다(받는 중일 때만 — 가만히 있을 땐 안 움직인다)
	var 출렁: float = sin(Time.get_ticks_msec() * 0.018) * 1.2 if _물받는중 else 0.0
	if 수위 > 0.0 and 수위 < 1.0:
		var 바닥 := 몸_아래 - 4.0
		var 수면 := 바닥 - 수위 * (몸_아래 - 몸_위 - 10.0)
		var 윗폭 := _반폭(수면) - 3.0
		var 아랫폭 := 몸_아래_반폭 - 3.0
		var 속 := Color(물.r * 0.75, 물.g * 0.75, 물.b * 0.75, 0.93)      # 깊을수록 조금 어둡다
		var 위색 := Color(물.r, 물.g, 물.b, 0.93)
		draw_polygon(PackedVector2Array([Vector2(-윗폭, 수면), Vector2(윗폭, 수면), Vector2(아랫폭, 바닥), Vector2(-아랫폭, 바닥)]),
			PackedColorArray([위색, 위색, 속, 속]))
		draw_colored_polygon(_타원점(수면, 윗폭, 3.2 + 출렁 * 0.5, false), Color(물.r * 0.85 + 0.06, 물.g * 0.85 + 0.06, 물.b * 0.85 + 0.06))
		# 수면 앞 가장자리 밝은 선 — 검은 물도 높이가 읽히게(시안 A 의 핵심)
		draw_polyline(_타원점(수면, 윗폭, 3.2 + 출렁 * 0.5, true), 밝은선, 1.3, true)
	elif 물참:
		var 바닥 := 몸_아래 - 4.0
		var 아랫폭 := 몸_아래_반폭 - 3.0
		var 윗폭 := 몸_위_반폭 - 3.0
		draw_polygon(PackedVector2Array([Vector2(-윗폭, 몸_위 + 1.5), Vector2(윗폭, 몸_위 + 1.5), Vector2(아랫폭, 바닥), Vector2(-아랫폭, 바닥)]),
			PackedColorArray([Color(물, 0.93), Color(물, 0.93), Color(물.r * 0.75, 물.g * 0.75, 물.b * 0.75, 0.93), Color(물.r * 0.75, 물.g * 0.75, 물.b * 0.75, 0.93)]))
	draw_texture_rect_region(_유리_그림, 자리, Rect2(Vector2(열, 칸_크기.y), 칸_크기))      # 앞 겹(쇠살·테·손잡이)
	if 물참:
		# 가득 = 입구까지 찬 수면 + 앞으로 넘친 물 한 줄
		draw_colored_polygon(_타원점(몸_위 + 1.5, 몸_위_반폭 - 4.0, 3.9, false), 물)
		draw_polyline(_타원점(몸_위 + 1.5, 몸_위_반폭 - 4.0, 3.9, true), 밝은선, 1.3, true)
		draw_polyline(PackedVector2Array([Vector2(20.0, 몸_위 + 4.0), Vector2(21.0, 몸_위 + 16.0), Vector2(20.5, 몸_위 + 22.0)]), 물, 2.4, true)
		draw_circle(Vector2(20.5, 몸_위 + 23.0), 2.2, 물)


func _draw() -> void:
	# 자식 물감지와 충돌은 그대로 두고, 뒤 유리·내용물·쇠살의 그리기 원점만 같은 만큼 옮긴다.
	draw_set_transform(Vector2(0, _그림보정))
	if not 옛_그림:
		if _유리_그림 == null and ResourceLoader.exists(유리_그림_경로):
			_유리_그림 = load(유리_그림_경로) as Texture2D
		if _유리_그림 != null:
			_유리_그리기()
			return
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

func 발_그림_깊이() -> float:
	# 채운 양동이를 밟을 때도 플레이어 발이 이동한 입구 그림의 중앙을 따르게 한다.
	return _그림보정
