extends Node2D
## ============================================================================
## [2026-08-01 신규] 페인트 총 — 조준 / 발사 / 덤불 내부 판정
## ----------------------------------------------------------------------------
## ▣ Player.tscn 무수정 원칙
##   기존 `scripts/gun.gd` 는 총알을 직접 만들어 쏜다(구 시스템). 그걸 고치면
##   다른 스테이지가 깨진다. 그래서 **런타임에 Gun 노드의 _process 를 꺼두고**
##   조준(look_at)과 발사를 여기서 대신한다.
##   → 동현 테스트월드제작.gd 가 쓰던 것과 똑같은 방식이다.
##
## ▣ 탄약 규칙 (페인트_코어.gd)
##   쏠 때 1발 소모 → 빗나가거나 못 칠하는 대상이면 코어가 그 자리에서 환급한다.
##   그래서 "허공에 쏘면 손해"가 아니라 "맞혀야만 잠긴다" 는 규칙이 성립한다.
##
## ▣ 덤불(식물 B) 안에서 쏠 때 (기획 규칙)
##   총구가 덤불 안이고 **커서도 덤불 안**이면 → 덤불이 칠해진다(투사체 없음).
##   총구가 덤불 안이지만 **커서가 덤불 밖**이면 → 총알이 덤불을 뚫고 나간다.
##
## ▣ [2026-08-07 추가] 우클릭 조준 궤적
##   도형님 제보: "스마트월드는 우클릭을 눌러도 포물선 경로가 안 나와서 불편하다."
##   `stage_1-1, 1-2`(v3)는 `proto_gun.gd` 가 궤적을 그려주는데 스마트월드는
##   총이 다른 파일(이 파일)이라 그 기능이 없었다.
##   → **총알.gd 와 완전히 같은 물리**로 미리 굴려 점선을 찍는다.
##     같은 물리를 쓰는 게 핵심이다. 조금이라도 다르면 "보이는 곳과 다른 데 맞는"
##     조준선이 되어 없느니만 못하다.
## ============================================================================
class_name 페인트총

const 총알_스크립트 := preload("res://scripts/스마트월드/총알.gd")

## 총구를 떠나는 속력(px/s). 낮출수록 탄낙차가 커진다.
@export var 탄속: float = 1150.0
## 연사 간격(초).
@export var 발사간격: float = 0.22

# ── 조준 궤적 ───────────────────────────────────────────────────────────────
## ★총알.gd 와 반드시 같아야 하는 값들. 한쪽만 바꾸면 조준선이 거짓말을 한다.
const 궤적_중력: float = 총알_스크립트.중력          # 900.0
const 궤적_단단한레이어: int = 총알_스크립트.단단한_레이어   # 1 | 8
const 궤적_최대수명: float = 총알_스크립트.최대_수명      # 3.0

const 궤적_간격: float = 1.0 / 60.0    ## 시뮬레이션 시간 간격(총알과 같은 물리 프레임)
const 궤적_점마다: int = 4             ## 몇 스텝마다 점 하나 (점선 간격)
const 궤적_점크기: float = 3.0
## 흑백 게임이라 단색 점은 어느 한쪽 배경에서 반드시 묻힌다.
## → 어두운 링 + 밝은 코어 2겹으로 그려 **양쪽 배경에서 모두** 보이게 한다.
##   (proto_gun.gd 가 2026-07-22 에 같은 이유로 도입한 문법을 그대로 따랐다)
const 궤적_코어색: Color = Color(0.95, 0.95, 0.95)
const 궤적_링색: Color = Color(0.05, 0.05, 0.05)
const 궤적_링여유: float = 1.4
const 궤적_알파_시작: float = 0.85
const 궤적_알파_끝: float = 0.35
const 궤적_흐름속도: float = 6.0       ## 점선이 표적 쪽으로 흐르는 속도(점/초)
const 궤적_탄착색: Color = Color(1.0, 0.25, 0.2, 0.9)

var 플레이어: Node2D = null
var 코어: 페인트코어 = null

var _gun: Node2D = null
var _muzzle: Marker2D = null
var _쿨: float = 0.0

