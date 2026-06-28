extends CharacterBody2D
## 플레이어 캐릭터.
## 검정(BLACK) ↔ 흰색(WHITE) 색상 전환, 페인트 총 발사, 사망/리스폰 처리.
##
## ─── 애니메이션 네이밍 규칙 ───────────────────────────────────────────
##   형식: {동작}_{색상}   예) idle_black, run_white, die_black
##   동작: idle / run / jump / fall / die
##   색상: black / white
##   → _play_anim(action) 에 동작 문자열만 넘기면 현재 색에 맞는 애니를 자동 재생

# ── 이동 파라미터 ──────────────────────────────────────────────────────
# 맵을 좌우로 1.3배 늘렸으므로 이동속도도 비례해 올림(300→390)
@export var move_speed: float          = 390.0
@export var jump_velocity: float       = -600.0
@export var gravity: float             = 1200.0
@export var gray_slide_multiplier: float = 5.0

# ── 시작 색상 ─────────────────────────────────────────────────────────
# 인스펙터 드롭다운으로 스테이지별 시작 색 지정 가능
@export_enum("BLACK:0", "WHITE:1") var start_color: int = ColorDefs.BLACK

# ── 물리 레이어 비트 ──────────────────────────────────────────────────
# project.godot 의 layer_names 와 일치해야 함
const LAYER_PLAYER:   int = 1 << 0   # layer 1
const LAYER_BLACK:    int = 1 << 1   # layer 2  (검정 지형)
const LAYER_WHITE:    int = 1 << 2   # layer 3  (흰색 지형)
const LAYER_GRAY:     int = 1 << 3   # layer 4  (회색 지형)
const LAYER_OBSTACLE: int = 1 << 8   # layer 9  (장애물 256)

# ── 점프 보정 상수 ────────────────────────────────────────────────────
const COYOTE_TIME:             float = 0.12  # 절벽 끝 낙하 후 점프 가능 시간
const JUMP_BUFFER_TIME:        float = 0.12  # 착지 직전 점프 입력 유지 시간
const FALL_GRAVITY_MULTIPLIER: float = 2.4   # 낙하 시 중력 배수
const JUMP_CUT_MULTIPLIER:     float = 0.4   # 점프 키 뗄 때 상승 감속 비율

# ── 런타임 상태 ───────────────────────────────────────────────────────
var player_color: int  = ColorDefs.BLACK   # 현재 색 (0=BLACK, 1=WHITE)
var is_dead: bool      = false

# ▼ 2026-06-22 (버그수정): 리스폰 직후 짧은 무적 시간(초).
#   왜: 리스폰은 global_position 으로 '순간이동'하는데, ColorSensor(Area2D)의 겹침 목록은
#       다음 물리 스텝에서야 갱신된다. 그래서 텔레포트 직후 1프레임 동안 '이전 위치(예: 흰 지형)'의
#       겹침이 남아, 안전한 리스폰 지점에서도 곧바로 다시 사망 판정이 떠 죽음이 2번 세지는 문제 발생.
#       → 리스폰 후 잠깐 색 사망 판정을 건너뛰어 stale overlap 프레임을 흘려보낸다(스폰 보호 효과 겸용).
var _spawn_grace: float = 0.0

var _coyote_timer:      float = 0.0
var _jump_buffer_timer: float = 0.0

# 애니메이션 이름 합성에 사용하는 색 문자열 ("black" 또는 "white")
var _color_str: String  = "black"

# ▼ 2026-06-22 추가: 색 전환 회전 모션용.
#   _spin_tween       : 진행 중인 회전 트윈(빠른 토글 시 이전 것을 정리)
#   _base_sprite_scale: 스프라이트 원래 스케일(스쿼시/스트레치·복귀 기준)
var _spin_tween: Tween = null
var _base_sprite_scale: Vector2 = Vector2.ONE

# ▼ 2026-06-22 추가: 주스(연출)용.
#   _was_on_floor  : 착지 순간 감지용(직전 프레임 바닥 여부)
#   _squash_timer  : 착지 스쿼시 지속 타이머
var _was_on_floor: bool = true
var _squash_timer: float = 0.0

