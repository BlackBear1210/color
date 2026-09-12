@tool
extends AnimatableBody2D
## ============================================================================
## [2026-09-07 신규] 움직이는 발판 (스마트월드용) — 상하 · 좌우 왕복
## ----------------------------------------------------------------------------
## ▣ 왜 새로 만들었나 — 기존 것 두 개가 다 못 쓴다
##   1. `scripts/장애물/움직이는발판.gd` 는 v3 의 `PaintPlatform` 을 상속한다.
##      그쪽은 `TilePaintMap` 규칙 엔진을 쓰므로 스마트월드의 `페인트코어` 와 안 물린다.
##   2. SS2D 지형(`지형.gd`)의 충돌은 `StaticBody2D` 다. StaticBody2D 를 움직이면
##      **위에 선 플레이어를 안 태우고 혼자 빠져나간다.**
##   → 라이더를 태우려면 `AnimatableBody2D` + `sync_to_physics = true` 여야 하고,
##     위치는 반드시 `_physics_process` 에서 옮겨야 한다(그리지 않으면 물리와 어긋난다).
##
## ▣ 색 규칙
##   통과플랫폼과 **완전히 같은 계약**을 지킨다 — 칠할 수 있고, 안 칠하면 검정이라
##   흰 플레이어는 안 칠한 발판에 올라타면 죽는다(`색규칙.gd`).
##   그래서 "움직이는 발판을 조준해서 맞히기" 라는 이 게임만의 상황이 만들어진다.
##
## ▣ 왕복은 사인파다
##   삼각파(등속 + 즉시 반전)로 하면 끝점에서 플레이어가 튕겨 나간다.
##   사인파는 끝에서 저절로 느려져 **끝점이 곧 타이밍 창**이 된다 — 발판 퍼즐의 리듬이 여기서 나온다.
##
## ▣ 레벨 디자인 규칙 (장애물_카탈로그 §3 과 동일)
##   · 왕복시간 3초 이상. 발판 위에서 조준까지 시키면 2초 이하는 가혹하다.
##   · 세로 발판을 **받아줄 것 없는 낙사 구간 위**에 두지 않는다.
##     (2-8 은 아래가 전부 물이라 예외다 — 물이 받아준다)
##   · 여러 장을 놓을 땐 `시작지연` 을 엇갈려 둔다. 안 그러면 전부 같은 위상으로 움직여
##     "발판이 하나"인 것과 다를 게 없어진다.
## ============================================================================
class_name 움직이는발판

@export_group("모양")
@export var 크기: Vector2 = Vector2(180, 28):
	set(v):
		크기 = Vector2(maxf(v.x, 24.0), maxf(v.y, 10.0))
		_다시_만들기()

@export_group("움직임")
## 왕복 거리(px). 0 이면 안 움직인다(= 그냥 발판).
@export_range(0.0, 1600.0, 10.0) var 이동거리: float = 300.0:
	set(v): 이동거리 = maxf(v, 0.0); queue_redraw()
## 0 = 좌우 · 1 = 상하.
@export_enum("좌우:0", "상하:1") var 이동방향: int = 0:
	set(v): 이동방향 = v; queue_redraw()
## A → B → A 한 바퀴에 걸리는 시간(초).
@export_range(0.6, 30.0, 0.1) var 왕복시간: float = 3.4
## 시작 위상 지연(초). 여러 장을 엇갈리게 움직일 때 쓴다.
@export_range(0.0, 30.0, 0.1) var 시작지연: float = 0.0
## 켜면 원점이 왕복 구간의 **가운데**, 끄면 **한쪽 끝**이 된다.
## (끝 기준이 기본이다 — 에디터에서 놓은 자리가 곧 출발 자리여야 배치가 안 헷갈린다)
@export var 원점이_가운데: bool = false

@export_group("색칠")
@export_range(1, 8) var 필요횟수: int = 2

