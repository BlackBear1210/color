extends "res://scripts/ui/페인트_HUD_어댑터.gd"
## ============================================================================
## [2026-08-17 신규] 어댑터 — 페인트 코어(스마트월드)용
## ----------------------------------------------------------------------------
## 대상 = Node (스마트지형 · 무너지는바위 · 물저장고 · 식물 A/B · 통과플랫폼 …)
## 이 시스템에는 탄약(12발)이 있으므로 HUD 가 12칸 줄을 전부 그린다.
##
## ▣ 호버 판정을 왜 물리 조회로 하나
##   "마우스를 얹은 대상"과 "쏘면 맞을 대상"이 다르면 호버 표시가 거짓말이 된다.
##   그래서 `총알.gd` 가 명중을 판정하는 방법(단단한 레이어 + 통과형 Area)을
##   그대로 따라 한 점만 조회한다. 레이어 상수도 총알에서 가져와 **한쪽만 바뀌는 일**을 막는다.
## ============================================================================
class_name 페인트HUD코어어댑터

const 총알_스크립트 := preload("res://scripts/스마트월드/총알.gd")
## ★총알과 반드시 같아야 하는 값. 다르면 "호버는 되는데 총알은 안 맞는" 대상이 생긴다.
const 단단한_레이어: int = 총알_스크립트.단단한_레이어

var _코어: 페인트코어 = null
## 물리 공간을 얻기 위한 기준 노드(HUD 자신). 트리에서 빠지면 조회를 포기한다.
var _기준: Node = null


func _init(코어: 페인트코어, 기준: Node) -> void:
	_코어 = 코어
	_기준 = 기준


func 살아있나() -> bool:
	return _코어 != null and is_instance_valid(_코어)


## 여기서는 발 하나가 곧 자원이고 총량이 12 로 묶여 있다 → 칸으로 센다.
func 발수를_센다() -> bool:
	return true


## ★날아가는 중인 발을 **아직 내 것으로 센다.**
##   탄약은 쏘는 순간 깎이므로 그대로 그리면 한 발에 두 번 바뀐다
##   (쏨 → 칸이 꺼짐 → 착탄 → 다시 켜지거나 빈 칸). 빗나가면 깜빡임만 남는다.
##   이렇게 더해 두면 비행 중에는 아무것도 안 변하고 **착탄 때 딱 한 번** 바뀐다.
##   합계 불변식도 그대로다 — 비행 중인 발은 아직 어느 묶음에도 안 들어갔기 때문이다.
func 탄약() -> Dictionary:
	if not 살아있나():
		return {}
	return { "남은": _코어.남은_탄약 + _코어.비행중(), "최대": _코어.최대_탄약 }


func 회수줄() -> Array:
	if not 살아있나():
		return []
	return _코어.회수줄_요약()


func 잠긴_발수() -> int:
	return _코어.잠긴_발수() if 살아있나() else 0


func 다음_회수대상() -> Variant:
	return _코어.다음_회수대상() if 살아있나() else null


func 대상_발수(대상: Variant) -> int:
	if not 살아있나() or 대상 == null:
		return 0
	return _코어.대상_발수(대상 as Node)


func 유효한가(대상: Variant) -> bool:
	return 대상 is Node and is_instance_valid(대상)


## 대상의 표시 좌표.
## ★우선순위: 코어가 기억해 둔 **마지막 명중 지점** → 없으면 노드 좌표.
##   SS2D 지형은 노드 원점이 도형 한쪽 끝에 있어서, 노드 좌표만 쓰면
##   마커가 지형 저 멀리에 뜬다. "칠한 자리"에 떠야 플레이어가 알아본다.
func 대상_좌표(대상: Variant) -> Vector2:
	if not 유효한가(대상):
		return Vector2.ZERO
	if 살아있나():
		var 기억: Variant = _코어.대상_좌표(대상 as Node)
		if 기억 != null:
			return 기억 as Vector2
	var n := 대상 as Node2D
	return n.global_position if n != null else Vector2.ZERO


func 대상_아래(월드: Vector2) -> Variant:
	if _기준 == null or not _기준.is_inside_tree():
		return null
	var 공간 := _기준.get_viewport().world_2d.direct_space_state
	if 공간 == null:
		return null

	# ── 1) 통과형(덤불·물 등 Area) 먼저 ── 총알도 Area 를 먼저 본다.
	var 질의 := PhysicsPointQueryParameters2D.new()
	질의.position = 월드
	질의.collide_with_areas = true
	질의.collide_with_bodies = true
	질의.collision_mask = 단단한_레이어
	for 결과 in 공간.intersect_point(질의, 8):
		var 대상 := _칠할대상_찾기(결과.get("collider"))
		if 대상 != null:
			return 대상

	# ── 2) 덤불(식물 B)은 콜리전이 아니라 자기 판정 함수를 갖고 있다 ──
	if _기준.is_inside_tree():
		for n in _기준.get_tree().get_nodes_in_group("식물B"):
			if is_instance_valid(n) and n.has_method("안에_있나") and n.안에_있나(월드):
				return n
	return null


## 콜리전에서 "칠할 수 있는 대상"을 거슬러 올라가 찾는다.
## SS2D 지형은 [지형] → StaticBody2D → CollisionPolygon2D 구조라 부모를 봐야 한다.
## (총알.gd `_칠할대상_찾기` 와 같은 문법)
func _칠할대상_찾기(맞은것: Variant) -> Node:
	var n := 맞은것 as Node
	while n != null:
		if n.has_method("명중"):
			return n
		n = n.get_parent()
	return null
