extends Node2D
## [2026-07-17 도형 · v3] 프로토 총: 포물선(포트리스식) 발사 + 우클릭 조준 궤적.
## v3 변경:
##  · 직선 발사 폐기 → 중력 포물선. 좌클릭 = 발사, 파워는 "입~마우스 거리"에 비례
##    (가까우면 살짝 뱉고, 멀면 세게 뱉는 포트리스 방식).
##  · 우클릭(홀드) = 예상 궤적을 "흐릿한 점선"으로 표시. 지형에 닿으면 그 지점에서 끊김.
##  · 발사 원점 = 입(MOUTH_POS에 부착된 이 노드의 위치). look_at 회전 제거 —
##    공룡 입에서 나가는 연출이므로 총 노드 자체는 회전하지 않는다.
##  · 우클릭은 project.godot 무수정 원칙에 따라 액션 등록 없이 마우스 버튼을 직접 읽는다.
## E 회수는 v2 그대로 유지.
class_name ProtoGun

signal fired   ## 발사 순간 (zone_lab 이 받아 공룡 입 벌림 연출에 사용)

const BULLET_SCENE: PackedScene = preload("res://scenes/proto/ProtoBullet.tscn")

# ── 포물선 파라미터 (ProtoBullet 과 동일한 중력을 써야 궤적이 정확함) ──
const GRAVITY: float = 1400.0       ## 총알 중력 (플레이어 1200보다 살짝 무겁게 = 손맛)
const POWER_MIN: float = 450.0      ## 최소 초속 (마우스가 입에 붙어 있을 때)
const POWER_MAX: float = 1350.0     ## 최대 초속 (마우스가 멀 때)
const DIST_MIN: float = 40.0        ## 이 거리 이하 = POWER_MIN
const DIST_MAX: float = 420.0       ## 이 거리 이상 = POWER_MAX

# ── 조준 궤적(점선) 파라미터 ─────────────────────────────────────────
const TRAJ_STEP: float = 1.0 / 60.0   ## 시뮬레이션 시간 간격
const TRAJ_MAX_TIME: float = 2.0      ## 최대 시뮬레이션 시간 (ProtoBullet lifetime 과 동일)
const TRAJ_DOT_EVERY: int = 4         ## 몇 스텝마다 점 하나 (점선 간격)
const TRAJ_DOT_RADIUS: float = 3.0    ## [2026-07-22] 2.5 → 3.0 (조금 키워 가독↑)
## ── [2026-07-22 도형 · 가시성 개선] ────────────────────────────────────
## 기존엔 "은은하게" 의도로 중간 회색(알파 0.32→0.10)만 썼는데, 실제로 배경(흑/백 지형)에
## 묻혀 안 보인다는 게 최초 피드백이자 개발 바이블 Chapter 5.3 의 핵심 지적이었다.
## 원인: 단일 회색은 흑 지형 위에선 어둡고, 백 지형 위에선 밝아 어느 쪽에서도 대비가 약하다.
## 해결: 점을 "어두운 외곽 링 + 밝은 코어" 2겹으로 그린다 → 흰 배경에선 링이, 검은 배경에선
##       코어가 보여 **어느 지형 위에서도 대비가 살아난다**(외곽선 트릭). 알파도 크게 올린다.
const TRAJ_CORE_COLOR: Color = Color(0.95, 0.95, 0.95)  ## 밝은 코어 (검은 지형에서 보임)
const TRAJ_RING_COLOR: Color = Color(0.05, 0.05, 0.05)  ## 어두운 외곽 링 (흰 지형에서 보임)
const TRAJ_ALPHA_START: float = 0.85   ## 입 근처 = 또렷
const TRAJ_ALPHA_END: float = 0.35     ## 먼 쪽 = 옅게(하지만 예전 0.10 보다 훨씬 진하게)
const TRAJ_RING_EXTRA: float = 1.4     ## 외곽 링이 코어보다 이만큼 큼(px)
## 점선이 표적을 향해 "흐르는" 애니메이션 속도(점 간격/초) — 발사 방향을 직관적으로 알림
const TRAJ_FLOW_SPEED: float = 6.0
## 탄착 마커: 궤적이 지형에 실제로 닿았을 때만 빨간 원으로 "여기 맞음"을 또렷하게 표시
const TRAJ_HIT_COLOR: Color = Color(1.0, 0.25, 0.2, 0.9)

## PaintSystem(v2) 또는 TilePaintMap — on_hit/recover 이름을 공유하므로 타입을 좁히지 않는다.
var paint_system: Node
var terrain: TileMapLayer
var player: Node          # player.gd (player_color 를 읽기만 함)

## ★[2026-07-24 도형] 페인트 v3(플랫폼 단위) 스테이지용 회수 매니저.
## 설정되면 E 회수를 타일맵(PaintSystem) 대신 이쪽으로 보낸다.
## 비어 있으면 기존 zone_01/02/world_1 동작 그대로 — 회귀 없음.
var 페인트매니저: Node = null

var _aiming: bool = false
var _traj_points: PackedVector2Array = PackedVector2Array()   # 전역 좌표
var _traj_hit: bool = false   ## [2026-07-22] 마지막 궤적이 지형에 닿아 끊겼는지(=탄착 마커 표시 여부)
var _flow_time: float = 0.0   ## [2026-07-22] 점선 흐름 애니메이션용 시간 누적

