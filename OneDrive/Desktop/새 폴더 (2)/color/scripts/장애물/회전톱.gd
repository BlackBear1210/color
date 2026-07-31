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
	_재구성()

func _재구성() -> void:
	if not is_inside_tree():
		return
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
