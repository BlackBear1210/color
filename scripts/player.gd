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
@export_range(0.1, 10.0) var 상승_배수: float = 1.0:
	set(v):
		상승_배수 = maxf(v, 0.05)
		if is_inside_tree(): _점프_재계산()
## 낙하 중 매초 하강 배수가 얼마나 더 세지는지. 0이면 기존과 동일(하강 배수 항상 FALL_GRAVITY_MULTIPLIER 고정).
## 값을 주면 "떨어질수록 점점 더 빨리 떨어지는" 느낌이 생긴다.
## ⚠ _점프_재계산() 공식은 하강 배수가 FALL_GRAVITY_MULTIPLIER로 고정이라고 가정하므로,
##   이 값을 0보다 크게 주면 실제 착지 지점이 점프_거리_칸으로 계산한 값보다 조금 더 가까워진다
##   (후반부 하강이 계산보다 더 빨라지니까).
@export_range(0.0, 10.0) var 낙하_가속_증가율: float = 0.0
## 위 증가율로 커지는 하강 배수의 상한. 무한정 커지는 걸 막는 안전장치.
@export_range(0.1, 20.0) var 낙하_최대_배수: float = 6.0

func _점프_재계산() -> void:
	var 높이 := 점프_높이_칸 * 타일_크기
	var 거리 := 점프_거리_칸 * 타일_크기
	var k := 1.0 / sqrt(상승_배수) + 1.0 / sqrt(FALL_GRAVITY_MULTIPLIER)
	gravity = 2.0 * 높이 * move_speed * move_speed * k * k / maxf(거리 * 거리, 0.0001)
	jump_velocity = -sqrt(2.0 * gravity * 상승_배수 * 높이)

var _coyote_timer:      float = 0.0
var _jump_buffer_timer: float = 0.0
var _fall_timer:        float = 0.0  ## 낙하가 시작된 뒤 경과 시간(낙하 가속용, 착지/상승 시 0으로 리셋)
var _지난_바닥: bool = false
var _착지_감시_시작: bool = false

# ── 색 상태 ─────────────────────────────────────────────────────────────
## ★[2026-08-23 전면 변경] 색은 **값이 아니라 위치의 함수**가 됐다.
##
## ▣ 왜 바꿨나
##   경계선이 몸을 가로지를 때 답이 없었다. 상체는 흰 경계, 하체는 검정 경계인데
##   `player_color` 는 정수 하나뿐이라 둘 중 하나를 골라야 했고, 어느 쪽을 골라도
##   보이는 것과 죽는 것이 어긋났다.
##   → 이제 몸을 경계선 그대로 잘라, **조각마다 자기 색**을 갖는다.
##
## ▣ 세 가지 값의 역할이 다르다 — 헷갈리면 안 된다
##   `자유색`      Shift 로 바꾸는 **유일한 상태값**. 경계 밖 조각이 쓰는 색.
##   `player_color` **대표색**. 총구가 박힌 조각의 색 = 총알 색.
##                 단일 색 하나만 필요한 곳(색레이저·도약대·색문·HUD·애니메이션)이 읽는다.
##                 **읽기 전용으로 다뤄라** — 매 물리 프레임 다시 계산된다.
##   `몸_영역들()`  조각 목록. 지형·유체 접촉 사망 판정이 이걸 쓴다.
## ★[2026-08-25 제거] `Placeholder`(파란 Polygon2D)를 씬에서 지웠다.
##   진짜 캐릭터 그림(`CharacterSprite`)이 생기기 전에 쓰던 임시 사각형이고, 그 뒤로는
##   `visible = false` 로 숨긴 채 색만 갱신하는 **죽은 노드**였다. 크기도 64×128(로컬,
##   월드 50.9×47.1px)로 실제 콜리전 44×97px 과 안 맞은 지 오래였다(2026-08-07 키 변경 때 잔재).
##   같이 지운 것: `placeholder` 참조와 `_apply_color_visual()`.
##   ⚠ **몸 색을 실제로 그리는 것은 분할 셰이더다** — `_분할_갱신()` / `색경계.분할_셰이더값()`.
##   ⚠ `Bullet.tscn` 의 `Placeholder` 는 **총알의 실제 그림**이다. 그건 건드리지 않았다.

