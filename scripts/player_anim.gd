@tool
extends AnimatedSprite2D
## [정식 플레이어 캐릭터 모션] player.gd 를 수정하지 않는 "별도 컴포넌트" 방식.
## Player(부모)의 상태(velocity·is_on_floor·player_color)를 매 프레임 읽어
## idle/walk/jump/fall/land 애니메이션을 고르고, 색(black/white)에 맞는 시트를 재생한다.
## 에셋: assets/p/{black,white}/*.png → assets/p/player_frames.tres (SpriteFrames)
##
## ⚠ 프로토존(zone_01/02)은 player.gd 무수정 전제로 동작 → 이 컴포넌트는 그 전제를 깨지 않는다.
##   또한 부모 스케일이 비균등(0.795, 0.368)이라, _ready 에서 역보정해 왜곡 없이 표시한다.
## ⚠ @tool: 크기/위치 보정을 에디터 2D 뷰포트에서도 미리보기 위함. 애니메이션 재생(_process)은
##   에디터에서 동작하지 않도록 Engine.is_editor_hint() 로 막아뒀다.
##
## ★[2026-08-22 추가] 절차적 애니메이션 레이어 (도형님 제보: "스마트매쉬/장애물을 밟을 때
##   발이 붕 떠 있고, 자연스러운 움직임이 아니라 애니를 재생하는 어색함이 있다")
##   스프라이트 시트(프레임 애니) 위에 **코드로 계산하는 변형**을 덧입힌다:
##     ① 지면 경사 정렬 — 발밑을 레이캐스트해 지면 법선에 맞춰 몸을 살짝 기울인다(계단·경사).
##     ② 착지 스쿼시 — 착지 순간 세로로 눌렸다 되돌아온다(무게감). 발끝을 피벗으로 유지.
##     ③ 공중 스트레치 — 빠르게 떨어질수록 세로로 늘어난다(속도감).
##     ④ 발 미세 스냅 — 발끝을 지면 접점에 정확히 얹어 '붕 뜸'을 없앤다(값은 아래 knob).
##   ★모든 변형은 **발끝(FOOT_Y)이 항상 Player 원점 y=0 = 콜리전 바닥선에 남도록** 계산한다.
##     (스쿼시로 스케일이 바뀌어도 position.y 를 다시 계산해 발이 안 뜨거나 안 파묻히게 한다)
##   ⚠ 순수 시각 효과다 — 물리/콜리전/판정은 1도 안 건드린다(사망·페인트 검사에 영향 없음).
##   ⚠ 값 보정은 눈으로 봐야 정확하다 → 세기·속도를 전부 @export knob 으로 뺐다.

const FRAME_PX: float   = 640.0   # 시트 프레임 한 변(정사각)
const FOOT_Y: float     = 567.0   # 프레임 안 캐릭터 발끝 y (측정 평균) — 바닥선 정렬 기준
const LAND_TIME: float  = 0.18    # 착지(land) 모션 유지 시간(초)
const MOVE_EPS: float   = 5.0     # 걷기/좌우반전으로 칠 최소 속도

## 화면(월드)에서 프레임을 표시할 높이(px). Inspector 에서 값을 바꾸면
## 2D 워크스페이스에서 바로 크기가 갱신된다 — 캐릭터 크기 조정은 이 값만 만지면 됨.
@export var 표시_높이: float = 130.0:
	set(v):
		표시_높이 = maxf(v, 1.0)
		if is_inside_tree(): _변형_적용()

@export_group("절차적 애니메이션")
## 지면 경사에 맞춰 몸을 기울일지. 계단·비탈에서 발이 지면을 따라간다.
@export var 지면정렬_사용: bool = true
## 기울기 최대 각도(도). 너무 크면 눕는 것처럼 보인다.
@export_range(0.0, 45.0) var 지면정렬_최대각: float = 22.0
## 기울기가 목표로 수렴하는 속도(1/초). 크면 딱딱, 작으면 물렁.
@export_range(1.0, 30.0) var 지면정렬_속도: float = 12.0
## 발끝을 지면 접점에 얹는 미세 스냅의 최대치(px). '발 붕 뜸'이 남으면 이 값을 올린다.
## 반대로 발이 파묻히면 음수(위로)로도 준다.
@export_range(-24.0, 24.0) var 발_미세오프셋: float = 0.0
## 발밑 레이로 감지한 접점까지 자동으로 얹는 최대 거리(px). 0 이면 자동 스냅을 끈다.
@export_range(0.0, 24.0) var 발_자동스냅_최대: float = 10.0
## 착지 스쿼시 세기(0=없음, 0.2=세로 20% 눌림).
@export_range(0.0, 0.5) var 착지_스쿼시: float = 0.16
## 스쿼시가 원래대로 되돌아오는 속도(1/초).
@export_range(1.0, 30.0) var 스쿼시_회복: float = 10.0
## 빠르게 떨어질 때 세로로 늘어나는 세기(0=없음). 속도 1000px/s 기준 최대치.
@export_range(0.0, 0.5) var 낙하_스트레치: float = 0.12