# ▼ 2026-06-22 (색 표시 UI: 화면 테두리 글로우) — '밋밋한 전체화면 플래시'를 대체.
#   현재 플레이어 색을 화면 가장자리 빛으로 표시. 색 전환/사망 때 잠깐 더 밝게 펄스.
#   _glow      : 전체화면 ColorRect(셰이더 적용)
#   _glow_mat  : 그 ShaderMaterial(색/세기 파라미터를 코드에서 변경)
#   ※ 다른 디자인으로 교체하고 싶으면 _juice_setup / _set_glow_color / _pulse_glow 만 바꾸면 됨.
const GLOW_SHADER: Shader = preload("res://shaders/edge_glow.gdshader")
const GLOW_BASE_INTENSITY: float = 0.55   # 평소 세기
const GLOW_PULSE_INTENSITY: float = 1.7   # 전환 순간 세기
var _glow: ColorRect = null
var _glow_mat: ShaderMaterial = null
var _glow_tween: Tween = null

# ── 사격 ──────────────────────────────────────────────────────────────
# 페인트 총알: 색깔별 전용 씬 (작업자 페인트 시스템 병합)
const BULLET_BLACK: PackedScene = preload("res://scenes/bullet/BulletBlack.tscn")
const BULLET_WHITE: PackedScene = preload("res://scenes/bullet/BulletWhite.tscn")
@export var fire_cooldown: float = 0.15
var _fire_timer: float = 0.0

# ▼ 2026-06-28 신규: '발광(에너지)' 기반 연발 제한 시스템.
#   [왜 만들었나]
#     색깔총을 너무 빠르게 연발하면 같은 프레임에 PaintMark(call_deferred 생성)가 폭증해
#     지형 색칠 로직이 꼬이는(겹침/판정 혼선) 문제가 있었다. 단순 쿨다운보다 '직관적'이도록
#     플레이어 주위에 빛(에너지)을 띄우고, 쏠수록 빛이 줄며, 다 쓰면 회복될 때까지 발사를 막는다.
#   [설계 결정 — 사용자 확정 2026-06-28]
#     · 빛은 흑/백 색 상태와 '분리된 중립 에너지광'(호박색). 회색은 게임상 '못 밟는 지형'을 뜻해 혼동되므로 사용 안 함.
#     · 에너지가 부족하면 실제로 발사를 막는다(디제식 탄약). → 연발을 물리적으로 차단해 페인트 로직 오류를 근본 예방.
#   [수치] 가득=1.0. 1발당 SHOOT_ENERGY_COST 소모, 초당 SHOOT_ENERGY_REGEN 회복.
#          발사하려면 최소 SHOOT_ENERGY_COST 만큼 남아 있어야 함(=다 쓰면 잠시 못 쏨).
const MAX_SHOOT_ENERGY:   float = 1.0
const SHOOT_ENERGY_COST:  float = 0.34   # 가득에서 약 3발 → 회복 대기
const SHOOT_ENERGY_REGEN: float = 0.45   # 바닥에서 가득까지 약 2.2초
var _shoot_energy: float = MAX_SHOOT_ENERGY

# ▼ 2026-06-28: 에너지광(플레이어 주위 빛) 비주얼 노드.
#   top_level=true 로 월드 좌표에 그려 플레이어 scale(0.3)의 영향을 받지 않게 한다(파티클과 동일 패턴).
#   밝기/반경/투명도를 _shoot_energy 에 비례시켜 '쏠수록 어두워지고 작아짐 → 회복되면 다시 커짐'.
const ENERGY_LIGHT_COLOR: Color = Color(1.0, 0.82, 0.45)   # 중립 호박색(흑/백/회색 어디에도 안 겹침)
var _energy_light: Sprite2D = null

## ▼ 2026-06-28: HUD 색 게이지가 읽는 접근자.
##   에너지 비율(0~1) — 사격할수록 줄고 시간이 지나면 회복.
func get_energy_ratio() -> float:
	return clampf(_shoot_energy / MAX_SHOOT_ENERGY, 0.0, 1.0)
## 현재 플레이어 색(0=BLACK, 1=WHITE) — 게이지 색을 플레이어 색에 맞추기 위함.
func get_player_color() -> int:
	return player_color

# ▼ 2026-06-28: '화면 전체 어둠' 오버레이.
#   왜 추가?: 기존 호박색 후광은 밝은 배경에서 잘 안 보였다(사용자 피드백).
#   해결: 발광이 줄면 '화면 전체'를 어둡게 덮고 플레이어 주변만 원형으로 밝게 남긴다.
#         → 어디서나 대비로 빛이 확실히 보이고, '세상이 어두워진다'는 연출도 강해짐.
#   _dark_mat 파라미터(light_pos/light_radius/darkness/aspect)를 _update_energy_light 가 매 프레임 갱신.
const DARK_SHADER: Shader = preload("res://shaders/energy_darkness.gdshader")
const DARK_MIN: float = 0.12   # 에너지 가득일 때도 깔리는 은은한 비네트(빛이 늘 보이게)
const DARK_MAX: float = 0.75   # 에너지 바닥일 때 화면 어둠 강도
var _dark_mat: ShaderMaterial = null

