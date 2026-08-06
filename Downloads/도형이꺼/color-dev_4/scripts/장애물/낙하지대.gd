@tool
extends Area2D
## ============================================================================
## 🕳 낙하지대 (Kill Zone)  —  [2026-07-24 도형 · 신규]
## ----------------------------------------------------------------------------
## 스테이지 바닥 전체에 깔아두는 낙사 판정. 보이지 않는다(디버그 때만 표시).
##
## ▣ 쓰는 법
##   scenes/장애물/낙하지대.tscn 을 스테이지 맨 아래에 깔고 `폭`·`높이` 만 늘린다.
##   `killzone` 그룹 — zone_template.tscn 과 같은 규약.
##
## ▣ 주의
##   구덩이 바닥에서 조금만 아래에 두면 "떨어지는 중"에 이미 죽어 억울하다.
##   화면 밖(카메라 리밋 아래 96px 이상)에 두는 것이 원칙.
## ============================================================================

@export var 폭: int = 4000:
	set(v): 폭 = v; _재구성()
@export var 높이: int = 200:
	set(v): 높이 = v; _재구성()
## 켜면 에디터/디버그에서 붉은 반투명으로 보인다
@export var 디버그표시: bool = false:
	set(v): 디버그표시 = v; queue_redraw()

func _ready() -> void:
	add_to_group("killzone")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	_재구성()

func _재구성() -> void:
	if not is_inside_tree():
		return
	var cs := get_node_or_null("충돌") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		cs.name = "충돌"
		add_child(cs)
	var sh := cs.shape as RectangleShape2D
	if sh == null:
		sh = RectangleShape2D.new()
		cs.shape = sh
	sh.size = Vector2(폭, 높이)
	queue_redraw()

func _draw() -> void:
	if 디버그표시 or Engine.is_editor_hint():
		draw_rect(Rect2(-Vector2(폭, 높이) * 0.5, Vector2(폭, 높이)),
			Color(0.8, 0.1, 0.1, 0.18), true)
