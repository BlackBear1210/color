@tool
extends StaticBody2D
## ============================================================================
## 🚪 색문 (Color Gate)  —  [2026-07-24 도형 · 신규]
## ----------------------------------------------------------------------------
## **지정한 색일 때만 통과**할 수 있는 문. 다른 색이면 벽이다.
## 즉사가 아니라 "막힘"이라 실패 비용이 낮다 → 배우는 구간(스테이지 2~3)에 적합.
##
## ▣ 쓰는 법
##   scenes/장애물/색문.tscn 드래그 → `통과색`(검정/흰색) 과 `크기_칸` 만 조절.
##   문 앞에 무색 발판을 두면 "칠해서 색을 확인하고 → 색을 바꾸고 → 통과" 리듬이 된다.
##
## ▣ 구현 메모
##   콜리전을 켜고 끄는 게 아니라 `collision_layer` 를 0/1 로 토글한다.
##   (disabled 토글은 물리 프레임 밖에서 하면 경고가 뜨므로 set_deferred 사용)
## ============================================================================

const 공통 := preload("res://scripts/장애물/장애물_공통.gd")

@export_enum("검정", "흰색") var 통과색: int = 0:
	set(v): 통과색 = v; queue_redraw()
@export var 크기_칸: Vector2i = Vector2i(1, 4):
	set(v):
		크기_칸 = Vector2i(maxi(v.x, 1), maxi(v.y, 1))
		_재구성()

var _열림: bool = false
var _충돌: CollisionShape2D

func _ready() -> void:
	_재구성()

func _재구성() -> void:
	if not is_inside_tree():
		return
	if _충돌 == null:
		_충돌 = get_node_or_null("충돌") as CollisionShape2D
	if _충돌 == null:
		_충돌 = CollisionShape2D.new()
		_충돌.name = "충돌"
		add_child(_충돌)
	var sh := _충돌.shape as RectangleShape2D
	if sh == null:
		sh = RectangleShape2D.new()
		_충돌.shape = sh
	sh.size = Vector2(크기_칸) * 32.0
	collision_layer = 1
	collision_mask = 0
	queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var 플레이어들 := get_tree().get_nodes_in_group("player")
	if 플레이어들.is_empty():
		return
	var 색: int = 플레이어들[0].get("player_color")
	var 열려야 := (색 == (ColorDefs.BLACK if 통과색 == 0 else ColorDefs.WHITE))
	if 열려야 != _열림:
		_열림 = 열려야
		set_deferred("collision_layer", 0 if _열림 else 1)
		queue_redraw()

func _draw() -> void:
	var 크기 := Vector2(크기_칸) * 32.0
	var 사각 := Rect2(-크기 * 0.5, 크기)
	var 문색 := Color(0.10, 0.10, 0.10) if 통과색 == 0 else Color(0.93, 0.93, 0.93)
	if _열림:
		# 열린 상태: 윤곽만 남기고 투명 — "지금은 지나갈 수 있다"
		draw_rect(사각, Color(문색.r, 문색.g, 문색.b, 0.12), true)
		draw_rect(사각, Color(0.5, 0.5, 0.5, 0.55), false, 2.0)
	else:
		draw_rect(사각, 문색, true)
		draw_rect(사각, 공통.구조_외곽 if 통과색 == 1 else 공통.구조_코어, false, 2.5)
		# 빗금 = "막혀 있음"
		var n := maxi(int(크기.y / 14.0), 2)
		for i in n:
			var y := -크기.y * 0.5 + 크기.y * float(i) / float(n)
			draw_line(Vector2(-크기.x * 0.5, y), Vector2(크기.x * 0.5, y + 10.0),
				Color(0.5, 0.5, 0.5, 0.45), 1.5)
	# 통과 조건 아이콘: 문 위에 통과색 원 (한눈에 "무슨 색이어야 하나" 읽히게)
	var 아이콘 := Vector2(0, -크기.y * 0.5 - 14.0)
	draw_circle(아이콘, 8.0, Color(0.5, 0.5, 0.5, 0.9))
	draw_circle(아이콘, 6.0, 문색)