# ── 신호 ──────────────────────────────────────────────────────────────
signal died
signal color_changed(new_color: int)

# ── 노드 참조 ─────────────────────────────────────────────────────────
@onready var sprite:        AnimatedSprite2D = $AnimatedSprite2D
@onready var gun_pivot:     Node2D           = $GunPivot
@onready var muzzle:        Marker2D         = $GunPivot/Muzzle
@onready var color_sensor:  Area2D           = $ColorSensor
@onready var respawn_point: Vector2          = global_position

# ═══════════════════════════════════════════════════════════════════════
#  초기화
# ═══════════════════════════════════════════════════════════════════════
func _ready() -> void:
	add_to_group("player")           # 가시·포탈 등이 이 그룹으로 플레이어를 찾음
	collision_layer = LAYER_PLAYER

	# ── 모든 색상×동작 애니메이션을 단일 SpriteFrames 에 빌드 ──────────
	# 검정 에셋(black/)과 흰색 에셋(white/)을 한 번에 등록해 두고
	# _play_anim()에서 "{동작}_{색상}" 이름으로 자동 선택함
	sprite.sprite_frames = _build_all_frames()

	# modulate 는 항상 WHITE → 에셋 자체 색을 그대로 표시 (tinting 없음)
	sprite.modulate = Color.WHITE

	# ▼ 2026-06-22: 스쿼시/스트레치·회전 모션 후 복귀할 기준 스케일 저장
	_base_sprite_scale = sprite.scale

	# ▼ 2026-06-22: 주스 노드(색전환 플래시) 생성
	_juice_setup()

	# ▼ 2026-06-28: 에너지광(연발 제한 빛) 노드 생성
	_energy_light_setup()

	_set_color(start_color)  # 시작 색 적용

## ▼ 2026-06-22 신규: 색 표시 UI(화면 테두리 글로우) 셋업.
##   씬 파일을 건드리지 않고 코드로 전체화면 ColorRect+셰이더를 띄워 모든 스테이지에 자동 적용.
func _juice_setup() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 49          # 월드 위, HUD 텍스트 아래쯤(테두리 빛)
	add_child(layer)
	_glow = ColorRect.new()
	_glow.anchor_right = 1.0
	_glow.anchor_bottom = 1.0                    # 화면 전체 덮기(셰이더가 가장자리만 칠함)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_mat = ShaderMaterial.new()
	_glow_mat.shader = GLOW_SHADER
	_glow_mat.set_shader_parameter("intensity", GLOW_BASE_INTENSITY)
	_glow_mat.set_shader_parameter("thickness", 0.16)
	_glow.material = _glow_mat
	layer.add_child(_glow)

## ▼ 2026-06-28 신규: 플레이어 주위 '에너지광' 비주얼을 코드로 생성한다.
##   - 방사형 그라데이션(중심 밝음→가장자리 투명) 텍스처를 Sprite2D 로 띄우고,
##     CanvasItemMaterial 의 ADD 블렌드로 '빛처럼' 더해지게 한다.
##   - top_level=true 로 월드 좌표에 직접 그려 플레이어 scale(0.3) 영향을 안 받게 한다.
##   - 실제 밝기/반경/투명도는 매 프레임 _update_energy_light() 가 _shoot_energy 로 갱신.
func _energy_light_setup() -> void:
	# 방사형 그라데이션 텍스처(흰 중심 → 투명 가장자리)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient  = grad
	tex.fill      = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to   = Vector2(1.0, 0.5)
	tex.width     = 256
	tex.height    = 256

	_energy_light = Sprite2D.new()
	_energy_light.texture   = tex
	_energy_light.top_level = true              # 월드 좌표(플레이어 스케일 무시)
	_energy_light.z_index   = -1                # 플레이어 뒤에 깔리는 후광
	_energy_light.modulate  = ENERGY_LIGHT_COLOR
	var mat := CanvasItemMaterial.new()
	mat.blend_mode          = CanvasItemMaterial.BLEND_MODE_ADD   # 빛처럼 더해짐
	_energy_light.material  = mat
	add_child(_energy_light)

	# ▼ 2026-06-28: 화면 전체 어둠 오버레이(빛 구멍 포함) — 전용 CanvasLayer 에 풀스크린 ColorRect.
	#   layer 48: 월드 위 + 테두리글로우(49)·HUD(그 위) 아래. → 어둠이 HUD 텍스트를 가리지 않음.
	var dark_layer := CanvasLayer.new()
	dark_layer.layer = 48
	add_child(dark_layer)
	var dark_rect := ColorRect.new()
	dark_rect.anchor_right  = 1.0
	dark_rect.anchor_bottom = 1.0                                  # 화면 전체 덮기
	dark_rect.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_dark_mat = ShaderMaterial.new()
	_dark_mat.shader = DARK_SHADER
	dark_rect.material = _dark_mat
	dark_layer.add_child(dark_rect)

	_update_energy_light()

