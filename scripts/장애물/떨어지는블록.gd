@tool
extends Area2D
## ============================================================================
## ⬇ 떨어지는 블록 (Falling Block)  —  [2026-07-24 도형 · 신규]
## ----------------------------------------------------------------------------
## 천장에 매달려 있다가, 플레이어가 아래를 지나가면 잠깐 떨리다 낙하한다.
## 닿으면 즉사. 바닥에 닿으면 부서지고, 잠시 뒤 원위치에서 다시 매달린다.
##
## ▣ 쓰는 법
##   scenes/장애물/떨어지는블록.tscn 을 천장에 붙여 배치 → `감지높이`(아래로 몇 px 까지
##   플레이어를 감지할지) 와 `경고시간` 만 조절.
##
## ▣ 레벨 디자인 규칙
##   · 경고시간 0.45초 = "보고 나서 반응할 수 있는" 최소치. 이보다 짧으면 암기 게임이 된다.
##   · 통로 하나에 3개 이상 연속으로 두지 않는다(암기 강요).
##   · 낙하 지점 바로 아래에 무색 발판을 두면 "쏘고 나서 피하기" 순서가 강제된다 — 좋은 배치.
## ============================================================================

const 공통 := preload("res://scripts/장애물/장애물_공통.gd")

@export var 크기_칸: Vector2i = Vector2i(2, 2):
	set(v):
		크기_칸 = Vector2i(maxi(v.x, 1), maxi(v.y, 1))
		_재구성()
## 이 블록 아래 몇 px 안에 플레이어가 들어오면 발동하는가
@export_range(32.0, 1200.0) var 감지높이: float = 320.0
## 떨리는 경고 시간(초)
@export_range(0.1, 2.0) var 경고시간: float = 0.45
## 부서진 뒤 다시 매달릴 때까지(초)
@export_range(0.5, 12.0) var 재생성시간: float = 3.0
@export_range(200.0, 3000.0) var 낙하중력: float = 1500.0

var _상태: int = 0                  ## 0=대기 1=경고 2=낙하 3=부서짐
var _타이머: float = 0.0
var _원래위치: Vector2
var _속도: float = 0.0
var _충돌: CollisionShape2D

func _ready() -> void:
	add_to_group("hazard")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	_원래위치 = position
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
	queue_redraw()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	match _상태:
		0:
			if _플레이어가_아래에_있나():
				_상태 = 1
				_타이머 = 경고시간
		1:
			_타이머 -= delta
			# 떨림 — 낙하 예고. 진폭이 커지며 긴장을 만든다.
			var 진행 := 1.0 - clampf(_타이머 / maxf(경고시간, 0.01), 0.0, 1.0)
			position = _원래위치 + Vector2(sin(Time.get_ticks_msec() * 0.06) * 4.0 * 진행, 0)
			if _타이머 <= 0.0:
				_상태 = 2
				_속도 = 0.0
				position = _원래위치
		2:
			_속도 += 낙하중력 * delta
			position.y += _속도 * delta
			# 바닥(지형)에 닿으면 부서진다 — 레이캐스트 한 방으로 검사
			if _바닥에_닿았나():
				_상태 = 3
				_타이머 = 재생성시간
				modulate.a = 0.0
		3:
			_타이머 -= delta
			if _타이머 <= 0.0:
				_상태 = 0
				position = _원래위치
				modulate.a = 1.0
	queue_redraw()

func _플레이어가_아래에_있나() -> bool:
	var 플레이어들 := get_tree().get_nodes_in_group("player")
	if 플레이어들.is_empty():
		return false
	var p := 플레이어들[0] as Node2D
	var 크기 := Vector2(크기_칸) * 32.0
	var 로컬 := to_local(p.global_position)
	return absf(로컬.x) <= 크기.x * 0.5 + 12.0 and 로컬.y > 0.0 and 로컬.y < 감지높이

func _바닥에_닿았나() -> bool:
	var 크기 := Vector2(크기_칸) * 32.0
	var 시작 := global_position + Vector2(0, 크기.y * 0.5)
	var q := PhysicsRayQueryParameters2D.create(시작, 시작 + Vector2(0, 6.0))
	q.collision_mask = 1
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()

func _draw() -> void:
	if _상태 == 3:
		return
	var 크기 := Vector2(크기_칸) * 32.0
	var 점 := PackedVector2Array([
		Vector2(-크기.x * 0.5, -크기.y * 0.5), Vector2(크기.x * 0.5, -크기.y * 0.5),
		Vector2(크기.x * 0.5, 크기.y * 0.5), Vector2(-크기.x * 0.5, 크기.y * 0.5)])
	공통.폴리곤_외곽선(self, 점, 공통.위험_코어, 공통.위험_외곽, 3.0)
	# 가운데 붉은 X — "이건 밟는 게 아니라 피하는 것"
	var m := minf(크기.x, 크기.y) * 0.26
	draw_line(Vector2(-m, -m), Vector2(m, m), 공통.위험_경고, 3.0)
	draw_line(Vector2(m, -m), Vector2(-m, m), 공통.위험_경고, 3.0)