## Shift 로 바꾸는 단 하나의 상태. 경계에 걸쳐 있으면 바꿀 수 없다.
var 자유색: int = ColorDefs.BLACK

var _대표색: int = ColorDefs.BLACK

## 대표색 — 총구 부위의 색. 매 물리 프레임 `_대표색_갱신()` 이 다시 채운다.
##
## ⚠ **읽으면 대표색, 쓰면 자유색이다.** 왜 이렇게 비대칭이냐면 —
##   대표색은 경계에서 파생되는 값이라 밖에서 써 봐야 다음 프레임에 덮어써진다.
##   그런데 이 이름을 읽는 곳이 30군데(색레이저·도약대·색문·HUD·애니메이션·테스트)라
##   이름을 없애면 전부 깨진다. 그래서 읽기는 그대로 두고, 쓰기는 **원래 의도했을
##   대상**인 자유색으로 넘긴다. 예전 코드가 `player_color = WHITE` 라고 쓴 것은
##   언제나 "플레이어를 흰색으로 만들어라" 는 뜻이었지 "파생값을 조작하라" 가 아니었다.
var player_color: int:
	get:
		return _대표색
	set(v):
		자유색 = v
		_대표색 = v

## 몸 콜리전을 실측해 만든 값 (원점=발바닥 기준). `_몸_실측()` 이 한 번만 채운다.
var _몸_크기: Vector2 = Vector2(44.0, 97.0)
var _몸_중심오프셋: Vector2 = Vector2(0.0, -48.5)

## 총구가 달린 받침. 대표색을 어디서 뽑을지의 기준점이다.
@onready var _총받침: Node2D = get_node_or_null("GunRig")

## 원본 640px 캐릭터 시트의 입을 실제 표시 크기(높이 130px)로 환산한 월드 좌표.
## 씬 인스턴스·런타임 스테이지 조립 경로마다 속성 오버라이드가 달라도, 총구와 대표색
## 기준점이 무릎으로 내려가지 않도록 Player가 준비될 때마다 이 한 곳에서 확정한다.
const 입_회전중심 := Vector2(0, -70)
const 입_앞_오프셋 := Vector2(18, 0)

## 분할 셰이더가 걸린 스프라이트 둘 (검정 시트 / 흰색 시트).
const _분할_셰이더 := preload("res://shaders/색분할.gdshader")
var _시트: Array[AnimatedSprite2D] = []


func _ready() -> void:
	add_to_group("player")
	_몸_실측()
	_총구_위치_맞추기()
	_분할_시트_준비()
	_대표색_갱신()
	_점프_재계산()   # 씬 로드 중엔 계산을 건너뛰었으니 여기서 최종값으로 한 번 확정

