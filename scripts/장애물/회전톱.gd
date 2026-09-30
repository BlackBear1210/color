@tool
extends Area2D
## ============================================================================
## ⚙ 회전톱 (Rotating Saw)  —  [2026-07-24 도형 · 신규]
## ----------------------------------------------------------------------------
## 정해진 경로를 왕복하며 빙글빙글 도는 톱날. 닿으면 즉사.
##
## ▣ 쓰는 법
##   scenes/장애물/회전톱.tscn 을 드래그 → `이동거리`(0 이면 제자리 회전),
##   `이동방향`(가로/세로), `왕복시간`, `반지름` 만 조절.
##
## ▣ 레벨 디자인 규칙
##   · 톱은 "타이밍"을 요구한다. 색칠은 "판단"을 요구한다.
##     두 개를 동시에 요구하면 난이도가 곱셈으로 뛴다 → 스테이지 4 이후에만 겹친다.
##   · 왕복시간은 2.0초 이상. 그보다 빠르면 플레이어가 패턴을 읽기 전에 죽어
##     "불공정하다"는 느낌을 준다 (Celeste/Super Meat Boy 의 가독성 원칙).
## ============================================================================

const 공통 := preload("res://scripts/장애물/장애물_공통.gd")

## ★[2026-09-28] 주철 톱날 그림 + 벽 속 홈 경로(도형님 확정 시안 3).
##   흰 톱니바퀴 + 빨간 점은 벽돌·주철 세계에서 혼자 벡터 도형이라 튀었고 허공에 떠 있었다.
##   톱날은 tools/생성_톱_주철.py 가 호퍼 원화 재질로 반지름별 1:1 로 굽는다(손으로 그리지 말 것).
##   **판정(원, 반지름 × 0.72)은 그대로다.**
const 톱_그림_크기 := [24, 28, 32, 36, 40, 48]      # 도구의 SIZES 와 같아야 한다
const 톱_그림_경로 := "res://assets/textures/obstacles/saw/cast_iron_v1/saw_r%d.png"
const 멈춤쇠 = preload("res://assets/textures/obstacles/saw/cast_iron_v1/stop.png")

## 옛 그림(흰 톱니바퀴 + 빨간 점)으로 되돌린다. 비교·디버그용.
@export var 옛_그림: bool = false:
	set(v): 옛_그림 = v; queue_redraw()
## 왕복하는 톱의 길을 **벽 속 홈 + 양끝 멈춤쇠** 로 그린다. 튀어나온 쇠막대는 공중선반(발판)처럼 읽혀서 벽에 판 홈으로 했다.
## 홈 길이 = 왕복 범위 → 톱이 어디까지 오는지 미리 보인다.
@export var 경로_홈: bool = true:
	set(v): 경로_홈 = v; queue_redraw()

var _톱_그림: Texture2D

@export_range(8.0, 96.0) var 반지름: float = 26.0:
	set(v): 반지름 = v; _재구성()
## 왕복 이동 거리(px). 0 이면 제자리에서 회전만 한다.
@export_range(0.0, 800.0) var 이동거리: float = 0.0
## 0=가로 1=세로
@export_enum("가로", "세로") var 이동방향: int = 0
## 한 번 왕복(A→B→A)에 걸리는 시간(초)
@export_range(0.6, 12.0) var 왕복시간: float = 3.0
## 회전 속도(초당 라디안). 보이는 속도감만 담당 — 판정과 무관.
@export_range(0.5, 20.0) var 회전속도: float = 6.0

var _시작위치: Vector2
var _t: float = 0.0

func _ready() -> void:
	add_to_group("hazard")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	_시작위치 = position
	_톱_그림 = _가장_가까운_톱()
	_재구성()

## 반지름에 가장 가까운 크기의 그림 — 크게 줄여 그리면 계단이 생기므로 가까운 것을 살짝만 늘린다.
func _가장_가까운_톱() -> Texture2D:
	var 고른 := 40
	for r in 톱_그림_크기:
		if absf(float(r) - 반지름) < absf(float(고른) - 반지름):
			고른 = r
	return load(톱_그림_경로 % 고른) as Texture2D

func _재구성() -> void:
	if not is_inside_tree():
		return
	_톱_그림 = _가장_가까운_톱()
	for c in get_children():
		if c is CollisionShape2D:
			c.queue_free()
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	# 판정 반지름은 그림보다 살짝 작게 — "스칠 듯 말 듯 피했다"는 느낌을 만든다.
	# (실제 상업 플랫포머의 표준 기법: 판정을 관대하게)
	sh.radius = 반지름 * 0.72
	cs.shape = sh
	add_child(cs)
	queue_redraw()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	rotation += 회전속도 * delta
	if 이동거리 > 0.0:
		# 부드러운 왕복(사인) — 끝에서 감속해 패턴을 읽기 쉽게 한다
		var s := sin(_t / maxf(왕복시간, 0.1) * TAU) * 이동거리 * 0.5
		position = _시작위치 + (Vector2(s, 0) if 이동방향 == 0 else Vector2(0, s))
	queue_redraw()

