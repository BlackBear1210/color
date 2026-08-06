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
		var f := get_node_or_null(대상_유체) as 유체
		if f:
			f.켜짐 = 켜짐
	else:
		var a := get_node_or_null(갈래_A) as 유체
		var b := get_node_or_null(갈래_B) as 유체
		if a:
			a.켜짐 = _A쪽
		if b:
			b.켜짐 = not _A쪽


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if absf(_목표각도 - _각도) > 0.005:
		_각도 = lerpf(_각도, _목표각도, 1.0 - exp(-10.0 * delta))
		queue_redraw()


func _draw() -> void:
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