## ▼ 2026-06-28 신규: 에너지 비율(0~1)에 따라 에너지광의 위치·반경·밝기를 갱신.
##   에너지가 가득이면 크고 밝게, 바닥이면 작고 어둡게 → '발광을 잃어간다'는 피드백.
func _update_energy_light() -> void:
	if _energy_light == null:
		return
	_energy_light.global_position = global_position
	var e: float = clampf(_shoot_energy / MAX_SHOOT_ENERGY, 0.0, 1.0)
	# 반경: 텍스처 256px 기준, 지름이 곧 빛 크기. (바닥 70px ~ 가득 200px)
	var diameter_px: float = lerp(70.0, 200.0, e)
	_energy_light.scale = Vector2.ONE * (diameter_px / 256.0)
	# 밝기(알파): 바닥에서도 희미하게 보이게 최소값 유지
	_energy_light.modulate = Color(
		ENERGY_LIGHT_COLOR.r, ENERGY_LIGHT_COLOR.g, ENERGY_LIGHT_COLOR.b,
		lerp(0.10, 0.55, e)
	)

	# ▼ 2026-06-28: 화면 전체 어둠 갱신.
	#   darkness: 에너지 가득=DARK_MIN(은은) → 바닥=DARK_MAX(어둠).  빛 구멍 반경: 가득=넓게 → 바닥=좁게.
	if _dark_mat != null:
		var vp := get_viewport()
		if vp:
			var size: Vector2 = vp.get_visible_rect().size
			# 플레이어의 '화면 UV' 좌표(월드→화면 변환) — 빛 구멍을 플레이어에 고정
			var screen_pos: Vector2 = vp.get_canvas_transform() * global_position
			if size.x > 0.0 and size.y > 0.0:
				_dark_mat.set_shader_parameter("light_pos", screen_pos / size)
				_dark_mat.set_shader_parameter("aspect", size.x / size.y)
		_dark_mat.set_shader_parameter("darkness", lerp(DARK_MAX, DARK_MIN, e))
		_dark_mat.set_shader_parameter("light_radius", lerp(0.22, 0.5, e))

# ── 스프라이트 시트를 AtlasTexture 로 분할해 SpriteFrames 에 등록 ─────
## black/white 두 색상의 모든 애니메이션을 하나의 SpriteFrames 에 담는다.
## 스프라이트 시트 규격: 512×512 px / 프레임, 가로 방향으로 나열.
func _build_all_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	# 기본 "default" 애니메이션 제거
	if frames.has_animation("default"):
		frames.remove_animation("default")

	# 두 색상 순서로 반복: "black", "white"
	for color_key in ["black", "white"]:
		var base: String = "res://assets/textures/player/%s/" % color_key
		var idle_tex: Texture2D = load(base + "Idle.png")  # 2  프레임
		var run_tex:  Texture2D = load(base + "Run.png")   # 4  프레임
		var jump_tex: Texture2D = load(base + "Jump.png")  # 11 프레임 (jump 6 + fall 5)
		var die_tex:  Texture2D = load(base + "Die.png")   # 6  프레임

		# 각 동작을 "{action}_{color}" 이름으로 등록
		_add_anim(frames, "idle_" + color_key, idle_tex, 0, 2,  6.0,  true)
		_add_anim(frames, "run_"  + color_key, run_tex,  0, 4,  10.0, true)
		_add_anim(frames, "jump_" + color_key, jump_tex, 0, 6,  12.0, false)
		_add_anim(frames, "fall_" + color_key, jump_tex, 6, 5,  10.0, true)
		_add_anim(frames, "die_"  + color_key, die_tex,  0, 6,  8.0,  false)

	return frames

