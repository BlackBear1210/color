extends Camera2D
## [2026-07-18 도형 · 신규] 플랫포머 전용 카메라 v2 — "전방이 보이는" 카메라.
##
## 기존 문제: Player.tscn 안의 기본 Camera2D 는 플레이어에 딱 고정되어
## 빠르게 달릴 때 진행 방향 앞이 화면의 절반밖에 안 보였고, 반대로
## position_smoothing 을 세게 걸면 카메라가 뒤로 처져 전방 확인이 더 안 됐다.
##
## 설계 근거 (Itay Keren, GDC 2015 "Scroll Back: The Theory and Practice of
## Cameras in Side-Scrollers" — 셀레스트/마리오 등 대부분의 플랫포머가 쓰는 문법):
##  1. 룩어헤드(lookahead): 카메라 중심을 "이동 방향 앞쪽"으로 밀어서
##     달릴수록 전방이 더 넓게 보이게 한다. 방향 전환 시에는 즉시 홱 돌지 않고
##     일정 속도로 부드럽게 옮겨가 멀미를 막는다 (lookahead easing).
##  2. 수평 = 빠른 추적: 스무딩을 약하게(반응 빠르게) 해서 조작 지연감을 없앤다.
##     "부드러움"은 수평 지연이 아니라 룩어헤드 이동의 완만함으로 얻는다.
##  3. 수직 = 플랫폼 스냅(platform snapping): 점프 중에는 카메라 y 를 지면에
##     고정해 화면이 출렁이지 않게 하고, 착지해서 지면 높이가 바뀐 순간에만
##     부드럽게 따라간다. 낙하가 길어지면 아래를 미리 보여준다(낙하 룩다운).
##  4. 구역 리밋 전환: limit_* 를 즉시 바꾸면 화면이 순간이동하므로,
##     리밋 사각형 자체를 트윈해서 '바인(Vane)'처럼 구역이 이어지는 팬 연출을 만든다.
##
## 사용법 (존 조립 스크립트에서 런타임 부착 — Player.tscn 무수정):
##   var cam := ProtoCamera.new()
##   zone.add_child(cam)
##   cam.setup(player)                       # 대상 지정 + 즉시 스냅
##   cam.set_limit_rect(Rect2(...), false)   # 초기 리밋 (즉시)
##   cam.set_limit_rect(Rect2(...), true)    # 구역 전환 시 (부드럽게 팬)
class_name ProtoCamera

# ── 튜닝 상수 (체감 조정은 여기서) ──────────────────────────────────────
## 서 있을 때 기본 룩어헤드(px) — 바라보는 방향이 살짝 더 보임
const LOOK_BASE: float = 70.0
## 최고 속도로 달릴 때 룩어헤드(px) — 전방 확인용. 화면폭(1152)의 약 1/6
const LOOK_MAX: float = 190.0
## 룩어헤드 오프셋이 이동하는 속도(px/s) — 방향 전환 시 홱 돌지 않게
const LOOK_SHIFT_SPEED: float = 420.0
## 수평 추적 반응(1/s) — 클수록 딱 붙음. 지연감을 없애려고 높게 잡음
const H_RESPONSE: float = 10.0
## 수직 추적 반응(1/s) — 착지로 지면 높이가 바뀔 때 따라가는 속도
const V_RESPONSE: float = 6.0
## 카메라 중심을 발밑보다 이만큼 위로 (머리 위 공간 확보)
const EYE_LIFT: float = 60.0
## 공중에서 플레이어가 화면 위/아래로 이만큼 벗어나면 그때만 수직 추적
const AIR_WINDOW_UP: float = 140.0
const AIR_WINDOW_DOWN: float = 110.0
## 빠른 낙하 시 아래를 미리 보여주는 최대 거리(px)와 반응 기준 낙하속도
const FALL_LOOKDOWN_MAX: float = 130.0
const FALL_SPEED_REF: float = 1300.0
## 구역 리밋 전환(팬) 시간(초) — 바인식 "구역이 이어지는" 연출의 핵심
const LIMIT_TWEEN_TIME: float = 1.1

var target: CharacterBody2D = null       # 따라갈 플레이어
var _look_x: float = 0.0                 # 현재 룩어헤드 오프셋 (부드럽게 이동)
var _face: float = 1.0                   # 마지막 바라본 방향 (+1/-1)
var _ground_y: float = 0.0               # 마지막으로 밟았던 지면 y (플랫폼 스냅 기준)
var _fall_look: float = 0.0              # 낙하 룩다운 오프셋 (부드럽게)
var _limits: Rect2 = Rect2()             # 현재 적용 중인 리밋 (트윈 대상)
var _has_limits: bool = false
var _limit_tween: Tween = null
var _zoom_tween: Tween = null

func _ready() -> void:
	# 스무딩은 우리가 직접 계산하므로 내장 스무딩은 끔 (이중 지연 방지)
	position_smoothing_enabled = false
	# 플레이어 이동(_physics_process)이 끝난 뒤에 따라가도록 우선순위를 뒤로
	process_physics_priority = 100
	make_current()

