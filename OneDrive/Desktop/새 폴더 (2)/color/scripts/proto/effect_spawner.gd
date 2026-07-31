extends Node2D
## [2026-07-22 도형 · 신규] 이펙트 스포너 — 개발 바이블 Chapter 4(PackedScene EffectSpawner) +
## Chapter 5(Paint Feedback / Landing Feedback)의 정식 구현.
##
## 목적: 그동안 paint_system 이 시그널(hit_feedback / gray_created)을 이미 쏘고 있었지만
##       그걸 "받아서 연출로 바꾸는 리스너"가 어디에도 없었다(어제 13차 검토에서 확인).
##       이 노드가 그 빈 리스너 자리를 채운다 — 색칠·착지 순간에 절차적 파티클을 터뜨리고
##       카메라를 살짝 흔들어 "타격감"을 만든다.
##
## 설계 원칙:
##  · ⚠아트 에셋 0개 — 전부 CPUParticles2D 코드 생성(원형 점). 나중에 ART 가 텍스처를 주면
##    _burst() 의 texture 만 갈아끼우면 된다.
##  · ⚠Player 비균등 스케일(0.795, 0.368) 함정 회피: 파티클은 top_level=true 로 만들어
##    부모 변환을 무시하고 월드 좌표에 직접 스폰한다(찌그러짐 방지 — 바이블 Part1 §2-3).
##  · player.gd / gun.gd / bullet.gd 무수정: 존이 런타임에 이 노드를 add_child 하고
##    setup() 으로 참조만 넘겨준다. 제거하면 흔적 없이 사라지는 순수 장식 + 카메라 훅.
class_name EffectSpawner

# ── 튜닝 상수 ────────────────────────────────────────────────────────────
## 색칠 성공(painted) 스플래시 파티클 수 / 회색화(mixed_gray) 스플래시 파티클 수
const SPLASH_COUNT: int = 14
const SPLASH_LIFETIME: float = 0.5
const SPLASH_SPEED: float = 180.0
## 착지 먼지 파티클 수 / 수명
const DUST_COUNT: int = 10
const DUST_LIFETIME: float = 0.45
const DUST_SPEED: float = 120.0
## 착지 먼지를 만들 최소 낙하 속도(px/s) — 살짝 걸어 내려온 정도는 무시
const DUST_MIN_FALL: float = 350.0
const DUST_REF_FALL: float = 1400.0   # 이 속도면 최대 세기(먼지·흔들림)
## 카메라 흔들림 세기(트라우마 0~1)
const SHAKE_PAINT: float = 0.12       # 색칠 성공 = 약한 킥
const SHAKE_GRAY: float = 0.25        # 회색화 = 조금 더 강하게(되돌릴 수 없는 사건)
const SHAKE_LAND_MAX: float = 0.35    # 최대 낙하 착지 = 강하게
## 회색화 순간의 히트스톱(초, 실시간). 되돌릴 수 없는 "회색" 사건에만 짧게 시간 정지 → 무게감.
const HITSTOP_GRAY: float = 0.06

var _paint_system: PaintSystem
var _terrain: TileMapLayer
var _player: CharacterBody2D
var _camera: ProtoCamera

var _was_on_floor: bool = true
var _prev_fall_speed: float = 0.0

## 존 조립 스크립트(zone_lab)가 참조를 넘겨준다.
func setup(ps: PaintSystem, terrain: TileMapLayer, player: CharacterBody2D, camera: ProtoCamera) -> void:
	_paint_system = ps
	_terrain = terrain
	_player = player
	_camera = camera
	# paint_system 이 이미 쏘고 있던 시그널을 여기서 처음으로 구독한다.
	ps.hit_feedback.connect(_on_hit_feedback)

