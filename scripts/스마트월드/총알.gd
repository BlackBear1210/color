extends Area2D
## ============================================================================
## [2026-08-01 신규] 페인트 투사체 — 탄낙차(포물선) 있음
## ----------------------------------------------------------------------------
## ▣ 왜 Area2D 인가 (CharacterBody2D 가 아니라)
##   총알은 "단단한 지형"과 "통과하는 오브젝트(물·덤불·연기)"를 **둘 다** 만나야 한다.
##   CharacterBody2D 는 앞의 것만, Area2D 는 뒤의 것만 잘 잡는다.
##   → Area2D 로 두고, 단단한 지형은 매 프레임 **직접 레이캐스트**해서 정확한
##     명중 지점을 얻는다. 빠른 총알이 얇은 발판을 뚫고 지나가는 문제도 같이 해결된다.
##
## ▣ 물리 레이어 약속
##   1  : 밟을 수 있는 지형 (SS2D 지형·통과플랫폼)
##   8  : 무색 유령 지형 (플레이어는 통과하지만 총알은 맞는다)
##   16 : 색칠 가능한 "통과형" 오브젝트 (식물 B 덤불 등)
##   32 : 유체(물·연기) — 반대색 총알을 막는다
## ============================================================================
class_name 페인트총알

const 단단한_레이어: int = 1 | 8
const 중력: float = 900.0
const 최대_수명: float = 3.0

var 색: int = ColorDefs.BLACK
var _속도: Vector2 = Vector2.ZERO
var _수명: float = 0.0
var _코어: 페인트코어 = null
var _행동효과: Node = null
var _끝남: bool = false
var _꼬리: PackedVector2Array = PackedVector2Array()

## [디버그전용] 바람에 노출된 구간을 통째로 비교하려고 진입 시점 값을 기억해둔다.
var _바람_프레임: int = 0
var _바람_시작속도: Vector2 = Vector2.ZERO
var _바람_시작위치: Vector2 = Vector2.ZERO


func 시작(시작점: Vector2, 방향: Vector2, 속력: float, 색상: int, 코어: 페인트코어, 행동효과: Node = null) -> void:
	global_position = 시작점
	_속도 = 방향.normalized() * 속력
	색 = 색상
	_코어 = 코어
	_행동효과 = 행동효과


func _ready() -> void:
	# 자기 자신은 아무에게도 안 잡히고(layer 0), 프롭·유체만 감지한다.
	collision_layer = 0
	collision_mask = 16 | 32
	monitoring = true
	var 모양 := CollisionShape2D.new()
	var 원 := CircleShape2D.new()
	원.radius = 5.0
	모양.shape = 원
	add_child(모양)
	z_index = 30


func _physics_process(delta: float) -> void:
	if _끝남:
		return
	_수명 += delta
	if _수명 > 최대_수명:
		_소멸(null, global_position)
		return

	# 탄낙차 — 기획의 "투사체로 탄낙차가 있음"
	_속도.y += 중력 * delta

	# 송풍기 바람 — 기획의 "페인트 투사체의 경로에 영향을 준다".
	# 송풍기가 총알을 감지하는 게 아니라 총알이 물어본다 (총알은 레이어 0 이라 안 잡힌다).
	for n in get_tree().get_nodes_in_group("송풍기"):
		var 힘: Vector2 = n.바람(global_position)
		if 힘 != Vector2.ZERO:
			if _바람_프레임 == 0:
				_바람_시작속도 = _속도
				_바람_시작위치 = global_position
			_바람_프레임 += 1
			_속도 += 힘 * delta
	var 이전 := global_position
	var 다음 := 이전 + _속도 * delta

	# ── 1) 통과형 오브젝트(덤불·물·연기) 먼저 확인 ──
	for 영역 in get_overlapping_areas():
		if 영역.has_method("총알_막나") and 영역.총알_막나(색):
			_소멸(null, 이전)          # 반대색 물이 막았다 → 페인트는 사라짐(회수 안 됨)
			return
		if 영역.has_method("명중"):
			_소멸(영역, 이전, true)
			return

	# ── 2) 단단한 지형: 이전→다음 구간을 레이캐스트 (터널링 방지) ──
	var 공간 := get_world_2d().direct_space_state
	var 질의 := PhysicsRayQueryParameters2D.create(이전, 다음, 단단한_레이어)
	질의.collide_with_areas = false
	var 결과 := 공간.intersect_ray(질의)
	if 결과:
		var 맞은것: Object = 결과.get("collider")
		_소멸(_칠할대상_찾기(맞은것), 결과["position"], true)
		return

	global_position = 다음
	rotation = _속도.angle()
	_꼬리.append(다음)
	if _꼬리.size() > 8:
		_꼬리.remove_at(0)
	queue_redraw()


## 콜리전 바디에서 "칠할 수 있는 대상"을 거슬러 올라가 찾는다.
## SS2D 지형은 [지형] → StaticBody2D → CollisionPolygon2D 구조라 부모를 봐야 한다.
func _칠할대상_찾기(맞은것: Object) -> Node:
	var n := 맞은것 as Node
	while n != null:
		if n.has_method("명중"):
			return n
		n = n.get_parent()
	return null


func _소멸(대상: Node, 지점: Vector2, 물감_튐: bool = false) -> void:
	_끝남 = true
	if OS.is_debug_build() and _바람_프레임 > 0:
		var 방향변화 := rad_to_deg(_바람_시작속도.angle_to(_속도))
		print("[총알] 바람 노출 종료 — %d프레임 노출, 시작속도=%s(%.1f°) 종료속도=%s(%.1f°) 방향변화=%.1f° 이동거리=%s" %
			[_바람_프레임, _바람_시작속도, rad_to_deg(_바람_시작속도.angle()),
			 _속도, rad_to_deg(_속도.angle()), 방향변화, _바람_시작위치.distance_to(지점)])
	if _코어:
		_코어.명중_처리(대상, 색, 지점)
	if 물감_튐 and _행동효과 and _행동효과.has_method("명중"):
		_행동효과.명중(지점, _속도, 색)
	queue_free()


func _draw() -> void:
	var c := Color(0.06, 0.06, 0.07) if 색 == ColorDefs.BLACK else Color(0.97, 0.97, 0.95)
	# 진행 방향으로 살짝 늘린 물방울 모양 — 속도감이 보이게
	draw_circle(Vector2.ZERO, 5.0, c)
	draw_line(Vector2(-10, 0), Vector2.ZERO, Color(c.r, c.g, c.b, 0.45), 4.0)
