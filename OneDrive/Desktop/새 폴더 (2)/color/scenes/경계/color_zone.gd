@tool
extends Area2D
class_name ColorZone
## [2026-07-19 · 신규] 다각형 "색 구역" 프레임.
##
## 목적: 타일맵으로 찍은 지형 위에 겹쳐 놓는, 에디터에서 자유롭게 모양을 바꿀 수 있는
##   다각형 틀. 플레이어가 이 다각형 "안"에 들어오면 지정한 색(흑/백)으로 자동 고정되고,
##   구역 "밖"에서는 강제하지 않으므로 플레이어가 키보드로 자유롭게 색을 토글할 수 있다.
##
## 사용법 (디자이너):
##   1. 이 색 구역 씬(color_zone.tscn)을 지형 씬에 드래그해 넣는다 (여러 개 가능).
##   2. 자식 CollisionPolygon2D 를 선택 → 에디터에서 꼭짓점을 찍고 드래그해 모양을 잡는다.
##   3. Inspector 의 "Zone Color" 를 Black/White 중 선택한다. 끝.
##
## 겹침 규칙: 흑 구역과 백 구역이 겹치는 지점에 플레이어가 있으면
##   "가장 마지막에 진입한 구역"의 색으로 고정된다 (공용 스택의 맨 위가 이긴다).
##
## player.gd 무수정 원칙: 색이 목표와 다를 때 player 의 _toggle_color() 만 호출해 맞춘다.
##   (흑/백 2색뿐이라 한 번 토글이면 항상 목표 색이 된다.)

enum ZoneColor { BLACK, WHITE }

## 이 구역이 강제하는 색. Inspector 에서 드롭다운으로 선택.
@export var zone_color: ZoneColor = ZoneColor.WHITE:
	set(v):
		zone_color = v
		queue_redraw()
## 에디터/게임에서 구역을 반투명 색으로 표시할지 (연출용, 로직과 무관).
@export var show_tint: bool = true:
	set(v):
		show_tint = v
		queue_redraw()

## 겹침 우선순위용 공용 스택 — 맨 뒤 원소 = 가장 최근에 진입한 구역 = 우선.
## 모든 ColorZone 인스턴스가 공유한다(static). 씬 전환 시 _exit_tree 에서 청소.
static var _stack: Array = []

var _player: Node = null

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# 이 Area2D 는 "감지만" 한다 (다른 Area 에 감지되지는 않음).
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1                     # 플레이어 CharacterBody2D 레이어(기본 1)
	# 플레이어 _physics_process(색 토글 입력) 뒤에 실행 → 같은 프레임에 교정(깜빡임 없음)
	process_physics_priority = 10
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(b: Node2D) -> void:
	if not b.is_in_group("player"):
		return
	_player = b
	_stack.erase(self)                     # 중복 진입 방지
	_stack.append(self)                    # 최근 진입을 맨 뒤로

func _on_body_exited(b: Node2D) -> void:
	if not b.is_in_group("player"):
		return
	_stack.erase(self)

func _exit_tree() -> void:
	_stack.erase(self)                     # 씬 전환/노드 삭제 시 정적 스택 청소

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# 스택 맨 위(가장 최근 진입) 구역만 실제로 색을 강제한다.
	# → 구역이 하나도 안 겹치면 스택이 비어 아무도 강제 안 함 = 키보드 자유 전환.
	if _stack.is_empty() or _stack.back() != self:
		return
	if _player == null or not is_instance_valid(_player):
		_stack.erase(self)
		return
	var target: int = ColorDefs.WHITE if zone_color == ZoneColor.WHITE else ColorDefs.BLACK
	if _player.get("player_color") != target:
		_player.call("_toggle_color")

# ── 에디터/런타임 시각화 (반투명 틴트 + 외곽선) ─────────────────────────
func _process(_delta: float) -> void:
	# 에디터에서 꼭짓점을 드래그하는 즉시 틴트가 따라오도록 매 프레임 다시 그린다.
	if Engine.is_editor_hint():
		queue_redraw()

func _draw() -> void:
	if not show_tint:
		return
	var poly_node := get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	if poly_node == null or poly_node.polygon.size() < 3:
		return
	# CollisionPolygon2D 의 로컬 폴리곤을 이 Area2D 좌표계로 변환해 그린다.
	var xf := poly_node.transform
	var pts := PackedVector2Array()
	for p in poly_node.polygon:
		pts.append(xf * p)
	var is_white := zone_color == ZoneColor.WHITE
	var fill := Color(0.95, 0.95, 0.95, 0.14) if is_white else Color(0.05, 0.05, 0.05, 0.24)
	var line := Color(0.98, 0.98, 0.98, 0.7) if is_white else Color(0.05, 0.05, 0.05, 0.8)
	draw_colored_polygon(pts, fill)
	# 외곽선 (닫힌 루프)
	var loop := pts
	loop.append(pts[0])
	draw_polyline(loop, line, 2.0)