var _조준중: bool = false
var _궤적: PackedVector2Array = PackedVector2Array()   ## 월드 좌표
var _궤적_닿음: bool = false                            ## 지형에 닿아 끊겼나(탄착 마커용)
var _흐름: float = 0.0


func 연결(p_player: Node2D, p_코어: 페인트코어) -> void:
	플레이어 = p_player
	코어 = p_코어
	# [2026-08-23] Gun 이 GunRig(역스케일 노드) 아래로 내려갔다 — `총_받침.gd` 참고.
	#   예전 씬도 열리게 옛 경로를 대비책으로 남긴다.
	_gun = 플레이어.get_node_or_null("GunRig/Gun") as Node2D
	if _gun == null:
		_gun = 플레이어.get_node_or_null("Gun") as Node2D
	if _gun:
		# 구 gun.gd 의 자동 발사를 끈다 — 조준은 우리가 대신 돌려준다.
		_gun.set_process(false)
		_muzzle = _gun.get_node_or_null("Muzzle") as Marker2D
	# 조준선은 지형·오브젝트보다 위에 보여야 한다. 총알(30)보다 살짝 아래로 둔다.
	z_index = 28


func _process(delta: float) -> void:
	_쿨 = maxf(_쿨 - delta, 0.0)
	if _gun and is_instance_valid(_gun):
		_gun.look_at(get_global_mouse_position())

	# ── 우클릭 홀드 = 조준 모드 ──
	# project.godot 무수정 원칙: 액션을 새로 등록하지 않고 마우스 버튼을 직접 읽는다.
	var 지금조준 := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if 지금조준 != _조준중:
		_조준중 = 지금조준
		if not _조준중:
			_궤적 = PackedVector2Array()
		queue_redraw()
	if _조준중:
		_흐름 += delta * 궤적_흐름속도
		queue_redraw()


func _physics_process(_delta: float) -> void:
	# 궤적은 물리 스냅샷(direct_space_state)을 쓰므로 물리 프레임에서 갱신한다.
	if _조준중:
		_궤적 = _궤적_계산()
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shoot"):
		발사()


func 발사() -> void:
	if _쿨 > 0.0 or 플레이어 == null or 코어 == null:
		return
	var 시작 := _muzzle.global_position if _muzzle else 플레이어.global_position
	var 커서 := get_global_mouse_position()
	# 발사 순간의 얼굴색을 직접 읽는다. 대표색은 물리 프레임마다 갱신되므로,
	# 여기서는 이전 프레임 값이 아니라 현재 조준 쪽 입의 색을 써야 한다.
	var 색: int = 플레이어.call("얼굴색", 커서.x - 플레이어.global_position.x) \
		if 플레이어.has_method("얼굴색") else 플레이어.get("player_color")

	# ── 덤불 안에서 쏘는 경우 ──
	var 덤불 := _총구가_속한_덤불(시작)
	if 덤불 != null and 덤불.안에_있나(커서):
		if not 코어.쏠_수_있나():
			return
		_쿨 = 발사간격
		코어.발사_소모()
		코어.명중_처리(덤불, 색, 커서)
		return

	# ── 평범한 발사 ──
	if not 코어.쏠_수_있나():
		return
	var 방향 := 커서 - 시작
	if 방향.length() < 4.0:
		return
	_쿨 = 발사간격
	코어.발사_소모()

	var 총알 := Area2D.new()
	총알.set_script(총알_스크립트)
	get_parent().add_child(총알)
	총알.시작(시작, 방향, 탄속, 색, 코어)


## 총구가 어느 덤불 안에 있는지. 없으면 null.
func _총구가_속한_덤불(총구: Vector2) -> 식물B:
	for n in get_tree().get_nodes_in_group("식물B"):
		var b := n as 식물B
		if b and b.안에_있나(총구):
			return b
	return null


# ============================================================================
# 조준 궤적 (우클릭 홀드)
# ============================================================================

## 발사 원점. 발사()와 **같은 식**을 써야 조준선과 실탄이 어긋나지 않는다.
func _발사_원점() -> Vector2:
	if _muzzle and is_instance_valid(_muzzle):
		return _muzzle.global_position
	return 플레이어.global_position if 플레이어 else global_position