func setup(ps: Node, layer: TileMapLayer, p: Node) -> void:
	paint_system = ps
	terrain      = layer
	player       = p

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("shoot"):
		_shoot()

	# 우클릭 홀드 = 조준 모드. 액션 미등록(project.godot 무수정) — 버튼 직접 읽기.
	var aiming_now := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if aiming_now != _aiming:
		_aiming = aiming_now
		if not _aiming:
			_traj_points = PackedVector2Array()
		queue_redraw()

	# [2026-07-22 도형] 조준 중에는 점선이 표적 쪽으로 흐르도록 시간을 누적하고 매 프레임 다시 그린다.
	if _aiming:
		_flow_time += delta * TRAJ_FLOW_SPEED
		queue_redraw()

func _physics_process(_delta: float) -> void:
	# 궤적 시뮬레이션은 물리 스냅샷(direct_space_state)을 쓰므로 physics 프레임에서 갱신.
	if _aiming:
		_traj_points = _simulate_trajectory()
		queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	# E = 회수 (액션 미등록: project.godot 무수정 원칙)
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_E:
		# [2026-07-24 도형] v3 스테이지면 플랫폼 매니저가, 아니면 기존 타일맵이 회수한다.
		if 페인트매니저 != null:
			페인트매니저.되돌리기()
		elif paint_system != null and terrain != null:
			paint_system.recover(terrain)

## 입~마우스 거리·방향 → 발사 초속 벡터 (포트리스식: 멀수록 세게).
func _launch_velocity() -> Vector2:
	var to_mouse := get_global_mouse_position() - global_position
	var t := clampf(
		(to_mouse.length() - DIST_MIN) / (DIST_MAX - DIST_MIN), 0.0, 1.0)
	return to_mouse.normalized() * lerpf(POWER_MIN, POWER_MAX, t)

func _shoot() -> void:
	# ★[2026-08-17] 탄약 검사. 예전에는 아무한테도 안 묻고 그냥 쐈다.
	# ⚠ 덕 타이핑으로 확인한다 — 이 총은 zone_01/02/world_1 의 `PaintSystem` 도 쓰는데
	#   그쪽엔 탄약이 없다. 메서드 유무로 갈라야 **그 스테이지들이 안 깨진다.**
	if paint_system != null and paint_system.has_method("쏠_수_있나"):
		if not paint_system.쏠_수_있나():
			return
		paint_system.발사_소모()

	var color: int = player.get("player_color")
	var bullet := BULLET_SCENE.instantiate()
	bullet.setup(paint_system, color, _launch_velocity(), GRAVITY)
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position   # 발사 원점 = 입
	fired.emit()

## 발사와 동일한 물리로 궤적을 미리 계산. 지형에 닿으면 그 지점에서 자르고,
## 마지막에 탄착점을 넣어 점선이 "벽에 닿아 끊긴" 느낌을 준다.
func _simulate_trajectory() -> PackedVector2Array:
	var points := PackedVector2Array()
	var space := get_world_2d().direct_space_state
	var exclude: Array[RID] = []
	if player is CollisionObject2D:
		exclude.append((player as CollisionObject2D).get_rid())

	var pos := global_position
	var vel := _launch_velocity()
	points.append(pos)

	_traj_hit = false   # [2026-07-22] 이번 시뮬이 지형에 닿았는지 초기화
	var steps := int(TRAJ_MAX_TIME / TRAJ_STEP)
	for i in steps:
		vel.y += GRAVITY * TRAJ_STEP
		var next := pos + vel * TRAJ_STEP
		var query := PhysicsRayQueryParameters2D.create(pos, next)
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit:
			points.append(hit["position"])   # 탄착점까지만 — 지형 뒤로는 안 그림
			_traj_hit = true                  # [2026-07-22] 지형에 닿아 끊김 → 탄착 마커 표시
			break
		pos = next
		points.append(pos)
	return points

func _draw() -> void:
	if not _aiming or _traj_points.size() < 2:
		return
	# Player 가 비균등 스케일(0.795, 0.368)이라 로컬 좌표로 그리면 점이 찌그러진다.
	# 전역 변환의 역행렬을 걸어 "월드 좌표 그대로" 그린다 (점 = 항상 동그란 원).
	draw_set_transform_matrix(get_global_transform().affine_inverse())
	var n := _traj_points.size()
	# [2026-07-22 도형] 점선 흐름: 시작 인덱스를 시간에 따라 밀어 점들이 표적 쪽으로 흐르게.
	var phase := int(_flow_time) % TRAJ_DOT_EVERY
	for i in range(phase, n, TRAJ_DOT_EVERY):
		var fade := float(i) / float(n)
		var a := lerpf(TRAJ_ALPHA_START, TRAJ_ALPHA_END, fade)
		# 2겹 그리기: 먼저 어두운 외곽 링(흰 지형에서 보임) → 그 위에 밝은 코어(검은 지형에서 보임).
		# 두 색이 함께 있어 흑/백 어떤 배경에서도 점의 대비가 유지된다.
		var ring := TRAJ_RING_COLOR;  ring.a = a
		var core := TRAJ_CORE_COLOR;  core.a = a
		draw_circle(_traj_points[i], TRAJ_DOT_RADIUS + TRAJ_RING_EXTRA, ring)
		draw_circle(_traj_points[i], TRAJ_DOT_RADIUS, core)
	# 탄착 마커: 지형에 실제로 닿은 경우에만 빨간 원 + 링으로 "여기 맞음"을 또렷하게 표시.
	# (최대 사거리까지 날아가 안 닿은 경우엔 마커를 그리지 않아 오해를 막는다.)
	if _traj_hit:
		var end := _traj_points[n - 1]
		draw_circle(end, TRAJ_DOT_RADIUS + TRAJ_RING_EXTRA + 2.0, TRAJ_RING_COLOR)  # 어두운 테두리
		draw_circle(end, TRAJ_DOT_RADIUS + 2.0, TRAJ_HIT_COLOR)                     # 빨간 탄착점
