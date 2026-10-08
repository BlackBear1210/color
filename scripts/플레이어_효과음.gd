extends Node
## ============================================================================
## [2026-10-05 Claude 신규] 플레이어 효과음 — 걷기 · 점프 · 착지 · 높은 곳 착지 · 죽음(잉크 터짐)
## ----------------------------------------------------------------------------
## ▣ 소리 파일
##   `assets/audio/sfx/*.ogg` — 도형님이 ElevenLabs 로 만든 원본(.opus)을
##   `tools/생성_플레이어_효과음.py` 가 무음을 잘라 Vorbis 로 굽는다. 손으로 자르지 말 것.
##
## ▣ 누가 부르나 — 세 곳뿐
##   · `player.gd` 점프가 실제로 성립한 프레임 → `점프()`
##   · `player.gd` 착지한 프레임 → `착지()`  (높은 곳인지는 여기서 잰다)
##   · `월드.gd` `_리스폰()` = 사망 → `죽음()`
##   걷기는 이 노드가 스스로 본다(바닥 + 좌우로 움직이는 중이면 걸음 간격마다).
##
## ▣ 왜 Node(2D 아님)이고 AudioStreamPlayer(2D 아님)인가
##   · Player 루트는 scale 이 비균등하다(0.795, 0.368 — 플레이어_보조광.gd 참고). Node 는 영향이 없다.
##   · 플레이어 소리는 카메라가 늘 따라가므로 거리 감쇠가 필요 없다. 그리고 죽으면
##     플레이어가 리스폰 지점으로 **순간이동**하는데, 2D 소리면 잉크 터지는 소리가
##     죽은 자리가 아니라 되살아난 자리에서 들리다 거리로 뚝 끊길 수 있다.
##
## ▣ 왜 preload 가 아니라 load 인가
##   새 .ogg 는 에디터가 한 번 열려야 .import 가 생긴다. preload 면 그 전에 헤드리스
##   검사(검사 13개)가 스크립트 파싱부터 실패한다. load 는 없으면 null → 그 소리만 조용히 빠진다.
##
## ▣ 하수도와의 관계
##   하수도는 `하수도_물소리.gd` 가 원래 발소리(합성 돌·물)를 냈다. 이제
##   · 마른 바닥 발소리 = 이 노드 (하수도 쪽은 이 노드가 있으면 돌 발소리를 쉰다)
##   · 웅덩이 속 찰박 발소리 = 하수도 쪽 그대로 (이 노드는 물속이면 쉰다)
##   둘이 동시에 울리지 않게 서로 한쪽씩만 맡는다.
## ============================================================================

const 경로 := "res://assets/audio/sfx/"

@export_group("음량 (dB)")
@export var 걷기_음량: float = -14.0
@export var 점프_음량: float = -10.0
@export var 착지_음량: float = -9.0
@export var 높은착지_음량: float = -6.0
@export var 죽음_음량: float = -4.0

@export_group("판정")
## 초 — 하수도 발소리(0.30)와 같은 걸음 간격. move_speed 390 달리기 애니 한 걸음과 맞다.
@export var 걸음_간격: float = 0.30
## 이 속도(px/s)보다 느리면 걷는 걸로 안 본다(벽에 막혀 미끄러지는 중 등).
@export var 걷기_최소속도: float = 40.0
## px — 공중에서 가장 높았던 곳부터 이만큼 넘게 떨어지면 "높은 곳 착지" 소리.
## 점프 높이 160 의 1.5 배. 평지 점프(160)는 일반 착지, 한 층 아래로 떨어지면 묵직한 소리.
@export var 높은착지_거리: float = 240.0
## px — 이보다 적게 떨어진 착지(턱 하나 내려가기)는 소리를 안 낸다. 걷다가 매번 쿵 하면 시끄럽다.
@export var 착지_최소거리: float = 12.0

var _플: CharacterBody2D
var _걷기: Array[AudioStream] = []
var _걷기_순번 := 0
var _걸음 := 0.0
var _최고점_y := INF          ## 공중에 있는 동안 가장 높았던 발 y (작을수록 높다)
var _착지_무시 := 0.0         ## 초 — 죽은 직후 리스폰 자리에 내려앉는 착지는 소리를 안 낸다
var _난수 := RandomNumberGenerator.new()

var _발: AudioStreamPlayer
var _몸: AudioStreamPlayer     ## 점프 · 착지 (한 번에 하나만 들리면 된다)
var _죽음: AudioStreamPlayer


