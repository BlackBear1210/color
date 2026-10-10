@tool
extends Area2D
## ============================================================================
## 🗡 가시 (Spikes)  —  [2026-07-24 도형 · 신규]
## ----------------------------------------------------------------------------
## 가장 기본적인 즉사 함정. 색과 무관하게 닿으면 죽는다.
##
## ▣ 쓰는 법
##   scenes/장애물/가시.tscn 을 스테이지에 드래그 → 인스펙터에서
##   `칸수`(가로 몇 칸) 와 `방향`(위/아래/왼쪽/오른쪽) 만 바꾸면 끝.
##   위치는 발판 표면에 딱 붙이면 된다(원점 = 가시가 박힌 면의 중앙).
##
## ▣ 레벨 디자인 규칙
##   · 플레이어 최대 점프 높이 ≈ 150px(약 4.7칸) / 최대 도약 거리 ≈ 320px(10칸).
##     가시 구간은 **6칸 이하**로 잡아야 실수 여지를 남기면서 넘을 수 있다.
##   · 가시는 "칠하기 실패의 벌"이 아니라 "경로를 좁히는 도구"로 쓴다.
##     칠하기를 강제하려면 가시가 아니라 반대색 발판을 쓰는 게 이 게임의 문법이다.
## ============================================================================

const 공통 := preload("res://scripts/장애물/장애물_공통.gd")

## ★[2026-09-28] 주철 가시판 그림(도형님 확정 시안 3). 흰 삼각형 + 빨간 점은 벽돌·주철 세계에서 혼자 벡터 도형이라 튀었고,
##   흰색이라 "흰 몸이면 밟아도 되나?" 로 읽힐 수 있었다(가시는 색과 무관하게 죽인다) → 회색 주철로.
##   그림은 tools/생성_가시_주철.py 가 호퍼 원화 재질로 굽는다(손으로 그리지 말 것). **판정 폴리곤은 그대로다.**
##   [2026-10-10] 말뚝의 금속 결만 재사용한다. 연속 받침판 대신 개별 타원 받침과 앞뒤 엇갈림으로 상판 원근을 표현한다.
const 주철_가시 = preload("res://assets/textures/obstacles/spike/cast_iron_v1/spike_atlas.png")
const 칸_그림폭 := 32.0
const 그림_여백 := 4.0
const 그림_상자 := 22.0
const 변형_수 := 6

## 자동은 발밑 지형의 상판 가운데를 따른다. 에디터에서는 현재 게임의 22px 상판 가운데(+7)를 미리 보여 준다.
@export_range(-1, 24) var 그림_깊이: float = -1.0:
	set(v): 그림_깊이 = v; queue_redraw()
var _잰_깊이: float = 7.0

## 옛 그림(흰 삼각형 + 빨간 점)으로 되돌린다. 비교·디버그용.
@export var 옛_그림: bool = false:
	set(v): 옛_그림 = v; queue_redraw()

@export_range(1, 20) var 칸수: int = 3:
	set(v): 칸수 = maxi(v, 1); _재구성()
## 0=위 1=아래 2=왼쪽 3=오른쪽 (가시가 향하는 방향)
@export_enum("위", "아래", "왼쪽", "오른쪽") var 방향: int = 0:
	set(v): 방향 = v; _재구성()
## 가시 하나의 높이(px). 32 = 한 칸.
@export_range(8, 64) var 가시높이: float = 22.0:
	set(v): 가시높이 = v; _재구성()

var _폴리들: Array = []

func _ready() -> void:
	add_to_group("hazard")          # stage_lab 이 이 그룹만 보고 사망 판정을 한다
	collision_layer = 0
	collision_mask = 1              # 플레이어(레이어 1)만 감지
	monitoring = true
	_재구성()
	if not Engine.is_editor_hint():
		_깊이_재기.call_deferred()


