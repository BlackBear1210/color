extends Area2D
## [2026-07-17 도형 · v3] 프로토 총알: 포물선 비행(중력 적용), 지형(TileMapLayer) 명중 시
## PaintSystem.on_hit() 에 셀 좌표와 색을 전달한다. 기존 bullet.gd 무수정.
## v3 변경: 직선(_direction × speed) → 초속 벡터 + 중력. 초속·중력은 ProtoGun 이
## setup() 으로 넘겨주므로 조준 궤적(점선)과 실제 탄도가 항상 일치한다.
class_name ProtoBullet

@export var lifetime: float = 2.0

## PaintSystem(v2, 타일 셀 단위) 또는 TilePaintMap(아틀라스 좌표 단위) 둘 중 하나.
## 두 클래스가 on_hit(layer, cell, color) 시그니처를 공유하므로 타입을 좁히지 않는다.
var _paint_system: Node
var _color: int = ColorDefs.BLACK
var _velocity: Vector2 = Vector2.RIGHT * 900.0
var _gravity: float = 1400.0
var _행동효과: Node = null
## 페인트 시스템에 명중을 넘겼나. 안 넘겼으면 수명이 다할 때 페인트를 환급한다.
var _명중함: bool = false

@onready var visual: Polygon2D = $Visual

func setup(ps: Node, color: int, velocity: Vector2, gravity: float, 행동효과: Node = null) -> void:
	_paint_system = ps
	_color        = color
	_velocity     = velocity
	_gravity      = gravity
	_행동효과     = 행동효과

func _ready() -> void:
	# ★[2026-07-24 도형] 레이어 1(실체 지형) + 레이어 4(유령 = 아직 안 칠해진 발판) 둘 다 감지.
	# 플레이어는 레이어 1만 보므로 유령 발판을 통과하지만, 총알은 유령도 맞힐 수 있어야 한다.
	collision_mask = 1 | PaintPlatform.유령_레이어비트
	visual.color = Color(0.05, 0.05, 0.05) if _color == ColorDefs.BLACK else Color(0.95, 0.95, 0.95)
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(_소멸)

func _physics_process(delta: float) -> void:
	_velocity.y += _gravity * delta
	position += _velocity * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		return
	# PaintPlatform·타일맵·일반 벽 모두, 총알이 실제 충돌한 한 번의 지점에서만 물감이 튄다.
	_물감_튐()
	# ★[2026-07-24 도형] 페인트 시스템 v3 — 플랫폼 단위 색칠 분기 추가.
	# 기존 타일맵 분기는 그대로 두고 앞에 한 갈래만 얹었다(zone_01/02/world_1 회귀 없음).
	# 플랫폼은 자기 상태를 스스로 알고 있으므로 PaintSystem 을 거치지 않고 직접 호출한다.
	if body is PaintPlatform:
		(body as PaintPlatform).명중(_color, global_position)
		queue_free()
		return
	# ★[2026-08-22 도형] 하수도 챕터 장애물(투명블럭·통과플랫폼·물저장고…) 분기.
	#   이 노드들은 PaintPlatform 도 TileMapLayer 도 아니라 **어느 갈래에도 안 걸려서**
	#   총을 쏴도 아무 일이 없었다. 스마트월드의 `총알.gd` 는 `명중` 메서드 유무로
	#   대상을 찾으므로, 여기서도 같은 방식으로 찾아 같은 규칙을 태운다.
	#   → 같은 장애물이 두 스테이지 계열에서 똑같이 동작한다.
	var 칠할것 := _칠할대상_찾기(body)
	if 칠할것 != null and _paint_system != null and _paint_system.has_method("노드_명중"):
		_명중함 = true          # 정산(환급/잠금)은 페인트 쪽이 한다
		_paint_system.노드_명중(칠할것, _color, global_position)
		_소멸()
		return

	if body is TileMapLayer and _paint_system != null:
		var layer := body as TileMapLayer
		# 탄착점이 셀 경계에 걸칠 수 있어 진행 방향으로 살짝 안쪽 지점도 함께 검사
		var dir := _velocity.normalized()
		var cell := layer.local_to_map(layer.to_local(global_position))
		if layer.get_cell_source_id(cell) == -1:
			cell = layer.local_to_map(layer.to_local(global_position + dir * 10.0))
		_명중함 = true          # 결과(칠함/낭비/막힘)에 따른 정산은 페인트 쪽이 한다
		_paint_system.on_hit(layer, cell, _color)
	_소멸()


func _물감_튐() -> void:
	if _행동효과 and _행동효과.has_method("명중"):
		# [2026-09-05] 이 총알은 body_entered 로 맞춰서 법선을 모른다 →
		#   ActionFX 가 진행 반대 방향으로 대신 세운다(기본값 Vector2.ZERO 의 뜻).
		_행동효과.명중(global_position, _velocity, _color, Vector2.ZERO, "ProtoBullet")


## 콜리전 바디에서 "칠할 수 있는 대상"을 거슬러 올라가 찾는다.
## `총알.gd` 의 같은 이름 함수와 동일한 규약 — 자식 콜리전에 맞아도 부모가 잡힌다.
## ⚠ TileMapLayer 는 제외한다. 그쪽은 셀 좌표가 필요해서 아래 전용 갈래로 가야 한다.
func _칠할대상_찾기(맞은것: Object) -> Node:
	var n := 맞은것 as Node
	while n != null:
		if n is TileMapLayer:
			return null
		if n.has_method("명중") and n.has_method("현재색"):
			return n
		n = n.get_parent()
	return null


## ★[2026-08-17] 페인트 시스템에 아무것도 못 넘기고 사라졌다 = 빗나감 → 페인트를 돌려준다.
## 수명이 다했을 때도, 칠할 수 없는 물체에 부딪혔을 때도 여기로 온다.
##
## 예전에는 `queue_free` 로 조용히 사라졌다. 탄약이 생긴 지금 그대로 두면
## **허공에 쏠 때마다 손해**가 되어 "맞혀야만 잠긴다" 규칙이 깨진다.
## ⚠ 덕 타이핑 — 탄약이 없는 PaintSystem(v2) 에는 `빗나감()` 이 없어 그냥 넘어간다.
func _소멸() -> void:
	if not _명중함 and _paint_system != null and _paint_system.has_method("빗나감"):
		_paint_system.빗나감()
	queue_free()