## SpriteFrames 에 애니메이션 하나를 추가하는 헬퍼.
## tex    : 스프라이트 시트 텍스처
## start  : 시작 프레임 인덱스 (0-based)
## count  : 프레임 수
## fps    : 초당 프레임 (재생 속도)
## loop   : 루프 여부
func _add_anim(frames: SpriteFrames, anim: String, tex: Texture2D,
		start: int, count: int, fps: float, loop: bool) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for i in count:
		var atlas := AtlasTexture.new()
		atlas.atlas  = tex
		atlas.region = Rect2((start + i) * 512, 0, 512, 512)
		frames.add_frame(anim, atlas)

# ═══════════════════════════════════════════════════════════════════════
#  물리 프레임 처리
# ═══════════════════════════════════════════════════════════════════════
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# ▼ 2026-06-22: 리스폰 직후 무적 시간 카운트다운(stale overlap 프레임 무시용)
	_spawn_grace = max(_spawn_grace - delta, 0.0)

	var on_gray := _is_touching_gray()

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
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0 and not on_gray:
		velocity.y         = jump_velocity
		_coyote_timer      = 0.0
		_jump_buffer_timer = 0.0
		AudioManager.play_sfx("jump")   # ▼ 2026-06-22 효과음

	_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)

	# ── 색 전환 입력 ─────────────────────────────────────────────────
	if Input.is_action_just_pressed("toggle_color"):
		_toggle_color()

	# ── 좌우 이동 ────────────────────────────────────────────────────
	floor_stop_on_slope = not on_gray

	if on_gray:
		# 회색 지형: 입력 무시, 마찰 없음
		if is_on_floor():
			var n := get_floor_normal()
			if abs(n.x) < 0.01:
				# 수평: velocity.x 불변 (얼음판)
				pass
			else:
				# 경사: velocity를 사면 접선 방향으로 완전히 맞춤
				# → move_and_slide()에 수직 성분이 없어 떨림 없이 부드럽게 미끄러짐
				var tangent := Vector2(n.y, -n.x)
				if tangent.y < 0.0:
					tangent = -tangent          # 항상 내리막(y 양수) 방향
				var speed: float = max(velocity.dot(tangent), 0.0)   # 오르막 성분 차단
				speed += gravity * abs(n.x) * gray_slide_multiplier * delta
				velocity.x = tangent.x * speed
				velocity.y = tangent.y * speed
	else:
		var dir := Input.get_axis("move_left", "move_right")
		velocity.x = dir * move_speed

	# ── 총 조준 (마우스 방향으로 GunPivot 회전) ──────────────────────
	if gun_pivot:
		gun_pivot.look_at(get_global_mouse_position())

	# ── 사격 ─────────────────────────────────────────────────────────
	# ▼ 2026-06-28: 에너지 회복(매 프레임) + 발사 게이트.
	#   발사 조건 = 입력 + 쿨다운 종료 + 에너지가 1발치(SHOOT_ENERGY_COST) 이상 남음.
	#   에너지가 부족하면 발사를 막아(연발 차단) 페인트 로직 폭주를 근본 예방한다.
	_shoot_energy = min(_shoot_energy + SHOOT_ENERGY_REGEN * delta, MAX_SHOOT_ENERGY)
	_fire_timer = max(_fire_timer - delta, 0.0)
	if Input.is_action_pressed("shoot") and _fire_timer <= 0.0 and _shoot_energy >= SHOOT_ENERGY_COST:
		_shoot()
		_shoot_energy -= SHOOT_ENERGY_COST   # 발사 1회당 에너지(빛) 소모
		_fire_timer = fire_cooldown

	# ▼ 2026-06-28: 에너지광 비주얼 갱신(위치·반경·밝기 = 현재 에너지)
	_update_energy_light()

	move_and_slide()
	_update_animation()
	_apply_juice_motion(delta)   # ▼ 2026-06-22: 스쿼시/스트레치 + 착지 먼지

	# 색 판정: 페인트 마크 우선 → 지형 색 → GhostPlatform
	_check_color_death()

# ═══════════════════════════════════════════════════════════════════════
#  애니메이션
# ═══════════════════════════════════════════════════════════════════════
## "{동작}_{현재색상}" 이름의 애니메이션을 재생한다.
## 이미 같은 애니메이션이 재생 중이면 다시 시작하지 않음.
func _play_anim(action: String) -> void:
	var anim_name: String = action + "_" + _color_str   # 예: "run_black", "idle_white"
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)

## 이동 상태에 따라 적절한 애니메이션을 선택해 재생.
func _update_animation() -> void:
	if is_dead:
		return   # 사망 중에는 die() 가 직접 관리

	var action: String
	if not is_on_floor():
		action = "jump" if velocity.y < 0.0 else "fall"
	elif absf(velocity.x) > 10.0:
		action = "run"
	else:
		action = "idle"

	_play_anim(action)

	# 이동 방향에 따라 스프라이트 좌우 반전
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x < 0.0