func _draw() -> void:
	if not 옛_그림 and _톱_그림 != null:
		_주철_그리기()
		return
	# 톱날: 바깥 톱니 12개 + 안쪽 원판
	var 이빨 := 12
	var 점 := PackedVector2Array()
	for i in 이빨 * 2:
		var a := float(i) / float(이빨 * 2) * TAU
		var r := 반지름 if i % 2 == 0 else 반지름 * 0.72
		점.append(Vector2(cos(a), sin(a)) * r)
	공통.폴리곤_외곽선(self, 점, 공통.위험_코어, 공통.위험_외곽, 2.2)
	draw_circle(Vector2.ZERO, 반지름 * 0.30, 공통.위험_외곽)
	draw_circle(Vector2.ZERO, 반지름 * 0.14, 공통.위험_경고)


func _주철_그리기() -> void:
	if 경로_홈 and 이동거리 > 0.0:
		_홈_그리기()
	# 톱날 — 노드가 돌고 있으니 그냥 가운데에 그리면 같이 돈다. 그림 한 변 = 2 × 반지름 + 8(톱니 끝 = 반지름)
	var 그림_반지름 := (float(_톱_그림.get_width()) - 8.0) * 0.5
	var 배율 := 반지름 / 그림_반지름
	var 한변 := float(_톱_그림.get_width()) * 배율
	draw_texture_rect(_톱_그림, Rect2(Vector2(-한변, -한변) * 0.5, Vector2(한변, 한변)), false)

## 홈은 벽에 파인 것이라 톱과 같이 움직이거나 돌면 안 된다.
## 노드는 (시작위치 + 왕복) 으로 옮겨지고 rotation 으로 돈다 → 그 둘을 되돌리는 변환으로 "시작 위치 기준, 안 돈" 좌표에 그린다.
func _홈_그리기() -> void:
	var 되돌림 := (_시작위치 - position).rotated(-rotation)
	if Engine.is_editor_hint():
		되돌림 = Vector2.ZERO
	draw_set_transform(되돌림, -rotation if not Engine.is_editor_hint() else 0.0, Vector2.ONE)
	var 반 := 이동거리 * 0.5 + 반지름 * 0.3 + 6.0     # 허브가 끝까지 와도 멈춤쇠에 안 겹치게
	var 굵기 := clampf(반지름 * 0.2, 6.0, 9.0)
	var 세로 := 이동방향 == 1
	var 홈 := Rect2(-반, -굵기 * 0.5, 반 * 2.0, 굵기) if not 세로 else Rect2(-굵기 * 0.5, -반, 굵기, 반 * 2.0)
	# 홈 둘레가 살짝 패인 그늘 → 깊은 어둠 → 위(세로면 왼쪽) 안벽 그늘 → 아랫입술(세로면 오른쪽) 반사
	draw_rect(홈.grow(2.0), Color(0, 0, 0, 0.25))
	draw_rect(홈, Color(0.05, 0.05, 0.05))
	if not 세로:
		draw_rect(Rect2(홈.position, Vector2(홈.size.x, 2.0)), Color(0.02, 0.02, 0.02))
		draw_rect(Rect2(홈.position + Vector2(0, 홈.size.y), Vector2(홈.size.x, 1.5)), Color(0.47, 0.47, 0.47, 0.4))
	else:
		draw_rect(Rect2(홈.position, Vector2(2.0, 홈.size.y)), Color(0.02, 0.02, 0.02))
		draw_rect(Rect2(홈.position + Vector2(홈.size.x, 0), Vector2(1.5, 홈.size.y)), Color(0.47, 0.47, 0.47, 0.4))
	# 양끝 멈춤쇠(벽에 박힌 쇠 블록) — 세로 홈에서는 눕혀 그린다
	for 끝 in [-반, 반]:
		var 자리 := Vector2(끝, 0.0) if not 세로 else Vector2(0.0, 끝)
		var 크기 := Vector2(12, 16) if not 세로 else Vector2(16, 12)
		if not 세로:
			draw_texture_rect(멈춤쇠, Rect2(자리 - 크기 * 0.5, 크기), false)
		else:
			draw_set_transform(되돌림 + 자리.rotated(-rotation if not Engine.is_editor_hint() else 0.0), (-rotation if not Engine.is_editor_hint() else 0.0) + PI * 0.5, Vector2.ONE)
			draw_texture_rect(멈춤쇠, Rect2(Vector2(-6, -8), Vector2(12, 16)), false)
			draw_set_transform(되돌림, -rotation if not Engine.is_editor_hint() else 0.0, Vector2.ONE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
