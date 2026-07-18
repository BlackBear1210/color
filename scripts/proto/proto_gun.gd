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
const TRAJ_DOT_RADIUS: float = 2.5
## "너무 잘 보이지 않고 흐릿하게" — 중간 회색 + 낮은 알파라 흑/백 어느 지형 위에서도
## 은은하게만 보인다. 점은 진행할수록 더 옅어진다.
const TRAJ_COLOR: Color = Color(0.5, 0.5, 0.5, 0.32)
const TRAJ_ALPHA_END: float = 0.10

var paint_system: PaintSystem
var terrain: TileMapLayer
var player: Node          # player.gd (player_color 를 읽기만 함)

var _aiming: bool = false
var _traj_points: PackedVector2Array = PackedVector2Array()   # 전역 좌표

func setup(ps: PaintSystem, layer: TileMapLayer, p: Node) -> void:
	paint_system = ps
	terrain      = layer
	player       = p

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("shoot"):
		_shoot()

	# 우클릭 홀드 = 조준 모드. 액션 미등록(project.godot 무수정) — 버튼 직접 읽기.
	var aiming_now := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if aiming_now != _aiming:
		_aiming = aiming_now
		if not _aiming:
			_traj_points = PackedVector2Array()
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
		paint_system.recover(terrain)

## 입~마우스 거리·방향 → 발사 초속 벡터 (포트리스식: 멀수록 세게).
func _launch_velocity() -> Vector2:
	var to_mouse := get_global_mouse_position() - global_position
	var t := clampf(
		(to_mouse.length() - DIST_MIN) / (DIST_MAX - DIST_MIN), 0.0, 1.0)
	return to_mouse.normalized() * lerpf(POWER_MIN, POWER_MAX, t)

func _shoot() -> void:
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

	var steps := int(TRAJ_MAX_TIME / TRAJ_STEP)
	for i in steps:
		vel.y += GRAVITY * TRAJ_STEP
		var next := pos + vel * TRAJ_STEP
		var query := PhysicsRayQueryParameters2D.create(pos, next)
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit:
			points.append(hit["position"])   # 탄착점까지만 — 지형 뒤로는 안 그림
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
	# 점선: TRAJ_DOT_EVERY 스텝마다 점 하나. 멀어질수록 알파를 낮춰 더 흐릿하게.
	var n := _traj_points.size()
	for i in range(0, n, TRAJ_DOT_EVERY):
		var fade := float(i) / float(n)
		var col := TRAJ_COLOR
		col.a = lerpf(TRAJ_COLOR.a, TRAJ_ALPHA_END, fade)
		draw_circle(_traj_points[i], TRAJ_DOT_RADIUS, col)
	# 탄착점(마지막 점)은 반지름만 살짝 크게 — 어디서 끊기는지 정도만 암시
	var end_col := TRAJ_COLOR
	end_col.a = 0.22
	draw_circle(_traj_points[n - 1], TRAJ_DOT_RADIUS * 1.6, end_col)
