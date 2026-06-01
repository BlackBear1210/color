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
@export var move_speed: float     = 390.0
@export var jump_velocity: float  = -600.0
@export var gravity: float        = 1200.0

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

var _coyote_timer:      float = 0.0
var _jump_buffer_timer: float = 0.0

# 애니메이션 이름 합성에 사용하는 색 문자열 ("black" 또는 "white")
var _color_str: String  = "black"

# ── 사격 ──────────────────────────────────────────────────────────────
const BULLET_BLACK: PackedScene = preload("res://scenes/bullet/BulletBlack.tscn")
const BULLET_WHITE: PackedScene = preload("res://scenes/bullet/BulletWhite.tscn")
@export var fire_cooldown: float = 0.15
var _fire_timer: float = 0.0

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

	_set_color(start_color)  # 시작 색 적용

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

	# ── 색 전환 입력 ─────────────────────────────────────────────────
	if Input.is_action_just_pressed("toggle_color"):
		_toggle_color()

	# ── 좌우 이동 ────────────────────────────────────────────────────
	# 회색 지형 위에서는 입력을 무시하고 자연스럽게 미끄러짐
	var on_gray := _is_touching_gray()
	floor_stop_on_slope = not on_gray
	var dir := Input.get_axis("move_left", "move_right")
	velocity.x = 0.0 if on_gray else dir * move_speed

	# ── 총 조준 (마우스 방향으로 GunPivot 회전) ──────────────────────
	if gun_pivot:
		gun_pivot.look_at(get_global_mouse_position())

	# ── 사격 ─────────────────────────────────────────────────────────
	_fire_timer = max(_fire_timer - delta, 0.0)
	if Input.is_action_pressed("shoot") and _fire_timer <= 0.0:
		_shoot()
		_fire_timer = fire_cooldown

	move_and_slide()
	_update_animation()

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

	# Area2D 목록 분류
	var marks:       Array = []   # PaintMark 의 JudgmentZone
	var ghost_zones: Array = []   # GhostPlatform 등 Area2D 사망 영역

	for a in color_sensor.get_overlapping_areas():
		if a.is_in_group("paint_marks"):
			marks.append(a)
		elif a.is_in_group("death_zones"):
			ghost_zones.append(a)

	# ① 페인트 우선: 같은 색 페인트가 하나라도 있으면 안전
	# 계층: JudgmentZone → Sprite2D → BlackMark/WhiteMark → PaintMark(paint_color)
	if not marks.is_empty():
		for m in marks:
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
	var bullet_color := ColorDefs.WHITE if player_color == ColorDefs.BLACK else ColorDefs.BLACK
	var scene := BULLET_BLACK if bullet_color == ColorDefs.BLACK else BULLET_WHITE
	var bullet := scene.instantiate()
	bullet.bullet_color = bullet_color
	bullet.direction    = (get_global_mouse_position() - muzzle.global_position).normalized()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position

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
	_play_anim("die")          # die_black 또는 die_white 재생
	await sprite.animation_finished
	_respawn()

func _respawn() -> void:
	global_position = respawn_point
	velocity        = Vector2.ZERO
	is_dead         = false
	# 칠했던 페인트 전부 제거 + 시작 색으로 복귀
	for p in get_tree().get_nodes_in_group("runtime_paint"):
		p.queue_free()
	_set_color(start_color)