# ═══════════════════════════════════════════════════════════════════════
#  색 판정 (사망 로직)
# ═══════════════════════════════════════════════════════════════════════
## ColorSensor 가 겹친 영역을 분석해 사망 여부를 판정한다.
## 판정 우선순위: ① 페인트 자국 → ② 지형 색 → ③ GhostPlatform
func _check_color_death() -> void:
	if is_dead or color_sensor == null:
		return
	# ▼ 2026-06-22: 리스폰 직후 무적 동안은 색 사망 판정 건너뜀(텔레포트 stale overlap 방지)
	if _spawn_grace > 0.0:
		return

	# Area2D 목록 분류
	var marks:       Array = []   # PaintMark 의 JudgmentZone
	var ghost_zones: Array = []   # GhostPlatform 등 Area2D 사망 영역

	for a in color_sensor.get_overlapping_areas():
		if a.is_in_group("paint_marks"):
			marks.append(a)
		elif a.is_in_group("death_zones"):
			ghost_zones.append(a)

	# ① 페인트 우선: 같은 색 페인트가 하나라도 있으면 안전
	if not marks.is_empty():
		for m in marks:
			# 계층: JudgmentZone → Sprite2D → BlackMark/WhiteMark → PaintMark(paint_color)
			var paint_mark: Node = m.get_parent().get_parent().get_parent()
			if paint_mark.get("paint_color") == player_color:
				return
		die()
		return

	# ② 지형 색 직접 체크 (StaticBody2D 의 color_state 변수)
	#    회색(GRAY)은 color_state 가 있어도 사망 제외
	for b in color_sensor.get_overlapping_bodies():
		var cs = b.get("color_state")
		if cs == null or cs == ColorDefs.GRAY:
			continue
		if cs != player_color:
			die()
			return

	# ③ GhostPlatform 등 Area2D 기반 사망 영역
	for z in ghost_zones:
		var plat: Node = z.get_parent()
		if plat and plat.get("color_state") != null and plat.get("color_state") != player_color:
			die()
			return

# ═══════════════════════════════════════════════════════════════════════
#  사격
# ═══════════════════════════════════════════════════════════════════════
## 총알 색 = 플레이어 색의 반대.
## add_child 전에 bullet_color 를 세팅해야 _ready() 에서 올바른 색이 적용됨.
func _shoot() -> void:
	# 총알 색 = 플레이어의 '반대색' (불변 규칙 — 작업자 커밋 7d15dd1 '총알 색 반대색 수정' 반영).
	#   검정 플레이어 → 흰색 페인트 / 흰색 플레이어 → 검정 페인트.
	#   ※ 2026-06-21 의 '같은 색 발사' 변경이 이 규칙을 깨 총알색이 들쭉날쭉해지는 버그를 만들어 되돌림.
	#   회색 경사로(현재 적용 방식): bullet.gd 가 'gray_slopes' 에 한해 '플레이어 색'(=반대색의 반대)
	#     으로 칠해 토글 없이 바로 등반 + 그라데이션이 되도록 예외 처리한다.
	#     ─ 작업자 의도(반대색 칠 → 그 색으로 토글해 착지하면 미끄럼 멈춤)로 통일하려면
	#       bullet.gd 의 gray_slopes 분기를 제거하면 됨.
	var bullet_color := ColorDefs.WHITE if player_color == ColorDefs.BLACK else ColorDefs.BLACK
	var scene := BULLET_BLACK if bullet_color == ColorDefs.BLACK else BULLET_WHITE
	var bullet := scene.instantiate()
	bullet.bullet_color = bullet_color
	bullet.direction    = (get_global_mouse_position() - muzzle.global_position).normalized()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
	AudioManager.play_sfx("shoot")   # ▼ 2026-06-22 효과음

# ═══════════════════════════════════════════════════════════════════════
#  회색 지형 감지
# ═══════════════════════════════════════════════════════════════════════
## 바닥 접촉(법선이 위를 향함) 중에 회색 지형이 있으면 true 반환.
## 페인트가 칠해진 위치에서는 false → 정상 이동 가능.
func _is_touching_gray() -> bool:
	if _is_over_paint():
		return false
	for i in get_slide_collision_count():
		var col  := get_slide_collision(i)
		var body := col.get_collider()
		if body and body.get("color_state") == ColorDefs.GRAY and col.get_normal().y < -0.5:
			return true
	return false