## 대상 지정 + 첫 프레임 순간이동 스냅 (씬 시작 시 카메라가 날아오는 것 방지)
func setup(p_target: CharacterBody2D) -> void:
	target = p_target
	_ground_y = target.global_position.y
	_face = 1.0
	_look_x = LOOK_BASE
	global_position = _desired_center()
	if _has_limits:
		global_position = _clamp_to_limits(global_position)

## 리밋 사각형 지정. animate=true 면 이전 리밋에서 새 리밋으로 트윈(구역 전환 팬)
func set_limit_rect(rect: Rect2, animate: bool = false) -> void:
	if _limit_tween:
		_limit_tween.kill()
		_limit_tween = null
	if not _has_limits or not animate:
		_limits = rect
		_has_limits = true
		return
	# Rect2 를 통째로 보간 — 화면이 순간이동하지 않고 흘러가듯 넘어간다
	var from := _limits
	_limit_tween = create_tween()
	_limit_tween.tween_method(
		func(t: float) -> void:
			_limits = Rect2(from.position.lerp(rect.position, t),
				from.size.lerp(rect.size, t)),
		0.0, 1.0, LIMIT_TWEEN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

## 구역별 줌 (GDC "Scroll Back" / Hollow Knight 식 구역별 카메라 변주).
## 높은 구역에 들어설 때 살짝 줌아웃하면 "새 지역이 눈앞에 펼쳐진다"는 연출이 된다.
## 리밋 트윈과 같은 시간으로 함께 흘러가야 한 호흡의 전환으로 읽힌다.
func set_region_zoom(target_zoom: float, animate: bool = false) -> void:
	if _zoom_tween:
		_zoom_tween.kill()
		_zoom_tween = null
	if not animate:
		zoom = Vector2.ONE * target_zoom
		return
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(self, "zoom", Vector2.ONE * target_zoom, LIMIT_TWEEN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return

	# ── 1) 룩어헤드: 이동 방향 앞쪽으로 카메라 중심을 민다 ─────────────
	var vx := target.velocity.x
	if absf(vx) > 5.0:
		_face = signf(vx)
	# 속도가 빠를수록 더 멀리 본다 (LOOK_BASE → LOOK_MAX)
	var speed_ratio: float = clampf(absf(vx) / 390.0, 0.0, 1.0)   # 390 = player move_speed
	var look_target := _face * lerpf(LOOK_BASE, LOOK_MAX, speed_ratio)
	# 목표 오프셋으로 "일정 속도" 이동 — 방향 전환이 부드럽다 (Keren: lookahead easing)
	_look_x = move_toward(_look_x, look_target, LOOK_SHIFT_SPEED * delta)

	# ── 2) 수직: 플랫폼 스냅 ────────────────────────────────────────────
	var py := target.global_position.y
	if target.is_on_floor():
		_ground_y = py            # 착지한 지면을 새 기준으로
	else:
		# 공중이라도 화면 밖으로 벗어나려 하면 그때만 따라간다
		if py < _ground_y - AIR_WINDOW_UP:
			_ground_y = py + AIR_WINDOW_UP
		elif py > _ground_y + AIR_WINDOW_DOWN:
			_ground_y = py - AIR_WINDOW_DOWN

	# 빠른 낙하 중에는 아래를 미리 보여준다 (착지 지점 확인용)
	var fall_target := 0.0
	if not target.is_on_floor() and target.velocity.y > 300.0:
		fall_target = FALL_LOOKDOWN_MAX * clampf(target.velocity.y / FALL_SPEED_REF, 0.0, 1.0)
	_fall_look = lerpf(_fall_look, fall_target, 1.0 - exp(-4.0 * delta))

	# ── 3) 목표점으로 지수 스무딩 (프레임률 독립) ───────────────────────
	var desired := _desired_center()
	var kx := 1.0 - exp(-H_RESPONSE * delta)
	var ky := 1.0 - exp(-V_RESPONSE * delta)
	var pos := global_position
	pos.x = lerpf(pos.x, desired.x, kx)
	pos.y = lerpf(pos.y, desired.y, ky)

	# ── 4) 구역 리밋으로 클램프 (리밋 자체가 트윈되므로 전환도 부드러움) ─
	if _has_limits:
		pos = _clamp_to_limits(pos)
	global_position = pos

## 카메라가 가야 할 이상적 중심점
func _desired_center() -> Vector2:
	return Vector2(
		target.global_position.x + _look_x,
		_ground_y - EYE_LIFT + _fall_look)

## 뷰포트 절반 크기를 고려해 카메라 중심을 리밋 안으로 (리밋이 화면보다 작으면 중앙 고정)
func _clamp_to_limits(pos: Vector2) -> Vector2:
	var half := get_viewport_rect().size * 0.5 / zoom
	if _limits.size.x > half.x * 2.0:
		pos.x = clampf(pos.x, _limits.position.x + half.x, _limits.end.x - half.x)
	else:
		pos.x = _limits.get_center().x
	if _limits.size.y > half.y * 2.0:
		pos.y = clampf(pos.y, _limits.position.y + half.y, _limits.end.y - half.y)
	else:
		pos.y = _limits.get_center().y
	return pos
