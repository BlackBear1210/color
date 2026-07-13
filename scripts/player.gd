extends CharacterBody2D
## 플레이어 이동/점프.
## dev_2 의 player.gd 에서 색 전환·사격·사망 판정 등을 제외하고
## 순수 물리 이동(좌우 이동 + 점프) 로직만 추출한 버전.

# ── 이동 파라미터 ──────────────────────────────────────────────────────
@export var move_speed: float    = 390.0
@export var jump_velocity: float = -600.0
@export var gravity: float       = 1200.0

# ── 점프 보정 상수 ────────────────────────────────────────────────────
const COYOTE_TIME:             float = 0.12  # 절벽 끝 낙하 후 점프 가능 시간
const JUMP_BUFFER_TIME:        float = 0.12  # 착지 직전 점프 입력 유지 시간
const FALL_GRAVITY_MULTIPLIER: float = 2.4   # 낙하 시 중력 배수
const JUMP_CUT_MULTIPLIER:     float = 0.4   # 점프 키 뗄 때 상승 감속 비율

var _coyote_timer:      float = 0.0
var _jump_buffer_timer: float = 0.0

func _physics_process(delta: float) -> void:
	# ── 중력 (비대칭: 낙하 시 배수 적용) ─────────────────────────────
	if not is_on_floor():
		var grav := gravity * FALL_GRAVITY_MULTIPLIER if velocity.y > 0.0 else gravity
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

	# ── 좌우 이동 ────────────────────────────────────────────────────
	var dir := Input.get_axis("move_left", "move_right")
	velocity.x = dir * move_speed

	move_and_slide()