var _상태색: int = -1
var _맞은횟수: int = 0
var _진행색: int = ColorDefs.BLACK
var _시작위치: Vector2 = Vector2.ZERO
var _t: float = 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true          # ★없으면 발판만 빠져나가고 플레이어는 미끄러진다
	_다시_만들기()
	# ★★[2026-09-07 수정] `_시작위치` 는 **에디터에서도** 잡아 둔다.
	#   전에는 아래 에디터 분기에서 먼저 return 해서 이 값이 (0,0) 인 채로 남았다.
	#   그런데 `_physics_process` 는 **메서드가 있으면 에디터에서도 돈다**(기본 활성).
	#   그래서 에디터에서 발판들이 `position = (0,0) + 오프셋` 으로 밀려
	#   **전부 원점 근처에 모였다** — 도형님 제보 "움직이는 발판이 0,0 에 다 모여있어".
	#   그 상태로 씬을 저장하면 밀린 좌표가 파일에 박힌다. 반드시 둘 다 막아야 한다.
	_시작위치 = position
	_t = -시작지연
	if Engine.is_editor_hint():
		set_physics_process(false)   # ★에디터에서는 한 픽셀도 움직이지 않는다
		queue_redraw()
		return
	add_to_group("칠할수있음")
	add_to_group("움직이는발판")
	set_physics_process(true)
	queue_redraw()


func _다시_만들기() -> void:
	if not is_inside_tree():
		return
	var c := get_node_or_null("충돌") as CollisionShape2D
	if c == null:
		c = CollisionShape2D.new()
		c.name = "충돌"
		add_child(c)
		if Engine.is_editor_hint() and owner:
			c.owner = owner
	var r := c.shape as RectangleShape2D
	if r == null:
		r = RectangleShape2D.new()
		c.shape = r
	r.size = 크기
	queue_redraw()


func _physics_process(delta: float) -> void:
	# ★두 겹으로 막는다. `set_physics_process(false)` 만 믿으면, 인스펙터에서 값을 만져
	#   `_ready` 가 다시 도는 상황에서 한 프레임이 새어 나가 발판이 밀린다.
	if Engine.is_editor_hint():
		return
	if 이동거리 <= 0.0 or 왕복시간 <= 0.0:
		return
	_t += delta
	if _t < 0.0:
		return                       # 시작지연 동안은 제자리
	# 0 → 1 → 0 을 오가는 사인 곡선. 누적이 아니라 시각에서 다시 계산하므로
	# 프레임 드랍이 나도 여러 발판의 위상이 서로 어긋나지 않는다.
	var 진행 := 0.5 - 0.5 * cos(TAU * _t / 왕복시간)
	var 뻗음 := (진행 - 0.5) * 이동거리 if 원점이_가운데 else 진행 * 이동거리
	position = _시작위치 + (Vector2(0.0, 뻗음) if 이동방향 == 1 else Vector2(뻗음, 0.0))


## 사망/리스폰 때 월드가 부를 수 있게 열어 둔다 — 발판이 엉뚱한 위상에서 시작하면
## 플레이어가 되살아나자마자 못 건너는 자리가 생긴다.
func 위상_초기화() -> void:
	_t = -시작지연
	position = _시작위치


# ── 페인트코어와의 약속 (통과플랫폼과 동일) ─────────────────────────────────
func 현재색() -> int:
	return _상태색


func 반대색인가(플레이어색: int) -> bool:
	# 안 칠한 상태(-1)도 화면에는 검정이다 → 규칙은 `색규칙.gd` 한 곳에만 있다.
	return 색규칙.위험한가(_상태색, 플레이어색)


func 명중(색: int, _월드좌표: Vector2) -> String:
	if _상태색 == ColorDefs.GRAY:
		return "blocked"
	if _상태색 >= 0:
		if 색 == _상태색:
			return "wasted"
		_상태색 = 색                 # 총알끼리는 섞지 않고 나중 색이 먼저 색을 덮는다
		queue_redraw()
		return "painted"
	if _맞은횟수 > 0 and _진행색 != 색:
		_맞은횟수 = 0
	_진행색 = 색
	_맞은횟수 += 1
	queue_redraw()
	if _맞은횟수 >= 필요횟수:
		_상태색 = 색
		return "painted"
	return "progress"


