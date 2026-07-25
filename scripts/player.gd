extends CharacterBody2D
## 플레이어 이동/점프 + 색 상태(검정/흰색) 전환.
## dev_2 의 player.gd 에서 사격·사망 판정 등을 제외한 이동 로직에,
## 원본 color 프로젝트의 색 전환 로직만 최소한으로 이식한 버전.

# ── 이동 파라미터 ──────────────────────────────────────────────────────
@export var move_speed: float    = 390.0
## [2026-07-26] Inspector 에서 숨김 — 아래 "점프 튜닝" 값들로부터 매번 다시 계산되는
## 결과값이라, 여기 직접 손대도 다음 재계산(_ready() 또는 칸/타일_크기 편집) 때 덮어써진다.
## 점프감을 바꾸려면 타일_크기·점프_높이_칸·점프_거리_칸·move_speed 를 만질 것.
var jump_velocity: float = -600.0
var gravity: float       = 1200.0

# ── 점프 보정 상수 ────────────────────────────────────────────────────
const COYOTE_TIME:             float = 0.12  # 절벽 끝 낙하 후 점프 가능 시간
const JUMP_BUFFER_TIME:        float = 0.12  # 착지 직전 점프 입력 유지 시간
const FALL_GRAVITY_MULTIPLIER: float = 2.4   # 낙하 시 중력 배수
const JUMP_CUT_MULTIPLIER:     float = 0.4   # 점프 키 뗄 때 상승 감속 비율

## [편의용 점프 튜닝] "칸 수"로 점프 높이·거리를 입력하면 jump_velocity·gravity 를 역산해서 채운다.
## 상승은 gravity, 하강은 gravity*FALL_GRAVITY_MULTIPLIER 로 비대칭이라
## 최고점에서 원래 높이로 착지(같은 move_speed 로 계속 이동)한다고 가정해 역산한다.
## ⚠ 씬마다 타일 크기가 다를 수 있어(world_1=32px, 일부 테스트씬=16~24px) `타일_크기` 도
##   인스턴스별로 Inspector 에서 맞춰야 "칸 수"가 그 씬 기준으로 정확해진다.
## ⚠ 초기화 순서 문제 방지: 노드가 트리에 들어가기 전(씬 로드 중 프로퍼티 적용 시점)에는
##   계산을 건너뛰고, _ready() 에서 최종값으로 한 번만 확정 계산한다.
@export var 타일_크기: float = 16.0:
	set(v):
		타일_크기 = maxf(v, 1.0)
		if is_inside_tree(): _점프_재계산()
@export var 점프_높이_칸: float = 4.0:
	set(v):
		점프_높이_칸 = maxf(v, 0.1)
		if is_inside_tree(): _점프_재계산()
@export var 점프_거리_칸: float = 5.0:
	set(v):
		점프_거리_칸 = maxf(v, 0.1)
		if is_inside_tree(): _점프_재계산()
## 상승 가속도에만 곱해지는 배수. 1.0=기본. 크게 하면 상승이 더 빨리 감속돼
## "훅 튀었다 정점에서 멎는" 느낌, 작게 하면 "둥실 오래 떠오르는" 느낌이 된다.
## 높이·거리는 그대로 유지한 채(재계산으로 자동 보정) 상승 구간의 "체감 속도"만 바뀐다.
@export_range(0.1, 5.0) var 상승_배수: float = 1.0:
	set(v):
		상승_배수 = maxf(v, 0.05)
		if is_inside_tree(): _점프_재계산()

func _점프_재계산() -> void:
	var 높이 := 점프_높이_칸 * 타일_크기
	var 거리 := 점프_거리_칸 * 타일_크기
	var k := 1.0 / sqrt(상승_배수) + 1.0 / sqrt(FALL_GRAVITY_MULTIPLIER)
	gravity = 2.0 * 높이 * move_speed * move_speed * k * k / maxf(거리 * 거리, 0.0001)
	jump_velocity = -sqrt(2.0 * gravity * 상승_배수 * 높이)

var _coyote_timer:      float = 0.0
var _jump_buffer_timer: float = 0.0

# ── 색 상태 (검정/흰색) ─────────────────────────────────────────────────
# 원본 color 프로젝트의 player_color 를 이식. 총알 색 = 이 색과 동일하게 발사된다.
@onready var placeholder: Polygon2D = $Placeholder
var player_color: int = ColorDefs.BLACK

func _ready() -> void:
	add_to_group("player")
	_apply_color_visual()
	_점프_재계산()   # 씬 로드 중엔 계산을 건너뛰었으니 여기서 최종값으로 한 번 확정

func _physics_process(delta: float) -> void:
	# ── 중력 (비대칭: 상승/낙하 각각 배수 적용) ───────────────────────
	if not is_on_floor():
		var grav := gravity * FALL_GRAVITY_MULTIPLIER if velocity.y > 0.0 else gravity * 상승_배수
		velocity.y += grav * delta

	# ── 가변 점프 높이: 버튼 뗄 때 상승 속도 감소 ───────────────────
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT_MULTIPLIER

	# ── 점프 버퍼: 착지 직전 점프 입력을 잠깐 기억 ─────────────────
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = JUMP_BUFFER_TIME

	# ── 코요테 타임: 절벽 끝에서 떨어진 직후에도 점프 가능 ─────────
	if is_on_floor():
		_coyote_timer = COYOTE_TIME
	else:
		_coyote_timer -= delta

	# ── 점프 실행 ────────────────────────────────────────────────────
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y         = jump_velocity
		_coyote_timer      = 0.0
		_jump_buffer_timer = 0.0

	_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)

	# ── 색 전환 입력 ─────────────────────────────────────────────────
	if Input.is_action_just_pressed("toggle_color"):
		_toggle_color()

	# ── 좌우 이동 ────────────────────────────────────────────────────
	var dir := Input.get_axis("move_left", "move_right")
	velocity.x = dir * move_speed

	move_and_slide()

## 현재 색 상태 전환 (BLACK ↔ WHITE). gun.gd 가 발사 시 이 색을 그대로 총알에 넘긴다.
func _toggle_color() -> void:
	player_color = ColorDefs.WHITE if player_color == ColorDefs.BLACK else ColorDefs.BLACK
	_apply_color_visual()

## 플레이스홀더 스프라이트가 없으므로 임시로 Polygon2D 색을 현재 색에 맞춰 표시.
func _apply_color_visual() -> void:
	if placeholder:
		placeholder.color = Color(0.05, 0.05, 0.05) if player_color == ColorDefs.BLACK \
			else Color(0.95, 0.95, 0.95)
