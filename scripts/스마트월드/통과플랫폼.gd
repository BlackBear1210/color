@tool
extends StaticBody2D
## ============================================================================
## [2026-08-01 신규] 통과되는 플랫폼 (하수구 격자)
## ----------------------------------------------------------------------------
## ▣ 기획
##   · 하수구처럼 구멍이 난 플랫폼.
##   · 검정/흰색 고정형이며 플레이어가 칠할 수 없다.
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

# 검정/흰색 원본과 구멍의 알파를 그대로 사용해 물과 배경이 격자 사이로 보이게 한다.
const 격자_아틀라스 = preload("res://assets/textures/obstacles/grate/cast_iron_v1/grate_atlas.png")

@export var 크기: Vector2 = Vector2(224, 26):
	set(v):
		크기 = Vector2(maxf(v.x, 24.0), maxf(v.y, 10.0))
		_다시_만들기()

# 기존 씬의 저장 속성 호환용이다. 고정색 격자에서는 횟수를 사용하지 않는다.
@export_range(1, 8) var 필요횟수: int = 2

# 외관과 접촉 판정이 같은 고정색을 사용해야 흑백 안전 규칙이 어긋나지 않는다.
@export_enum("검정:0", "흰색:1") var 고정색: int = ColorDefs.BLACK:
	set(value):
		고정색 = clampi(value, 0, 1)
		queue_redraw()

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_다시_만들기()
	if Engine.is_editor_hint():
		queue_redraw()
		return
	# 물감 대상 그룹에는 등록하지 않되, 직접 명중 호출도 아래에서 차단한다.
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
	return 고정색


func 반대색인가(플레이어색: int) -> bool:
	# 고정색도 기존 색규칙을 따라 반대색 플레이어에게 위험하다.
	return 색규칙.위험한가(고정색, 플레이어색)


# 총알/페인트코어에서 직접 호출해도 검정·흰색 규격은 바뀌지 않는다.
func 명중(_색: int, _월드좌표: Vector2) -> String:
	return "blocked"


func 되돌리기() -> bool:
	return false


func 강제_초기화() -> void:
	# 사망이나 물에 의한 리셋도 인스펙터에서 정한 고정색을 보존한다.
	queue_redraw()


func _draw() -> void:
	# 생성 원본의 실제 불투명 경계를 사용해 그림 윗면과 충돌 윗면을 맞춘다.
	var 원본 := Rect2(90, 810, 1075, 116) if 고정색 == ColorDefs.WHITE else Rect2(90, 326, 1074, 114)
	var 배율 := 크기.y / 원본.size.y
	# 양끝 볼트는 높이 비율을 유지하고 중앙만 늘려 짧거나 긴 발판에서도 고정부가 찌그러지지 않는다.
	var 끝폭 := minf(48.0 * 배율, 크기.x * 0.25)
	var 원본끝 := 끝폭 / 배율
	var 시작 := -크기 * 0.5
	draw_texture_rect_region(격자_아틀라스, Rect2(시작, Vector2(끝폭, 크기.y)),
		Rect2(원본.position, Vector2(원본끝, 원본.size.y)))
	draw_texture_rect_region(격자_아틀라스,
		Rect2(시작 + Vector2(끝폭, 0), Vector2(크기.x - 끝폭 * 2, 크기.y)),
		Rect2(원본.position + Vector2(원본끝, 0), Vector2(원본.size.x - 원본끝 * 2, 원본.size.y)))
	draw_texture_rect_region(격자_아틀라스,
		Rect2(시작 + Vector2(크기.x - 끝폭, 0), Vector2(끝폭, 크기.y)),
		Rect2(원본.position + Vector2(원본.size.x - 원본끝, 0), Vector2(원본끝, 원본.size.y)))