func 되돌리기() -> bool:
	if _상태색 == ColorDefs.GRAY:
		return false
	_상태색 = -1
	_맞은횟수 = 0
	queue_redraw()
	return true


func 강제_초기화() -> void:
	_상태색 = -1
	_맞은횟수 = 0
	queue_redraw()


# ── 그리기 ──────────────────────────────────────────────────────────────────
func _draw() -> void:
	if 아트슬롯.그림_있나(self):
		return

	var 본체 := Color(0.22, 0.23, 0.26)
	match _상태색:
		ColorDefs.BLACK: 본체 = Color(0.09, 0.09, 0.11)
		ColorDefs.WHITE: 본체 = Color(0.90, 0.91, 0.89)
		ColorDefs.GRAY:  본체 = Color(0.50, 0.50, 0.50)

	var 반 := 크기 * 0.5
	draw_rect(Rect2(-반, 크기), 본체)
	# 부분 색칠은 왼쪽부터 차오르게 — 몇 발 남았는지 눈으로 보인다
	if _상태색 < 0 and _맞은횟수 > 0:
		var 진행 := clampf(float(_맞은횟수) / float(maxi(필요횟수, 1)), 0.0, 1.0)
		var c := Color(0.09, 0.09, 0.11) if _진행색 == ColorDefs.BLACK else Color(0.90, 0.91, 0.89)
		draw_rect(Rect2(-반, Vector2(크기.x * 진행, 크기.y)), Color(c.r, c.g, c.b, 0.75))

	# 흑백 게임이라 단색 테두리는 어느 한쪽 배경에서 묻힌다 → 어두운 테 + 밝은 테 2겹.
	draw_rect(Rect2(-반, 크기), Color(0.04, 0.04, 0.05, 0.9), false, 3.0)
	draw_rect(Rect2(-반, 크기), Color(0.62, 0.63, 0.66, 0.75), false, 1.5)

	# 움직이는 방향 표시 — "이건 움직인다"를 서 보기 전에 알아야 한다
	if 이동거리 > 0.0:
		var 축 := Vector2(0.0, 1.0) if 이동방향 == 1 else Vector2(1.0, 0.0)
		var 길이 := minf(반.x, 반.y) * 0.9 + 6.0
		var 화살 := Color(0.62, 0.63, 0.66, 0.8)
		draw_line(-축 * 길이, 축 * 길이, 화살, 2.0)
		for s: float in [-1.0, 1.0]:
			var 끝: Vector2 = 축 * 길이 * s
			var 옆: Vector2 = 축.orthogonal() * 4.0
			draw_line(끝, 끝 - 축 * 6.0 * s + 옆, 화살, 2.0)
			draw_line(끝, 끝 - 축 * 6.0 * s - 옆, 화살, 2.0)

	# 에디터에서만: 왕복 구간을 점선으로 보여준다 (배치할 때 실행 없이 확인)
	if Engine.is_editor_hint() and 이동거리 > 0.0:
		var 축2 := Vector2(0.0, 1.0) if 이동방향 == 1 else Vector2(1.0, 0.0)
		var 시작 := -축2 * 이동거리 * 0.5 if 원점이_가운데 else Vector2.ZERO
		var 끝2 := 시작 + 축2 * 이동거리
		draw_rect(Rect2(시작 - 반, 크기), Color(0.62, 0.63, 0.66, 0.35), false, 1.0)
		draw_rect(Rect2(끝2 - 반, 크기), Color(0.62, 0.63, 0.66, 0.35), false, 1.0)
		draw_line(시작, 끝2, Color(0.62, 0.63, 0.66, 0.5), 1.0)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
