@tool
extends StaticBody2D
## ============================================================================
## [2026-08-01 신규] 통과되는 플랫폼 (하수구 격자)
## ----------------------------------------------------------------------------
## ▣ 기획
##   · 하수구처럼 구멍이 난 플랫폼.
##   · 일반 플랫폼처럼 **색칠 가능**.
##   · **물로 인해 색칠이 지워지지 않으며 물이 통과한다.**
##   · 3 스테이지의 연기도 통과한다.
##
## ▣ 구현 포인트
##   "물이 통과한다"는 물리적으로는 이미 성립한다 — 유체는 Area2D 라 충돌이 없다.
##   진짜 중요한 건 **물이 페인트를 지우지 못한다**는 쪽이고, 그건
##   `물에_안지워짐()` 이 true 를 돌려주면 유체.gd 가 알아서 건너뛴다.
##   → 물길 아래에서도 색을 유지할 수 있는 유일한 발판 = 레벨 설계의 열쇠가 된다.
## ============================================================================
class_name 통과플랫폼

@export var 크기: Vector2 = Vector2(224, 26):
	set(v):
		크기 = Vector2(maxf(v.x, 24.0), maxf(v.y, 10.0))
		_다시_만들기()

@export_range(1, 8) var 필요횟수: int = 2

var _상태색: int = -1
var _맞은횟수: int = 0
var _진행색: int = ColorDefs.BLACK


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_다시_만들기()
	if Engine.is_editor_hint():
		queue_redraw()
		return
	add_to_group("칠할수있음")
	add_to_group("통과플랫폼")
	queue_redraw()


func _다시_만들기() -> void:
	if not is_inside_tree():
		return
	var c := get_node_or_null("충돌") as CollisionShape2D
	if c == null:
		c = CollisionShape2D.new()
		c.name = "충돌"
		add_child(c)
	var r := c.shape as RectangleShape2D
	if r == null:
		r = RectangleShape2D.new()
		c.shape = r
	r.size = 크기
	queue_redraw()


## 유체.gd 가 이걸 보고 페인트 지우기를 건너뛴다.
func 물에_안지워짐() -> bool:
	return true


# ── 페인트코어와의 약속 ─────────────────────────────────────────────────────
func 현재색() -> int:
	return _상태색


func 반대색인가(플레이어색: int) -> bool:
	# ★[2026-08-30] 안 칠한 상태(-1)도 화면에는 검정이다 → 검정으로 판정한다.
	#   규칙은 `색규칙.gd` 한 곳에만 있다.
	return 색규칙.위험한가(_상태색, 플레이어색)


func 명중(색: int, _월드좌표: Vector2) -> String:
	if _상태색 == ColorDefs.GRAY:
		return "blocked"
	if _상태색 >= 0:
		if 색 == _상태색:
			return "wasted"
		_상태색 = 색                    # 총알끼리는 섞지 않고 나중 색이 먼저 색을 덮는다.
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


## 사망/스테이지 리셋 전용 — 되돌리기() 와 달리 회색이어도 강제로 무색화한다.
func 강제_초기화() -> void:
	_상태색 = -1
	_맞은횟수 = 0
	queue_redraw()


func _draw() -> void:
	# ── [2026-08-07 도형] 디자이너 그림 슬롯 ────────────────────────────
	# 자식 `그림`(아트슬롯.gd) 에 텍스처가 꽂혀 있으면 코드 그리기는 쉰다.
	# 슬롯이 비어 있으면 지금까지처럼 아래 _draw 코드가 그린다 → 회귀 없음.
	if 아트슬롯.그림_있나(self):
		return

	var 본체 := Color(0.22, 0.23, 0.26)
	match _상태색:
		ColorDefs.BLACK: 본체 = Color(0.09, 0.09, 0.11)
		ColorDefs.WHITE: 본체 = Color(0.90, 0.91, 0.89)
		ColorDefs.GRAY:  본체 = Color(0.50, 0.50, 0.50)

	var 반 := 크기 * 0.5
	# 진행 중인 부분 색칠은 왼쪽부터 차오르게 표시 (몇 발 남았는지 눈으로 보이게)
	draw_rect(Rect2(-반, 크기), 본체)
	if _상태색 < 0 and _맞은횟수 > 0:
		var 진행 := clampf(float(_맞은횟수) / float(maxi(필요횟수, 1)), 0.0, 1.0)
		var c := Color(0.09, 0.09, 0.11) if _진행색 == ColorDefs.BLACK else Color(0.90, 0.91, 0.89)
		draw_rect(Rect2(-반, Vector2(크기.x * 진행, 크기.y)), Color(c.r, c.g, c.b, 0.75))

	# 격자 구멍 — "하수구" 실루엣
	var 구멍폭 := 12.0
	var 간격 := 22.0
	var x := -반.x + 10.0
	while x + 구멍폭 < 반.x:
		draw_rect(Rect2(Vector2(x, -반.y + 5), Vector2(구멍폭, 크기.y - 10)),
			Color(0.04, 0.04, 0.05, 0.85))
		x += 간격
	draw_rect(Rect2(-반, 크기), Color(0.55, 0.56, 0.58, 0.5), false, 2.0)