func _physics_process(delta: float) -> void:
	# ── 중력 (비대칭: 상승/낙하 각각 배수 적용, 낙하는 시간이 지날수록 점점 가속) ─
	if not is_on_floor():
		if velocity.y > 0.0:
			_fall_timer += delta
			var fall_mult := minf(FALL_GRAVITY_MULTIPLIER + 낙하_가속_증가율 * _fall_timer, 낙하_최대_배수)
			velocity.y += gravity * fall_mult * delta
		else:
			velocity.y += gravity * 상승_배수 * delta
	else:
		_fall_timer = 0.0

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
		# 점프가 실제로 성립한 프레임에만 남긴다. 입력 버퍼만으로 먼지가 나오면 조작 피드백이 거짓말이 된다.
		var 행동효과 := get_node_or_null("ActionFX")
		if 행동효과 and 행동효과.has_method("점프"):
			행동효과.점프(얼굴색())

	_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)

	# ── 색 전환 입력 ─────────────────────────────────────────────────
	if Input.is_action_just_pressed("toggle_color"):
		_toggle_color()

	# ── 좌우 이동 ────────────────────────────────────────────────────
	var dir := Input.get_axis("move_left", "move_right")
	velocity.x = dir * move_speed

	var 착지_직전속도 := velocity.y
	move_and_slide()
	var 바닥 := is_on_floor()
	if _착지_감시_시작 and 바닥 and not _지난_바닥:
		# 첫 물리 프레임의 스폰은 제외하고, 실제 낙하 뒤 착지에만 반응한다.
		var 행동효과 := get_node_or_null("ActionFX")
		if 행동효과 and 행동효과.has_method("착지"):
			행동효과.착지(얼굴색(), maxf(착지_직전속도, 0.0))
	_지난_바닥 = 바닥
	_착지_감시_시작 = true

	# 이동이 끝난 자리에서 대표색을 다시 뽑는다. 사망 판정(월드.gd)보다 먼저 와야
	# 같은 프레임의 판정이 방금 선 자리를 기준으로 이뤄진다.
	_대표색_갱신()
	_분할_갱신()


# ── 색 ─────────────────────────────────────────────────────────────────────

## 몸 사각형(월드). 원점은 발바닥이라 중심 오프셋을 더해 만든다.
func 몸_사각형() -> Rect2:
	return Rect2(global_position + _몸_중심오프셋 - _몸_크기 * 0.5, _몸_크기)


## 이 월드 좌표의 색. 경계가 강제하면 그 색, 아니면 자유색.
func 색_at(월드좌표: Vector2) -> int:
	var c := 색경계.강제색_at(get_tree(), 월드좌표)
	return c if c >= 0 else 자유색


## 몸을 색이 같은 조각들로 자른 결과. 원소 = { "폴리곤": PackedVector2Array, "색": int }
## `여유` 만큼 몸을 부풀린 뒤 자른다 — 자르는 선은 부풀리지 않으므로 조각들이
## 경계선에서 정확히 맞닿는다(겹치면 선 위에서 양쪽 색으로 다 죽어 버린다).
func 몸_영역들(여유: float = 0.0) -> Array:
	var 몸 := 몸_사각형()
	if 여유 > 0.0:
		몸 = 몸.grow(여유)
	return 색경계.몸_영역들(get_tree(), 몸, 자유색)


## 몸의 일부라도 경계 안에 있는가. 걸쳐 있으면 색을 바꿀 수 없다.
func 경계에_걸쳤나() -> bool:
	for 영역 in 몸_영역들():
		if 영역["강제"]:
			return true
	return false


## 색 전환 (BLACK ↔ WHITE).
## ⚠ **경계에 걸쳐 있으면 아무 일도 일어나지 않는다.** 경계란 "색이 강제되고 못 바꾸는 곳"
##   이고, 몸이 반쯤 걸친 상태도 그 안에 든다 — 반만 바꾸면 규칙이 애매해진다.
##   → 레벨을 찍을 때 경계 입구 앞에 색을 미리 맞출 평지(최소 플레이어 폭 44px + 여유)를
##     둬야 한다. 없으면 걸친 채로 오도 가도 못 하는 자리가 생긴다.
func _toggle_color() -> void:
	if 경계에_걸쳤나():
		return
	자유색 = ColorDefs.WHITE if 자유색 == ColorDefs.BLACK else ColorDefs.BLACK
	_대표색_갱신()
	# [2026-08-25] 예전엔 여기서 `_apply_color_visual()` 로 Placeholder 색을 맞췄다.
	# 그 노드를 지웠고, 몸 색은 `_process` 의 `_분할_갱신()` 이 매 렌더 프레임 그린다.


