extends Node2D
## ============================================================================
## [2026-09-30 Claude] 하수도 발밑 접지 그림자 — 그림만(판정·물리 없음).
## ----------------------------------------------------------------------------
## ▣ 왜
##   벽등이 벽에 드리우는 그림자는 등 가까이에서만 생기고(명암차 10~17/255) 등에서 멀면 없다.
##   그래서 캐릭터가 바닥에 "서 있는" 느낌이 약했다(도형님: 플레이어 그림자).
##   발 아래 바닥 윗면에 옅은 타원을 깔고, 뛰어오르면 높이에 따라 작고 옅어지게 한다.
##
## ▣ 어디서 켜지나
##   `하수도_실시간벽등.gd` 가 자기 옆에 하나 만든다 → 그 배경을 쓰는 하수도 스테이지만.
##   집·다른 챕터의 Player 는 건드리지 않는다.
##
## ▣ 좌표
##   Player 원점 = 발바닥(2-9 실측: 착지한 원점 y 와 바닥 윗면 y 가 같다).
##   원점에서 아래로 최대 `최대_높이` 까지 지형(레이어 1)을 광선으로 찾는다.
## ============================================================================

@export var 최대_높이: float = 160.0     ## 이보다 높이 뜨면 그림자를 안 그린다(점프 높이 160 과 같다)
@export var 폭: float = 46.0             ## 서 있을 때 타원 가로 (충돌 폭 44 실측)
@export var 진하기: float = 0.8

var _플: Node2D
var _바닥 := Vector2.ZERO
var _높이 := -1.0

func _ready() -> void:
	# Player 의 자식으로 붙고(설치 쪽), 스프라이트보다 **먼저**(인덱스 0) 그려서 발 뒤에 깔린다.
	# 스테이지 루트에 따로 두면 SS2D 지형 마감 메시가 나중에 그려져 그림자를 덮었다(실측: 폭 200·진하기 1 도 안 보임).
	# top_level 로 Player 의 비율(scale 0.79×0.37)을 받지 않고 전역 좌표 그대로 그린다.
	top_level = true
	z_index = 1

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_플):
		_플 = get_tree().get_first_node_in_group("player") as Node2D
		if _플 == null:
			return
	var 공간 := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(_플.global_position + Vector2(0, -4), _플.global_position + Vector2(0, 최대_높이))
	q.collision_mask = 1
	if _플 is CollisionObject2D:
		q.exclude = [(_플 as CollisionObject2D).get_rid()]
	var hit := 공간.intersect_ray(q)
	if hit.is_empty():
		_높이 = -1.0
	else:
		_바닥 = hit["position"]
		_높이 = maxf(0.0, _바닥.y - _플.global_position.y)
	queue_redraw()

func _draw() -> void:
	if _높이 < 0.0:
		return
	var t := clampf(_높이 / 최대_높이, 0.0, 1.0)
	var w := 폭 * (1.0 - 0.55 * t)
	var a := 진하기 * (1.0 - t)
	# 바닥 윗면 줄(갓돌)은 충돌선보다 몇 px 위까지 그려진다 → 그림자 중심을 3px 올려 윗면 위에 앉힌다.
	# 납작한 타원(높이 = 폭의 0.28)을 8 겹 옅게 겹쳐 가장자리를 부드럽게(텍스처 없이).
	var c := _바닥 + Vector2(0, -3)
	for i in 8:
		var k := 1.0 - float(i) / 8.0
		var rx := w * 0.5 * (0.35 + 0.65 * k)
		_타원(c, rx, rx * 0.28, Color(0, 0, 0, a / 5.0))

func _타원(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var ang := TAU * float(i) / 20.0
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	draw_colored_polygon(pts, col)