func _ready() -> void:
	_플 = get_parent() as CharacterBody2D
	_난수.randomize()
	for n in ["걷기_1", "걷기_2"]:
		var s := _불러오기(n)
		if s:
			_걷기.append(s)
	_발 = _새_재생기("발")
	_몸 = _새_재생기("몸")
	_죽음 = _새_재생기("죽음")
	_죽음.stream = _불러오기("죽음_잉크터짐")


func _새_재생기(이름: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = 이름
	add_child(p)
	return p


func _불러오기(이름: String) -> AudioStream:
	var 파일 := 경로 + 이름 + ".ogg"
	if not ResourceLoader.exists(파일):
		return null
	return load(파일) as AudioStream


func _physics_process(delta: float) -> void:
	if _플 == null:
		return
	_착지_무시 = maxf(_착지_무시 - delta, 0.0)
	if _플.is_on_floor():
		_최고점_y = _플.global_position.y
		_걷기_갱신(delta)
	else:
		_최고점_y = minf(_최고점_y, _플.global_position.y)
		_걸음 = 걸음_간격 * 0.5      # 착지하고 걷기 시작하면 반 박자 뒤 첫 걸음(착지 소리와 안 겹치게)


func _걷기_갱신(delta: float) -> void:
	if absf(_플.velocity.x) < 걷기_최소속도 or _걷기.is_empty():
		_걸음 = 걸음_간격 * 0.5      # 멈췄다 다시 걸으면 반 박자 뒤 첫 걸음
		return
	_걸음 -= delta
	if _걸음 > 0.0:
		return
	_걸음 = 걸음_간격
	# 하수도 웅덩이 속이면 찰박 소리는 하수도_물소리.gd 가 낸다 → 여기는 쉰다(두 소리가 겹치지 않게).
	var 하수도 := get_tree().get_first_node_in_group("하수도_소리")
	if 하수도 and 하수도.has_method("발이_물속") and 하수도.발이_물속(_플.global_position):
		return
	# 두 발을 번갈아 + 높낮이를 조금씩 달리해 같은 소리가 기계처럼 반복되지 않게.
	_발.stream = _걷기[_걷기_순번 % _걷기.size()]
	_걷기_순번 += 1
	_발.pitch_scale = _난수.randf_range(0.92, 1.08)
	_발.volume_db = 걷기_음량 + _난수.randf_range(-1.5, 0.0)
	_발.play()


## player.gd — 점프가 실제로 성립한 프레임.
func 점프() -> void:
	_몸_재생("점프", 점프_음량, 0.95, 1.05)


## player.gd — 공중에 있다가 바닥에 닿은 프레임.
## 떨어진 거리를 속도가 아니라 **높이**로 잰다: 레벨 디자인이 "몇 px 아래" 로 말하니까
## (속도는 낙하_가속_증가율 같은 튜닝에 따라 같은 높이에서도 달라진다).
func 착지() -> void:
	if _플 == null or _착지_무시 > 0.0:
		return
	var 떨어진 := _플.global_position.y - _최고점_y
	if not is_finite(떨어진) or 떨어진 < 착지_최소거리:
		return
	if 떨어진 >= 높은착지_거리:
		_몸_재생("착지_높은곳", 높은착지_음량, 0.95, 1.03)
	else:
		_몸_재생("착지", 착지_음량, 0.93, 1.07)


## 월드.gd `_리스폰()` — 사망.
func 죽음() -> void:
	# 죽는 프레임에 막 난 점프·착지·발소리는 끊는다 — 잉크 터지는 소리가 묻히지 않게.
	_발.stop()
	_몸.stop()
	_걸음 = 걸음_간격 * 0.5
	# 리스폰 자리로 순간이동한 뒤 바닥에 닿는 것을 "착지" 로 읽지 않게.
	_착지_무시 = 0.3
	_최고점_y = INF
	if _죽음.stream:
		_죽음.volume_db = 죽음_음량
		_죽음.pitch_scale = _난수.randf_range(0.96, 1.04)
		_죽음.play()


func _몸_재생(이름: String, db: float, 낮음: float, 높음: float) -> void:
	var s := _불러오기(이름)      # load 는 캐시를 타므로 매번 불러도 디스크를 다시 읽지 않는다
	if s == null:
		return
	_몸.stream = s
	_몸.volume_db = db
	_몸.pitch_scale = _난수.randf_range(낮음, 높음)
	_몸.play()
