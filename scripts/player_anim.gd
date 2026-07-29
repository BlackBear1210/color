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

const FRAME_PX: float   = 640.0   # 시트 프레임 한 변(정사각)
const FOOT_Y: float     = 567.0   # 프레임 안 캐릭터 발끝 y (측정 평균) — 바닥선 정렬 기준
const LAND_TIME: float  = 0.18    # 착지(land) 모션 유지 시간(초)
const MOVE_EPS: float   = 5.0     # 걷기/좌우반전으로 칠 최소 속도

## 화면(월드)에서 프레임을 표시할 높이(px). Inspector 에서 값을 바꾸면
## 2D 워크스페이스에서 바로 크기가 갱신된다 — 캐릭터 크기 조정은 이 값만 만지면 됨.
@export var 표시_높이: float = 130.0:
	set(v):
		표시_높이 = maxf(v, 1.0)
		if is_inside_tree(): _크기_보정()

var _player: CharacterBody2D
var _color: String = "black"
var _was_on_floor: bool = true
var _land_timer: float = 0.0

func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	if _player == null:
		return
	_크기_보정()
	if Engine.is_editor_hint():
		return
	# 기존 파란 Placeholder 는 화면에서만 숨긴다 (player.gd 는 그대로 참조 유지)
	var ph := _player.get_node_or_null("Placeholder")
	if ph:
		ph.visible = false
	play("black_idle")

## 부모 Player 의 비균등 스케일 역보정(양축 월드px/프레임px 를 같게 → 왜곡 없음) +
## 발끝(FOOT_Y)이 Player 로컬 바닥선(y=0)에 닿도록 위치 정렬.
func _크기_보정() -> void:
	var ps := _player.scale
	var k := 표시_높이 / FRAME_PX
	scale = Vector2(k / ps.x, k / ps.y)
	var foot_from_center := FOOT_Y - FRAME_PX * 0.5
	position = Vector2(0, -foot_from_center * scale.y)

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

	# 착지 감지 (공중 → 지상 전이 순간 land 타이머 시작)
	var on_floor := _player.is_on_floor()
	if on_floor and not _was_on_floor:
		_land_timer = LAND_TIME
	_was_on_floor = on_floor
	_land_timer = maxf(_land_timer - delta, 0.0)

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

## 현재 재생 중과 다른 애니면 새로 재생 (같은 애니 반복 호출 시 프레임 리셋 방지)
func _switch(full: String) -> void:
	if animation != full:
		play(full)