func _깊이_재기() -> void:
	await get_tree().physics_frame
	if not is_inside_tree() or 방향 != 0:
		return
	# 가시 원점은 판정 상자의 중앙이다. 받침 위치에서 지형을 찾아 소품/발 그림과 같은 깊이를 적용한다.
	var 받침 := Vector2(0, 가시높이 * 0.5)
	var q := PhysicsRayQueryParameters2D.create(to_global(받침 + Vector2(0, -4)), to_global(받침 + Vector2(0, 24)), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	_잰_깊이 = 0.0
	if not hit.is_empty():
		var 면 := hit["collider"] as Node
		while 면 != null and not 면.has_method("발_그림_깊이"):
			면 = 면.get_parent()
		if 면 is Node2D:
			var 값 := float(면.call("발_그림_깊이"))
			_잰_깊이 = to_local(면.to_global(Vector2(0, 값))).y - to_local(면.to_global(Vector2.ZERO)).y
	queue_redraw()

func _재구성() -> void:
	if not is_inside_tree():
		return
	var 폭 := float(칸수 * 32)
	_폴리들 = 공통.가시_폴리곤들(폭, 가시높이, 칸수, 방향)
	# 기존 충돌 폴리곤 제거 후 다시 생성 (칸수를 바꿔도 항상 정확히 맞게)
	for c in get_children():
		if c is CollisionPolygon2D:
			c.queue_free()
	for p in _폴리들:
		var cp := CollisionPolygon2D.new()
		cp.polygon = p
		add_child(cp)
	queue_redraw()

func _draw() -> void:
	if not 옛_그림 and 주철_가시 != null:
		_주철_그리기()
		return
	for p in _폴리들:
		공통.폴리곤_외곽선(self, p, 공통.위험_코어, 공통.위험_외곽, 2.0)
		# 끝쪽에 붉은 경고점 — 흑백 화면에서 "위험"을 즉시 읽히게
		var 끝: Vector2 = p[1]
		draw_circle(끝, 2.4, 공통.위험_경고)


## 판정은 기존 삼각형 띠를 유지하고 그림만 상판에 투영한다. 원근 보정은 바닥 가시에만 적용한다.
func _주철_그리기() -> void:
	var 회전 := 0.0
	match 방향:
		1: 회전 = PI            # 아래 (천장에 박힘)
		2: 회전 = -PI * 0.5     # 왼쪽 (오른쪽 벽에 박힘)
		3: 회전 = PI * 0.5      # 오른쪽 (왼쪽 벽에 박힘)
	var 깊이 := (그림_깊이 if 그림_깊이 >= 0.0 else _잰_깊이) if 방향 == 0 else 0.0
	draw_set_transform(Vector2(0, 깊이), 회전, Vector2.ONE)
	var 폭 := float(칸수) * 32.0
	var 씨앗 := int(round(global_position.x)) * 73856093 ^ int(round(global_position.y)) * 19349663
	# 뒷줄을 왼쪽 위, 앞줄을 오른쪽 아래로 밀어 상판의 (-18,-22) 투영 방향과 맞춘다.
	for 줄 in 2:
		for i in 칸수:
			if i % 2 != 줄:
				continue
			var 앞뒤 := -1.0 if 줄 == 0 else 1.0
			var 간격 := minf(3.0, 가시높이 * 0.12) if 방향 == 0 and 깊이 > 0.0 and 칸수 > 1 else 0.0
			var 중심 := Vector2(-폭 * 0.5 + 32.0 * (i + 0.5) + 앞뒤 * 간격 * 18.0 / 22.0, 가시높이 * 0.5 + 앞뒤 * 간격)
			_개별_가시(중심, posmod(씨앗 + i * 83492791, 변형_수))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _개별_가시(중심: Vector2, 변형: int) -> void:
	var 배율 := 가시높이 / 그림_상자
	# 타원 아래쪽을 어둡게 남겨 원형 금속 소켓의 두께와 바닥 접촉을 보여 준다. 연속 은색 막대는 없앤다.
	_타원(중심 + Vector2(1, 2.0 * 배율), Vector2(14, 4.0 * 배율), Color(0, 0, 0, 0.35))
	_타원(중심, Vector2(13, 4.5 * 배율), Color(0.055, 0.055, 0.055))
	_타원(중심 + Vector2(0, -1.3 * 배율), Vector2(11.5, 3.4 * 배율), Color(0.30, 0.31, 0.31))
	_타원(중심 + Vector2(-0.6, -2.0 * 배율), Vector2(10, 2.4 * 배율), Color(0.52, 0.53, 0.53))
	# 기존 주철의 날/음영/거친 결은 유지하되 넓은 판을 잘라내고 좁힌 말뚝을 개별 소켓에 박는다.
	var 원본 := Rect2(칸_그림폭 * 변형, 그림_여백, 칸_그림폭, 16.0)
	var 목적 := Rect2(중심 + Vector2(-10, -가시높이), Vector2(20, 가시높이 - 2.0 * 배율))
	draw_texture_rect_region(주철_가시, 목적, 원본)


func _타원(중심: Vector2, 반경: Vector2, 색: Color) -> void:
	var 점들 := PackedVector2Array()
	for i in 32:
		var 각도 := TAU * float(i) / 32.0
		점들.append(중심 + Vector2(cos(각도), sin(각도)) * 반경)
	draw_colored_polygon(점들, 색)