## 대표색 = 실제 얼굴(입)이 있는 조각의 색.
## 총구는 조준 각도에 따라 회전하므로, 총알의 색을 거기서 직접 읽으면 위·아래를 겨눌 때
## 색이 바뀐다. 입 높이는 고정하고 좌·우만 조준 방향을 따라 얼굴 쪽으로 옮긴다.
func _대표색_갱신() -> void:
	var 새색 := 얼굴색()
	if 새색 != _대표색:
		_대표색 = 새색            # ⚠ player_color 로 쓰면 자유색까지 덮어써진다


## 총 회전 중심은 입, Marker는 입 바로 앞이다.
## GunRig가 부모의 비균등 배율을 없앤 뒤에 실행되므로 이 로컬 값은 월드 픽셀과 같다.
func _총구_위치_맞추기() -> void:
	if _총받침 == null or not is_instance_valid(_총받침):
		return
	var 총 := _총받침.get_node_or_null("Gun") as Node2D
	if 총 == null:
		return
	총.position = 입_회전중심
	var 총구 := 총.get_node_or_null("Muzzle") as Marker2D
	if 총구:
		총구.position = 입_앞_오프셋


## 조준하는 쪽의 입 위치. 왼쪽을 겨누면 왼쪽 얼굴, 오른쪽을 겨누면 오른쪽 얼굴을 쓴다.
## GunRig 아래 좌표는 월드 픽셀과 같아 프로토 총·일반 총이 같은 기준을 공유할 수 있다.
func 입_월드좌표(방향x: float = 0.0) -> Vector2:
	var 옆 := 방향x
	if absf(옆) < 0.01:
		옆 = get_global_mouse_position().x - global_position.x
	if absf(옆) < 0.01:
		var 그림 := get_node_or_null("CharacterSprite") as AnimatedSprite2D
		옆 = -1.0 if 그림 and 그림.flip_h else 1.0
	var 부호 := 1.0 if 옆 >= 0.0 else -1.0
	var 입로컬 := Vector2(입_앞_오프셋.x * 부호, 입_회전중심.y)
	if _총받침 and is_instance_valid(_총받침):
		return _총받침.to_global(입로컬)
	# GunRig가 없는 옛 Player 씬도 총알이 최소한 발바닥·무릎에서 나오지 않게 월드값으로 둔다.
	return global_position + 입로컬


## 총알 색의 유일한 기준. "현재 대표색"의 이전 프레임 값이 아니라 발사 순간의 얼굴색을 준다.
func 얼굴색(방향x: float = 0.0) -> int:
	return 색_at(입_월드좌표(방향x))


## ★[2026-09-05 신규] 바깥(HUD 등)이 "지금 Shift 로 고른 색"을 읽는 유일한 창구.
##
## ⚠ `player_color` 를 대신 읽으면 안 된다. 그건 **대표색**(총구가 박힌 조각의 색)이라
##   몸이 색 경계에 걸칠 때마다 매 물리 프레임 덮어써진다. HUD 가 그걸 읽으면
##   경계 지형 위를 걸을 때 초상·게이지가 깜빡인다.
##   `자유색` 은 Shift 로만 바뀌는 **진짜 상태값**이라 표시용으로는 이쪽이 맞다.
##   (총알 색은 지금처럼 `얼굴색()` 을 계속 써야 한다 — 그건 위치의 함수가 맞다)
func 선택색() -> int:
	return 자유색


# ── 분할 그림 ───────────────────────────────────────────────────────────────

## ⚠ 그림은 **렌더 프레임**에서 맞춘다.
##   `_physics_process` 에서만 갱신하면, 물리와 렌더가 어긋나는 순간(로딩 끊김·셰이더
##   컴파일 등으로 한 렌더 프레임 사이에 물리가 여러 번 도는 때) 스프라이트가 그려지는
##   자리와 다른 위치로 분할선을 찾아 **몸이 안 갈린 채로 그려진다.**
##   판정은 물리에서, 그림은 렌더에서 — 각자 자기 프레임의 몸 위치를 쓴다.
##   (분할선 계산은 물리 질의가 없는 순수 다각형 연산이라 두 번 돌아도 싸다)
func _process(_delta: float) -> void:
	_분할_갱신()