func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	# ── 착지 감지: 공중→지상 전이 순간, 직전 낙하 속도에 비례해 먼지 + 흔들림 ──
	var on_floor := _player.is_on_floor()
	if on_floor and not _was_on_floor and _prev_fall_speed >= DUST_MIN_FALL:
		var power := clampf(_prev_fall_speed / DUST_REF_FALL, 0.0, 1.0)
		# 먼지는 발밑(플레이어 원점 아래)에 좌우로 퍼지게 스폰
		_burst(_player.global_position + Vector2(0, 4),
			Color(0.7, 0.7, 0.7, 0.9),          # 중간 회색 먼지(흑/백 배경 모두 무난)
			int(lerpf(4, DUST_COUNT, power)),
			DUST_LIFETIME, DUST_SPEED * (0.5 + 0.5 * power),
			90.0,                                # 위로 넓게 퍼짐(스프레드 90도)
			Vector2(0, -1),                      # 살짝 위로 튀었다 가라앉음
			Vector2(0, 500))                     # 중력으로 곧 내려앉음
		if _camera:
			_camera.add_trauma(SHAKE_LAND_MAX * power)
	_was_on_floor = on_floor
	if not on_floor:
		_prev_fall_speed = maxf(_player.velocity.y, 0.0)

## paint_system 의 탄착 결과 → 그에 맞는 스플래시 + 카메라 킥(+회색은 히트스톱).
func _on_hit_feedback(cell: Vector2i, result: String, _remaining: int) -> void:
	var world := _terrain.to_global(_terrain.map_to_local(cell))   # 셀 중앙의 월드 좌표
	match result:
		"painted":
			# 방금 칠해진 색(=플레이어 색)으로 스플래시. 검은색은 배경에 묻히므로 살짝 밝게 보정.
			var col := player_paint_color()
			_burst(world, col, SPLASH_COUNT, SPLASH_LIFETIME, SPLASH_SPEED,
				180.0, Vector2.ZERO, Vector2(0, 300))
			if _camera:
				_camera.add_trauma(SHAKE_PAINT)
		"mixed_gray":
			# 되돌릴 수 없는 회색화: 회색 스플래시 + 더 센 킥 + 아주 짧은 히트스톱.
			_burst(world, Color(0.5, 0.5, 0.5, 0.95), SPLASH_COUNT, SPLASH_LIFETIME,
				SPLASH_SPEED, 180.0, Vector2.ZERO, Vector2(0, 300))
			if _camera:
				_camera.add_trauma(SHAKE_GRAY)
			_hitstop(HITSTOP_GRAY)
		# progress / wasted / blocked / recovered 는 붓 커서 UI 팝업이 이미 담당 → 여기선 무시.

## 플레이어 현재 색을 화면에서 잘 보이는 스플래시 색으로 변환.
## 순수 검정은 검은 지형 위에서 안 보이므로 아주 어두운 회색으로 살짝 올린다.
func player_paint_color() -> Color:
	if _player and _player.get("player_color") == ColorDefs.WHITE:
		return Color(0.95, 0.95, 0.95, 0.95)
	return Color(0.18, 0.18, 0.18, 0.95)

## ── 절차적 파티클 버스트 (아트 에셋 없이 원형 점) ─────────────────────────
## pos=월드좌표, dir=기준 분사 방향(0 이면 전방향), spread=분사 각도(도), grav=중력.
func _burst(pos: Vector2, color: Color, count: int, life: float, speed: float,
		spread_deg: float, dir: Vector2, grav: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.top_level = true            # ★부모(Player) 스케일 무시 → 월드 좌표에 원형 그대로
	p.global_position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0         # 한 번에 팍 터짐
	p.amount = max(count, 1)
	p.lifetime = life
	p.direction = dir if dir != Vector2.ZERO else Vector2.RIGHT
	p.spread = 180.0 if dir == Vector2.ZERO else spread_deg
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = grav
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = color
	# 수명 끝나면(one_shot 완료) 스스로 정리 — 노드 누수 방지
	p.finished.connect(p.queue_free)
	add_child(p)

## ── 히트스톱(짧은 시간 정지) ──────────────────────────────────────────────
## Engine.time_scale 을 잠깐 낮췄다가, ★실시간 기준 타이머로 복구한다.
## (일반 타이머는 time_scale 의 영향을 받아 영영 안 풀릴 수 있으므로 ignore_time_scale=true)
func _hitstop(duration: float) -> void:
	Engine.time_scale = 0.05
	# create_timer(sec, process_always, process_in_physics, ignore_time_scale)
	var t := get_tree().create_timer(duration, true, false, true)
	await t.timeout
	Engine.time_scale = 1.0