## ColorSensor 가 페인트 자국(paint_marks 그룹) 위에 겹쳐 있으면 true
func _is_over_paint() -> bool:
	if color_sensor == null:
		return false
	for a in color_sensor.get_overlapping_areas():
		if a.is_in_group("paint_marks"):
			return true
	return false

# ═══════════════════════════════════════════════════════════════════════
#  색 전환
# ═══════════════════════════════════════════════════════════════════════
func _toggle_color() -> void:
	_set_color(ColorDefs.WHITE if player_color == ColorDefs.BLACK else ColorDefs.BLACK)
	# ▼ 2026-06-22: 색을 바꿀 때마다 '다이얼/리모컨 돌리듯' 회전 모션 재생
	_play_color_switch_spin()
	AudioManager.play_sfx("switch")   # ▼ 2026-06-22 효과음

## ▼ 2026-06-22 신규(사용자 요청): 색 전환 시 스프라이트를 한 바퀴 회전(다이얼 돌리는 느낌) + 화면 번쩍.
##   - 회전은 sprite.rotation 만 사용 → 스케일은 스쿼시/스트레치가 담당하므로 서로 안 부딪힘.
##   - 빠르게 연타해도 깨지지 않게 이전 트윈을 kill 하고 회전을 0 으로 리셋한다.
func _play_color_switch_spin() -> void:
	if sprite == null:
		return
	if _spin_tween and _spin_tween.is_valid():
		_spin_tween.kill()
	sprite.rotation = 0.0

	# 회전 트윈(한 바퀴) — 끝나면 rotation 을 0 으로 정리
	_spin_tween = create_tween()
	_spin_tween.tween_property(sprite, "rotation", TAU, 0.30) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_spin_tween.tween_callback(func() -> void: sprite.rotation = 0.0)

	# 화면 테두리 글로우 펄스(색 전환 강조)
	_pulse_glow()

## ▼ 2026-06-22 신규: 화면 테두리 글로우 색을 현재 플레이어 색에 맞춘다.
##   검정=어두운(약간 남색 틴트로 가시성↑) / 흰색=밝은 빛. 색은 취향대로 조정 가능.
func _set_glow_color(c: int) -> void:
	if _glow_mat == null:
		return
	var col := Color(0.97, 0.97, 1.0) if c == ColorDefs.WHITE else Color(0.12, 0.13, 0.20)
	_glow_mat.set_shader_parameter("glow_color", col)