var _player: CharacterBody2D
var _color: String = "black"
var _was_on_floor: bool = true
var _land_timer: float = 0.0

# ── 절차적 상태 ──────────────────────────────────────────────────────────────
var _기본_scale: Vector2 = Vector2.ONE   ## 표시_높이·부모 스케일 역보정으로 나온 기준 스케일
var _발_중심거리: float = 0.0             ## 프레임 원점→발끝 거리(로컬 px, 스케일 전)
var _스쿼시_y: float = 1.0                ## 현재 세로 변형 배수(1=정상). 착지/낙하로 흔들림
var _목표_회전: float = 0.0               ## 지면 법선으로부터의 목표 기울기(라디안)
var _발_오프셋: float = 0.0               ## 발을 지면에 얹는 로컬 y 오프셋(부드럽게 수렴)


func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	if _player == null:
		return
	_변형_적용()
	if Engine.is_editor_hint():
		return
	# 기존 파란 Placeholder 는 화면에서만 숨긴다 (player.gd 는 그대로 참조 유지)
	var ph := _player.get_node_or_null("Placeholder")
	if ph:
		ph.visible = false
	play("black_idle")


## 기준 스케일(=표시_높이·부모 역보정)을 계산해 둔다. 실제 노드 변형은 _변형_적용() 이 한다.
## 부모 Player 의 비균등 스케일 역보정(양축 월드px/프레임px 를 같게 → 왜곡 없음).
func _기준_스케일_계산() -> void:
	var ps := _player.scale
	var k := 표시_높이 / FRAME_PX
	_기본_scale = Vector2(k / ps.x, k / ps.y)
	_발_중심거리 = FOOT_Y - FRAME_PX * 0.5


## 현재 절차적 상태(_스쿼시_y·_목표_회전·_발_오프셋)를 반영해 노드 변형을 갱신한다.
## ★핵심: 발끝(FOOT_Y)이 항상 y=0(콜리전 바닥선)에 남도록 position.y 를 스케일에 맞춰 재계산.
func _변형_적용() -> void:
	_기준_스케일_계산()
	# 스쿼시: 세로를 누르면(_스쿼시_y<1) 부피 보존 느낌으로 가로를 살짝 늘린다.
	var sy := _스쿼시_y
	var sx := 1.0 / sqrt(maxf(sy, 0.01))        # 부피 근사 보존(세로 누르면 가로 부풀림)
	scale = Vector2(_기본_scale.x * sx, _기본_scale.y * sy)
	# 발끝이 y=0 에 오도록: 스케일된 '원점→발끝' 거리만큼 위로 올리고, 미세 오프셋을 더한다.
	position = Vector2(0, -_발_중심거리 * scale.y + _발_오프셋)
	rotation = _목표_회전


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _player == null:
		return
	# 색 접두어 (player.gd 의 player_color)
	_color = "black" if _player.player_color == ColorDefs.BLACK else "white"

	# 사망 훅: 프로토존이 사망 연출 중 물리를 끄면(set_physics_process(false)) death 재생.
	# player.gd 자체엔 사망이 없으므로 평상시엔 물리가 켜져 있어 이 분기는 지나간다.
	if not _player.is_physics_processing():
		_switch(_color + "_death")
		return

	# 이동 방향 기준 좌우 반전
	var vx := _player.velocity.x
	if vx > MOVE_EPS:
		flip_h = false
	elif vx < -MOVE_EPS:
		flip_h = true

	# 착지 감지 (공중 → 지상 전이 순간 land 타이머 + 스쿼시 시작)
	var on_floor := _player.is_on_floor()
	if on_floor and not _was_on_floor:
		_land_timer = LAND_TIME
		# 착지 순간 낙하 속도가 클수록 더 깊게 눌린다(무게감). 최대 착지_스쿼시.
		var 세기 := clampf(absf(_player.velocity.y) / 900.0, 0.25, 1.0) * 착지_스쿼시
		_스쿼시_y = 1.0 - 세기
	_was_on_floor = on_floor
	_land_timer = maxf(_land_timer - delta, 0.0)

	# ── 절차적 변형 갱신 ────────────────────────────────────────────────
	_절차적_갱신(delta, on_floor)

	# 상태 → 애니메이션
	var anim: String
	if not on_floor:
		anim = "jump" if _player.velocity.y < 0.0 else "fall"
	elif _land_timer > 0.0:
		anim = "land"
	elif absf(vx) > MOVE_EPS:
		anim = "walk"
	else:
		anim = "idle"
	_switch(_color + "_" + anim)


