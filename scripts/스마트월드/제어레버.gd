@tool
extends Area2D
## ============================================================================
## [2026-08-01 신규] 제어 배관 — 원형 레버 / 직선 레버
## ----------------------------------------------------------------------------
## ▣ 기획
##   · 플레이어가 가까이 가서 상호작용할 수 있다.
##   · **원형 레버** = 흐름을 멈춘다 (밸브).
##   · **직선 레버** = 흐르는 방향을 바꾼다.
##
## ▣ 조작
##   레버 근처에서 `interact`(기본 E) 를 누른다.
##   ⚠ E 는 페인트 수동 회수와 같은 키다. 레버 범위 안에 있을 때는 **레버가 우선**
##     이며(월드.gd 가 그렇게 중재한다), 범위 밖에서 누르면 평소대로 회수된다.
##     "가까이 가서 상호작용" 이라는 기획 문구를 그대로 지키면서 키를 아끼는 방법.
## ============================================================================
class_name 제어레버

enum 종류_ { 원형, 직선 }

@export var 종류: 종류_ = 종류_.원형:
	set(v): 종류 = v; queue_redraw()

## 원형: 이 유체를 켜고 끈다.
@export var 대상_유체: NodePath
## 직선: 켤 쪽 / 끌 쪽 — 레버를 넘길 때마다 둘이 뒤바뀐다.
@export var 갈래_A: NodePath
@export var 갈래_B: NodePath

@export var 반응반경: float = 74.0:
	set(v): 반응반경 = maxf(v, 24.0); _모양_갱신(); queue_redraw()

## 레버를 씬에 놓은 순간부터 물이 흐를지, 어느 갈래가 먼저 열릴지 정한다.
## 기본값은 기존 레버와 같은 "켜짐 + A 갈래"라 이전 스테이지의 동작은 바뀌지 않는다.
@export_group("초기 상태")
@export var 시작_켜짐: bool = true
@export var 시작_갈래_A: bool = true
@export_group("")

var 켜짐: bool = true
var _A쪽: bool = true
var _각도: float = 0.0
var _목표각도: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1                 # 플레이어 감지
	monitoring = true
	_모양_갱신()
	if Engine.is_editor_hint():
		queue_redraw()
		return
	add_to_group("제어레버")
	# 씬 인스펙터 값으로 먼저 맞춘 뒤 유체에 반영해야, 시작 프레임에 닫힌 밸브가 열리지 않는다.
	켜짐 = 시작_켜짐
	_A쪽 = 시작_갈래_A
	_반영()
	set_process(true)
	queue_redraw()


func _모양_갱신() -> void:
	var c := get_node_or_null("모양") as CollisionShape2D
	if c == null:
		c = CollisionShape2D.new()
		c.name = "모양"
		add_child(c)
	var s := c.shape as CircleShape2D
	if s == null:
		s = CircleShape2D.new()
		c.shape = s
	s.radius = 반응반경


## 플레이어가 상호작용 범위 안에 있는가 (월드.gd 가 E 키 중재에 쓴다)
func 닿아있나() -> bool:
	for b in get_overlapping_bodies():
		if b.is_in_group("player"):
			return true
	return false


## 월드.gd 가 E 입력을 넘겨준다.
func 조작() -> void:
	if 종류 == 종류_.원형:
		켜짐 = not 켜짐
		_목표각도 += PI * 0.5
	else:
		_A쪽 = not _A쪽
		_목표각도 = 0.6 if _A쪽 else -0.6
	_반영()
	queue_redraw()


func _반영() -> void:
	if 종류 == 종류_.원형:
		_켜기(대상_유체, 켜짐)
	else:
		_켜기(갈래_A, _A쪽)
		_켜기(갈래_B, not _A쪽)


## ★[2026-09-07] 예전에는 대상을 `as 유체` 로 못박아서 **웅덩이를 못 물렸다**
##   (`as` 는 형이 다르면 조용히 null 이라, 레버를 당겨도 아무 일도 안 일어났다).
##   → `켜짐` 을 가진 것이면 무엇이든 켠다. 유체·웅덩이 둘 다, 앞으로 생길 것도 그대로.
##   덤으로 켜는 순간 `차오르기_시작()` 도 불러 준다 —
##   "레버를 당기면 물이 차오른다" 가 배선 없이 성립한다.
func _켜기(경로: NodePath, 값: bool) -> void:
	var n := get_node_or_null(경로)
	if n == null or not ("켜짐" in n):
		return
	n.set("켜짐", 값)
	if 값 and n.has_method("차오르기_시작"):
		n.call("차오르기_시작")
	elif not 값 and n.has_method("차오르기_멈춤"):
		n.call("차오르기_멈춤")


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if absf(_목표각도 - _각도) > 0.005:
		_각도 = lerpf(_각도, _목표각도, 1.0 - exp(-10.0 * delta))
		queue_redraw()


func _draw() -> void:
	# ── [2026-08-07 도형] 디자이너 그림 슬롯 ────────────────────────────
	# 자식 `그림`(아트슬롯.gd) 에 텍스처가 꽂혀 있으면 코드 그리기는 쉰다.
	# 슬롯이 비어 있으면 지금까지처럼 아래 _draw 코드가 그린다 → 회귀 없음.
	if 아트슬롯.그림_있나(self):
		return

	var 금속 := Color(0.30, 0.31, 0.34)
	var 밝은 := Color(0.62, 0.63, 0.66)
	var 표시 := Color(0.85, 0.85, 0.82) if 켜짐 else Color(0.35, 0.35, 0.35)

	# 상호작용 범위 — 플레이어가 "여기서 누르면 된다"를 알 수 있게 은은하게
	draw_arc(Vector2.ZERO, 반응반경, 0.0, TAU, 40, Color(1, 1, 1, 0.07), 1.5)

	# 받침대
	draw_rect(Rect2(Vector2(-14, 0), Vector2(28, 26)), 금속)

	if 종류 == 종류_.원형:
		# 밸브 핸들 — 살 4개짜리 바퀴
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 32, 밝은, 5.0)
		for i in 4:
			var a := _각도 + TAU * float(i) / 4.0
			draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * 20.0, 밝은, 4.0)
		draw_circle(Vector2.ZERO, 6.0, 표시)
	else:
		# 직선 레버 — 손잡이가 좌/우로 넘어간다
		var 끝 := Vector2(sin(_각도), -cos(_각도)) * 34.0
		draw_line(Vector2.ZERO, 끝, 밝은, 6.0)
		draw_circle(끝, 8.0, 표시)
		draw_circle(Vector2.ZERO, 7.0, 금속)