## ▼ 2026-06-22 신규: 테두리 글로우를 잠깐 더 밝게 펄스(전환/사망 강조).
func _pulse_glow() -> void:
	if _glow_mat == null:
		return
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
	_glow_mat.set_shader_parameter("intensity", GLOW_PULSE_INTENSITY)
	_glow_tween = create_tween()
	_glow_tween.tween_method(
		func(v: float) -> void: _glow_mat.set_shader_parameter("intensity", v),
		GLOW_PULSE_INTENSITY, GLOW_BASE_INTENSITY, 0.35
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## ▼ 2026-06-22 신규: 스쿼시&스트레치 + 착지 먼지.
##   점프 상승=세로로 늘리고, 낙하=살짝 늘리고, 착지 순간=납작(스쿼시) + 먼지 파편.
##   스케일만 다루므로 회전 모션(_play_color_switch_spin)과 충돌하지 않는다.
func _apply_juice_motion(delta: float) -> void:
	if sprite == null:
		return
	var on_floor := is_on_floor()
	# 착지 순간 감지 → 납작 스쿼시 + 발밑 먼지
	if on_floor and not _was_on_floor:
		_squash_timer = 0.12
		_spawn_burst(global_position + Vector2(0, 45), Color(0.75, 0.75, 0.75, 0.7), 12, 75.0, 90.0)
		AudioManager.play_sfx("land")   # ▼ 2026-06-22 효과음
	_was_on_floor = on_floor

	var target := _base_sprite_scale
	if not on_floor:
		if velocity.y < 0.0:
			target = Vector2(_base_sprite_scale.x * 0.86, _base_sprite_scale.y * 1.16)  # 상승: 길쭉
		else:
			target = Vector2(_base_sprite_scale.x * 0.93, _base_sprite_scale.y * 1.08)  # 낙하: 약간 길쭉
	if _squash_timer > 0.0:
		target = Vector2(_base_sprite_scale.x * 1.22, _base_sprite_scale.y * 0.80)        # 착지: 납작
		_squash_timer -= delta

	# 지수 감쇠로 부드럽게 목표 스케일에 수렴
	var t := 1.0 - exp(-18.0 * delta)
	sprite.scale = sprite.scale.lerp(target, t)

## ▼ 2026-06-22 신규: 한 번 터지는 파티클(먼지/파편)을 현재 씬에 스폰 → 끝나면 자동 제거.
##   플레이어(scale 0.3)의 자식으로 두면 입자가 작아지므로, 씬 루트에 월드 좌표로 스폰한다.
func _spawn_burst(world_pos: Vector2, color: Color, amount: int, spread: float, vel: float) -> void:
	var p := CPUParticles2D.new()
	p.one_shot     = true
	p.explosiveness = 0.95
	p.amount       = max(amount, 1)
	p.lifetime     = 0.5
	p.direction    = Vector2(0, -1)
	p.spread       = spread
	p.gravity      = Vector2(0, 600)
	p.initial_velocity_min = vel * 0.5
	p.initial_velocity_max = vel
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	p.color        = color
	p.position     = world_pos     # 씬 루트는 원점이므로 position=월드좌표
	p.emitting     = true
	p.finished.connect(p.queue_free)
	var scene := get_tree().current_scene
	if scene:
		scene.call_deferred("add_child", p)

## 사망 파편 색 (현재 플레이어 색 계열)
func _death_color() -> Color:
	return Color(0.95, 0.95, 0.95, 0.95) if player_color == ColorDefs.WHITE else Color(0.12, 0.12, 0.12, 0.95)

## 색상 상태를 변경한다.
## ① collision_mask 교체 (자기 색 지형 + 회색 + 장애물만 충돌)
## ② _color_str 업데이트 → _play_anim 에서 올바른 스프라이트 선택
## ③ modulate 는 항상 WHITE 유지 (에셋 원본 색 그대로, tinting 없음)
func _set_color(c: int) -> void:
	player_color = c

	# 충돌 마스크: 자기 색 지형 + 회색 + 장애물
	collision_mask = (LAYER_BLACK | LAYER_GRAY | LAYER_OBSTACLE) if c == ColorDefs.BLACK \
					 else (LAYER_WHITE | LAYER_GRAY | LAYER_OBSTACLE)

	# 색 문자열 업데이트 (애니메이션 이름 합성에 사용)
	_color_str = "black" if c == ColorDefs.BLACK else "white"

	# 스프라이트 원본 색 유지 (modulate tinting 없음)
	if sprite:
		sprite.modulate = Color.WHITE

	# ▼ 2026-06-22: 화면 테두리 글로우 색을 현재 색에 동기화(전환 직후 상태가 화면에 표시됨)
	_set_glow_color(c)

	# 현재 재생 중인 동작을 새 색상으로 즉시 전환
	var current_action: String = sprite.animation.split("_")[0] if sprite and sprite.animation else "idle"
	_play_anim(current_action)

	color_changed.emit(c)

# ═══════════════════════════════════════════════════════════════════════
#  사망 / 리스폰
# ═══════════════════════════════════════════════════════════════════════
func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	died.emit()
	SceneManager.add_death()   # HUD 죽음 횟수 누적 (+1)
	# ▼ 2026-06-22: 사망 파편 폭발(현재 색 계열) + 테두리 글로우 펄스
	_spawn_burst(global_position + Vector2(0, 25), _death_color(), 26, 150.0, 160.0)
	_pulse_glow()
	AudioManager.play_sfx("death")   # ▼ 2026-06-22 효과음
	_play_anim("die")          # die_black 또는 die_white 재생
	await sprite.animation_finished
	_respawn()

func _respawn() -> void:
	global_position = respawn_point
	velocity        = Vector2.ZERO
	is_dead         = false
	_spawn_grace    = 0.2   # ▼ 2026-06-22: 리스폰 직후 짧은 무적(stale overlap 재사망 방지)
	_shoot_energy   = MAX_SHOOT_ENERGY   # ▼ 2026-06-28: 리스폰 시 발광(에너지) 가득 회복
	# 칠했던 페인트 전부 제거 + 시작 색으로 복귀
	for p in get_tree().get_nodes_in_group("runtime_paint"):
		p.queue_free()
	# ▼ 2026-06-21 (작업 W-C) 추가: 회색 경사로의 그라데이션 페인트도 함께 초기화
	#   (PaintMark 는 runtime_paint 로 지워지지만, 경사로 셰이더 누적은 별도이므로 직접 리셋)
	for s in get_tree().get_nodes_in_group("gray_slopes"):
		if s.has_method("reset_paint"):
			s.reset_paint()
	_set_color(start_color)