## 흑·백 시트 두 장에 분할 셰이더를 걸어 둔다.
## `CharacterSprite`(부모) 와 그 자식 `색겹침` 이 짝이다 — `색겹침.gd` 주석 참고.
func _분할_시트_준비() -> void:
	_시트.clear()
	var 기본 := get_node_or_null("CharacterSprite") as AnimatedSprite2D
	if 기본 == null:
		return
	var 겹침 := 기본.get_node_or_null("색겹침") as AnimatedSprite2D
	for s in [기본, 겹침]:
		if s == null:
			continue
		var m := ShaderMaterial.new()
		m.shader = _분할_셰이더
		s.material = m
		_시트.append(s)


## 몸을 가르는 선과 조각별 색을 셰이더에 넣는다.
## ⚠ 판정과 **같은 함수**(`색경계.분할선들`)에서 나온 값을 쓴다. 따로 계산하면
##   보이는 것과 죽는 것이 어긋난다 — 이 규칙이 이번 작업의 전부다.
func _분할_갱신() -> void:
	if _시트.is_empty():
		return
	var 값 := 분할_셰이더값()
	for s in _시트:
		if s == null or not is_instance_valid(s):
			continue
		var m := s.material as ShaderMaterial
		if m == null:
			continue
		# 셰이더 파일은 한글을 못 쓰므로, uniform 이름은 영문으로 고정한다.
		# 값의 뜻은 `색경계.분할_셰이더값()` 딕셔너리와 1:1로 같다.
		m.set_shader_parameter("split_count", int(값["개수"]))
		m.set_shader_parameter("line_1", 값["선1"])
		m.set_shader_parameter("line_2", 값["선2"])
		m.set_shader_parameter("color_table", 값["색표"])
		# 시트가 지금 무슨 색을 재생 중인지로 담당 색을 정한다.
		# (부모는 대표색, 자식은 그 반대라 자동으로 갈린다)
		m.set_shader_parameter("sheet_color",
			0.0 if String(s.animation).begins_with("black_") else 1.0)


## 평상시 몸과 발사 모션이 반드시 같은 분할표를 쓰도록 공개한다.
## 발사 전용 시트가 따로 이 계산을 흉내 내면 경계선에서 한 프레임씩 어긋날 수 있다.
func 분할_셰이더값() -> Dictionary:
	return 색경계.분할_셰이더값(get_tree(), 몸_사각형(), 자유색)


## 몸 콜리전을 한 번만 실측한다.
## ⚠ 크기를 상수로 박지 않는다 — 2026-08-07 에 키가 47→97px 로 바뀌면서 상수로
##   박아둔 판정이 전부 어긋난 적이 있다(월드.gd 의 같은 주석 참고).
## ★[2026-08-25] 재는 일을 `플레이어몸.재기()` 한 곳으로 옮겼다.
##   예전에는 여기 직접 박혀 있었고 `RectangleShape2D`·`CapsuleShape2D` 만 알았다.
##   콜리전을 `CollisionPolygon2D` 로 바꾸자 **노드조차 못 찾아** 기본값 44×97 로
##   돌아갔고, 그 결과 "몸이 반대색 벽에 닿으면 죽는다"가 작동을 멈췄다.
##   같은 코드가 7 곳에 복사돼 있어 어디가 깨졌는지도 알기 어려웠다 → 자를 하나로 모았다.
func _몸_실측() -> void:
	var 잰것 := 플레이어몸.재기(self)
	if not 잰것["찾음"]:
		push_warning("player: 콜리전을 못 찾음 → 몸 크기를 기본값(44×97)으로 쓴다")
		return
	_몸_크기 = 잰것["크기"]
	_몸_중심오프셋 = 잰것["중심오프셋"]
