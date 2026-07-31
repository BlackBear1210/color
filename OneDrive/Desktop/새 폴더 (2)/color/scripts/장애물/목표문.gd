@tool
extends Area2D
## ============================================================================
## 🏁 목표문 (Goal)  —  [2026-07-24 도형 · 신규]
## ----------------------------------------------------------------------------
## 스테이지의 끝. 닿으면 클리어 → stage_lab 이 다음 스테이지로 넘긴다.
##
## ▣ 쓰는 법
##   scenes/장애물/목표문.tscn 을 스테이지 마지막 발판 위에 드래그. 끝.
##   `zone_exit` 그룹에 자동 등록되어 stage_lab.gd 가 찾아 연결한다.
##   (기존 zone_template.tscn 의 ExitZone 과 같은 그룹명이라 규약이 이어진다)
## ============================================================================

const 공통 := preload("res://scripts/장애물/장애물_공통.gd")

@export_range(24, 300) var 폭: int = 64:
	set(v): 폭 = v; _재구성()
@export_range(24, 400) var 높이: int = 112:
	set(v): 높이 = v; _재구성()

var _t: float = 0.0

func _ready() -> void:
	add_to_group("zone_exit")
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
	cs.position = Vector2(0, -높이 * 0.5)
	queue_redraw()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	queue_redraw()

func _draw() -> void:
	var w := float(폭)
	var h := float(높이)
	# 아치형 문틀 — 흑백 어느 지형 위에서도 보이게 2겹
	var 점 := PackedVector2Array([
		Vector2(-w * 0.5, 0), Vector2(-w * 0.5, -h * 0.72),
		Vector2(-w * 0.28, -h), Vector2(w * 0.28, -h),
		Vector2(w * 0.5, -h * 0.72), Vector2(w * 0.5, 0)])
	# 문 안쪽 = 흑↔백 그라데이션이 천천히 도는 "출구" 느낌 (이 게임의 주제 그대로)
	var 맥동 := 0.5 + 0.5 * sin(_t * 1.6)
	var 안쪽 := Color(1, 1, 1).lerp(Color(0.05, 0.05, 0.05), 맥동)
	draw_colored_polygon(점, Color(안쪽.r, 안쪽.g, 안쪽.b, 0.75))
	var 닫힌 := PackedVector2Array(점)
	닫힌.append(점[0])
	draw_polyline(닫힌, 공통.구조_외곽, 6.0, true)
	draw_polyline(닫힌, 공통.구조_코어, 2.5, true)
