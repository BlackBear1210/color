extends Node
## [2026-07-18 도형 · 신규] 절차적 2차 모션(secondary motion) 컴포넌트.
##
## 레인월드(GDC 2016 "Rainworld Animation Process")식 접근의 핵심은
## "프레임을 더 그리는 게 아니라, 물리 상태로부터 실시간으로 변형을 계산"하는 것.
## 우리 캐릭터는 스프라이트 시트(프레임 애니메이션) 기반이라 관절 IK 를 그대로
## 넣을 수는 없지만, 같은 원리의 2차 모션 3종을 물리 상태에서 실시간 계산한다:
##
##  1. 스쿼시&스트레치: 착지 순간 낙하 속도에 비례해 납작해졌다가(스프링 감쇠로)
##     통통 튀며 복원. 상승 중엔 세로로 늘어난다. 부피 보존(가로·세로 반비례).
##  2. 달리기 기울임(lean): 이동 방향으로 몸이 살짝 기운다 (가속감).
##  3. 발 기준 스케일: 변형해도 발이 땅에 붙어 있도록 위치를 보정 (뜨거나 파묻힘 방지).
##
## ⚠ 팀원 코드 무수정: player.gd / player_anim.gd / Player.tscn 은 그대로 두고,
##   존 조립 시 이 노드를 Player 밑에 add_child 하면 시각 노드(CharacterSprite)의
##   scale/rotation/position 만 매 프레임 덧씌운다. 제거하면 원상복구되는 순수 장식.
class_name ProtoMotion

## 착지 스쿼시 최대 비율 (0.30 = 세로 30% 압축)
const SQUASH_MAX: float = 0.30
## 스쿼시를 유발하는 기준 낙하 속도(px/s) — 이 속도면 최대 스쿼시
const FALL_SPEED_REF: float = 1400.0
## 상승(점프) 중 세로 스트레치 비율
const RISE_STRETCH: float = 0.14
## 스프링 감쇠 계수 (클수록 빨리 복원)
const SPRING_K: float = 130.0
const SPRING_DAMP: float = 11.0
## 달리기 기울임 최대 각도(라디안, ≈4.5도)
const LEAN_MAX: float = 0.08
## 시각 프레임의 화면 기준 높이(px) — player_anim.gd TARGET_HEIGHT 와 동일해야 발 보정이 맞음
const VISUAL_HEIGHT: float = 130.0

var _player: CharacterBody2D
var _sprite: Node2D                # CharacterSprite(AnimatedSprite2D) 등 시각 노드
var _base_scale: Vector2           # 원래 스케일 (여기 곱해서 변형)
var _base_pos: Vector2             # 원래 위치
var _squash: float = 0.0           # 현재 변형량 (+: 세로 늘어남 / -: 납작)
var _squash_vel: float = 0.0       # 스프링 속도
var _lean: float = 0.0
var _was_on_floor: bool = true

func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	if _player == null:
		queue_free()
		return
	# 시각 노드 탐색: 팀원의 CharacterSprite 우선, 없으면 프로토 스프라이트
	for n in ["CharacterSprite", "DinoSprite", "Placeholder"]:
		var node := _player.get_node_or_null(n)
		if node is Node2D and (node as CanvasItem).visible:
			_sprite = node
			break
	if _sprite == null:
		queue_free()
		return
	# player_anim.gd 가 _ready 에서 정한 스케일/위치를 기준값으로 저장
	# (한 프레임 늦게 읽어야 안전 — player_anim._ready 가 먼저 실행된다는 보장이 없음)
	await get_tree().process_frame
	_base_scale = _sprite.scale
	_base_pos = _sprite.position

func _physics_process(delta: float) -> void:
	if _sprite == null or _base_scale == Vector2.ZERO:
		return
	# 사망 연출 중(존이 물리를 꺼둠)에는 변형을 리셋하고 손대지 않는다
	if not _player.is_physics_processing():
		_sprite.scale = _base_scale
		_sprite.rotation = 0.0
		_sprite.position = _base_pos
		_squash = 0.0
		_squash_vel = 0.0
		return

	var on_floor := _player.is_on_floor()
	var vy := _player.velocity.y

	# ── 착지 임팩트: 공중→지상 전이 순간, 직전 낙하 속도만큼 납작 ──────
	if on_floor and not _was_on_floor:
		var impact := clampf(_prev_fall_speed / FALL_SPEED_REF, 0.15, 1.0)
		_squash = -SQUASH_MAX * impact
		_squash_vel = 0.0
	_was_on_floor = on_floor
	if not on_floor:
		_prev_fall_speed = maxf(vy, 0.0)

	# ── 스프링 감쇠로 0 으로 복원 (통통 튀는 복원감) ────────────────────
	var target := 0.0
	if not on_floor and vy < -50.0:
		target = RISE_STRETCH * clampf(-vy / 600.0, 0.0, 1.0)   # 상승 중 스트레치
	var accel := SPRING_K * (target - _squash) - SPRING_DAMP * _squash_vel
	_squash_vel += accel * delta
	_squash += _squash_vel * delta

	# ── 달리기 기울임 ───────────────────────────────────────────────────
	var lean_target := LEAN_MAX * clampf(_player.velocity.x / 390.0, -1.0, 1.0)
	_lean = lerpf(_lean, lean_target, 1.0 - exp(-10.0 * delta))

	# ── 적용: 부피 보존 스케일 + 발 위치 보정 ──────────────────────────
	var sy := 1.0 + _squash
	var sx := 1.0 - _squash * 0.6            # 세로가 줄면 가로가 늘어남 (부피 보존)
	_sprite.scale = Vector2(_base_scale.x * sx, _base_scale.y * sy)
	_sprite.rotation = _lean
	# 스프라이트는 중심 기준 스케일이라 세로가 줄면 발이 뜬다 → 그만큼 내려서 접지 유지
	# (화면 높이 VISUAL_HEIGHT × 변형량의 절반을 플레이어 로컬 좌표로 환산)
	var foot_fix := VISUAL_HEIGHT * (1.0 - sy) * 0.5 / _player.scale.y
	_sprite.position = _base_pos + Vector2(0, foot_fix)

var _prev_fall_speed: float = 0.0