## 스쿼시·스트레치·지면정렬·발스냅을 매 프레임 부드럽게 수렴시키고 노드에 반영한다.
func _절차적_갱신(delta: float, on_floor: bool) -> void:
	# ① 스쿼시 회복 — 항상 1.0(정상)로 되돌아온다.
	_스쿼시_y = move_toward(_스쿼시_y, 1.0, 스쿼시_회복 * delta)

	# ② 공중 스트레치 — 빠르게 떨어질수록 세로로 늘어난다(착지 스쿼시와 반대 부호).
	#    지면에 있을 땐 적용 안 함(스쿼시 회복만).
	if not on_floor and _player.velocity.y > 0.0:
		var 늘림 := clampf(_player.velocity.y / 1000.0, 0.0, 1.0) * 낙하_스트레치
		_스쿼시_y = maxf(_스쿼시_y, 1.0 + 늘림)

	# ③ 지면정렬 + ④ 발 자동스냅 — 발밑을 한 번 레이캐스트해 둘 다 계산한다.
	var 목표회전 := 0.0
	var 목표발오프셋 := 발_미세오프셋
	if on_floor:
		var 접촉 := _발밑_접촉()
		if not 접촉.is_empty():
			if 지면정렬_사용:
				# 법선(0,-1)=평지일 때 회전 0. rotation = normal.angle() + PI/2.
				var n: Vector2 = 접촉["normal"]
				var 각 := n.angle() + PI * 0.5
				# ±최대각으로 제한(너무 눕지 않게). flip 여부와 무관하게 지면 경사 그대로.
				목표회전 = clampf(각, -deg_to_rad(지면정렬_최대각), deg_to_rad(지면정렬_최대각))
			if 발_자동스냅_최대 > 0.0:
				# 접점이 발(플레이어 원점) 아래에 있으면 그만큼 발을 내려 얹는다(붕 뜸 제거).
				# 월드 간격 → 로컬(부모 비균등 스케일 역보정) 로 바꿔야 안 왜곡된다.
				# ⚠ Dictionary 값은 Variant 라 := 로는 타입 추론이 안 된다 → 명시 타입으로 받는다.
				var 접점: Vector2 = 접촉["point"]
				var 월드간격: float = clampf(접점.y - _player.global_position.y, 0.0, 발_자동스냅_최대)
				var ps := _player.scale.y
				if absf(ps) > 0.0001:
					목표발오프셋 += 월드간격 / ps

	# 목표값으로 부드럽게 수렴(툭툭 끊기지 않게).
	_목표_회전 = lerp_angle(_목표_회전, 목표회전, clampf(지면정렬_속도 * delta, 0.0, 1.0))
	_발_오프셋 = move_toward(_발_오프셋, 목표발오프셋, 120.0 * delta)

	_변형_적용()


## 발밑(플레이어 원점 바로 아래)의 지면 접점·법선을 레이캐스트로 구한다.
## 밟을 수 있는 지형(레이어 1)만 본다. 없으면 빈 사전.
func _발밑_접촉() -> Dictionary:
	var 공간 := _player.get_world_2d().direct_space_state
	var 기준 := _player.global_position
	# 발 위 8px 에서 아래로 (자동스냅 최대 + 여유)만큼 쏜다.
	var q := PhysicsRayQueryParameters2D.create(
		기준 + Vector2(0, -8.0), 기준 + Vector2(0, 발_자동스냅_최대 + 12.0), 1)
	q.exclude = [_player.get_rid()]
	var r := 공간.intersect_ray(q)
	if r.is_empty():
		return {}
	return {"point": r["position"], "normal": r["normal"]}


## 현재 재생 중과 다른 애니면 새로 재생 (같은 애니 반복 호출 시 프레임 리셋 방지)
func _switch(full: String) -> void:
	if animation != full:
		play(full)