## 총구를 떠나는 초속도. 총알.시작() 안의 `방향.normalized() * 속력` 과 동일하다.
func _발사_속도() -> Vector2:
	var 시작 := _발사_원점()
	var 방향 := get_global_mouse_position() - 시작
	if 방향.length() < 4.0:
		return Vector2.ZERO
	return 방향.normalized() * 탄속


## 총알.gd 의 `_physics_process` 를 그대로 앞당겨 굴린다.
## ▣ 같은 것을 반드시 지킨다
##   · 중력 900 을 **속도에 먼저** 더하고 그 다음 위치를 옮긴다 (순서가 다르면 궤적이 어긋난다)
##   · 송풍기 바람도 같이 받는다 — 바람 구간에서 조준선만 곧게 가면 거짓말이 된다
##   · 단단한 지형은 이전→다음 구간 **레이캐스트**로 본다 (총알과 같은 터널링 방지)
func _궤적_계산() -> PackedVector2Array:
	var 점들 := PackedVector2Array()
	_궤적_닿음 = false

	var 속도 := _발사_속도()
	if 속도 == Vector2.ZERO:
		return 점들

	var 공간 := get_world_2d().direct_space_state
	var 제외: Array[RID] = []
	if 플레이어 is CollisionObject2D:
		제외.append((플레이어 as CollisionObject2D).get_rid())

	var 위치 := _발사_원점()
	점들.append(위치)

	# 송풍기는 매 스텝 물어보면 비싸다. 개수가 적으니 목록만 미리 받아둔다.
	var 송풍기들 := get_tree().get_nodes_in_group("송풍기")

	var 스텝수 := int(궤적_최대수명 / 궤적_간격)
	for _i in 스텝수:
		속도.y += 궤적_중력 * 궤적_간격
		for n in 송풍기들:
			var 힘: Vector2 = n.바람(위치)
			if 힘 != Vector2.ZERO:
				속도 += 힘 * 궤적_간격

		var 다음 := 위치 + 속도 * 궤적_간격
		var 질의 := PhysicsRayQueryParameters2D.create(위치, 다음, 궤적_단단한레이어)
		질의.collide_with_areas = false
		질의.exclude = 제외
		var 결과 := 공간.intersect_ray(질의)
		if 결과:
			점들.append(결과["position"])     # 탄착점까지만 — 지형 뒤로는 안 그린다
			_궤적_닿음 = true
			break
		위치 = 다음
		점들.append(위치)
	return 점들


func _draw() -> void:
	if not _조준중 or _궤적.size() < 2:
		return
	# 이 노드는 월드 바로 아래(원점 0)라 보통은 로컬 = 월드지만,
	# 누가 총을 다른 노드 밑으로 옮겨도 점이 어긋나지 않게 역행렬을 걸어둔다.
	draw_set_transform_matrix(get_global_transform().affine_inverse())

	var n := _궤적.size()
	# 점선 흐름 — 시작 인덱스를 시간에 따라 밀어 점이 표적 쪽으로 흐르게 한다.
	# (정지된 점선은 "선"으로 보이고, 흐르면 "날아가는 방향"이 직관적으로 읽힌다)
	var 위상 := int(_흐름) % 궤적_점마다
	for i in range(위상, n, 궤적_점마다):
		var 페이드 := float(i) / float(n)
		var a := lerpf(궤적_알파_시작, 궤적_알파_끝, 페이드)
		var 링 := 궤적_링색;   링.a = a
		var 코어색 := 궤적_코어색; 코어색.a = a
		draw_circle(_궤적[i], 궤적_점크기 + 궤적_링여유, 링)
		draw_circle(_궤적[i], 궤적_점크기, 코어색)

	# 탄착 마커 — **실제로 지형에 닿았을 때만** 그린다.
	# (최대 사거리까지 날아가 안 닿은 경우에 마커를 그리면 "여기 맞는다"는 거짓말이 된다)
	if _궤적_닿음:
		var 끝 := _궤적[n - 1]
		draw_circle(끝, 궤적_점크기 + 궤적_링여유 + 2.0, 궤적_링색)
		draw_circle(끝, 궤적_점크기 + 2.0, 궤적_탄착색)
