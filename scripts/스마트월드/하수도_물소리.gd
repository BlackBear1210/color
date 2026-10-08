extends Node
## ============================================================================
## [2026-09-30 Claude] 하수도 효과음 — 발소리 · 입수 · 떨어지는 물소리.
## ----------------------------------------------------------------------------
## ▣ 어디서 켜지나
##   `하수도_실시간벽등.gd` 가 스테이지에 하나 만든다 → 그 배경을 쓰는 하수도 스테이지만.
##
## ▣ 소리 (tools/생성_하수도_효과음.py 가 합성 · 진짜 음원이 오면 같은 이름으로 덮어쓰면 된다)
##   · 발소리: 바닥에 서서 움직이면 걸음 간격마다. 발이 웅덩이 안이면 찰박, 아니면 돌바닥 툭.
##   · 입수: 웅덩이에 들어가는 순간(웅덩이_하수도29.gd 가 `입수()` 를 부른다) 풍덩 — 떨어진 세기만큼 크게.
##   · 떨어지는 물: 켜진 물줄기(유체_흰물v2)마다 아래 끝(착수점)에 2D 소리 — 멀어지면 작아진다.
##     물을 끄면(밸브·저장고) 소리도 멈춘다.
## ============================================================================

const 경로 := "res://assets/audio/sewer/"
const 걸음_간격 := 0.30          ## 초 — 달리기 애니 한 걸음과 비슷하게
const 물소리_거리 := 900.0       ## px — 이보다 멀면 안 들린다
## [2026-09-30 도형님] 물소리·발소리 20% 낮춤 — 소리 크기(진폭) × 0.8 = 약 −1.9 dB.
const 발소리_배율 := 0.8
const 물소리_배율 := 0.8

var _돌: Array[AudioStream] = []
var _물발: Array[AudioStream] = []
var _풍덩: AudioStream
var _발: AudioStreamPlayer
var _입수: AudioStreamPlayer
var _걸음 := 0.0
var _물줄기: Dictionary = {}     ## 유체 → AudioStreamPlayer2D
var _훑기 := 0.0
var _난수 := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("하수도_소리")
	_난수.randomize()
	for i in 4:
		_돌.append(load(경로 + "step_stone_%d.wav" % (i + 1)))
		_물발.append(load(경로 + "step_water_%d.wav" % (i + 1)))
	_풍덩 = load(경로 + "splash_enter.wav")
	_발 = AudioStreamPlayer.new()
	_발.volume_db = -12.0
	add_child(_발)
	_입수 = AudioStreamPlayer.new()
	_입수.stream = _풍덩
	add_child(_입수)

func 입수(세기: float) -> void:
	# 걸어 들어가면 작게, 높은 데서 떨어지면 크게.
	_입수.volume_db = lerpf(-16.0, -4.0, clampf(세기, 0.0, 1.0))
	_입수.pitch_scale = _난수.randf_range(0.92, 1.08)
	_입수.play()

func _physics_process(delta: float) -> void:
	var 플 := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if 플 != null:
		_발소리(플, delta)
	_훑기 -= delta
	if _훑기 <= 0.0:
		_훑기 = 0.25
		_물줄기_갱신()

func _발소리(플: CharacterBody2D, delta: float) -> void:
	var 움직임 := absf(플.velocity.x)
	if not 플.is_on_floor() or 움직임 < 40.0:
		_걸음 = 걸음_간격 * 0.5      # 멈췄다 다시 걸으면 반 박자 뒤 첫 걸음
		return
	_걸음 -= delta
	if _걸음 > 0.0:
		return
	_걸음 = 걸음_간격
	var 물속 := _발이_물속(플.global_position)
	# [2026-10-05] 마른 바닥 발소리는 이제 플레이어의 `효과음` 노드(플레이어_효과음.gd · ElevenLabs 음원)가 낸다.
	#   여기서도 돌 발소리를 내면 한 걸음에 두 번 울린다 → 웅덩이 속 찰박만 맡는다.
	#   (효과음 노드가 없는 옛 플레이어 씬이면 예전처럼 돌 발소리도 낸다)
	if not 물속 and 플.get_node_or_null("효과음") != null:
		return
	var 목록 := _물발 if 물속 else _돌
	_발.stream = 목록[_난수.randi_range(0, 목록.size() - 1)]
	_발.pitch_scale = _난수.randf_range(0.9, 1.1)
	_발.volume_db = (-10.0 if 물속 else -14.0) + linear_to_db(발소리_배율)
	_발.play()

## [2026-10-05] 플레이어_효과음.gd 가 묻는다 — 물속이면 그쪽은 발소리를 쉬고 여기서 찰박을 낸다.
func 발이_물속(발: Vector2) -> bool:
	return _발이_물속(발)

func _발이_물속(발: Vector2) -> bool:
	for pool in get_tree().get_nodes_in_group("웅덩이"):
		if not pool.get("켜짐"):
			continue
		var local: Vector2 = (pool as Node2D).to_local(발)
		var 크기: Vector2 = pool.get("크기")
		if absf(local.x) <= 크기.x * 0.5 and local.y >= -크기.y and local.y <= 4.0:
			return true
	return false

## 켜진 물줄기마다 착수점에 반복 소리를 단다. 끄면 멈춘다. 호퍼로 들어가는 물도 소리가 난다(짧게 떨어진다).
func _물줄기_갱신() -> void:
	var 루트 := get_parent()
	for n in 루트.find_children("*", "Area2D", true, false):
		if n.get("물줄기_v3") == null or n.get("크기") == null:
			continue
		var 켜짐: bool = n.get("켜짐")
		if not _물줄기.has(n):
			if not 켜짐:
				continue
			var p := AudioStreamPlayer2D.new()
			var s := (load(경로 + "stream_loop.wav") as AudioStreamWAV).duplicate() as AudioStreamWAV
			# 합성한 WAV 는 반복 표시가 없다 → 실행 중에 전체 구간 반복으로 켠다(파일 끝과 처음이 이미 이어지게 만들었다).
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(s.get_length() * s.mix_rate)
			p.stream = s
			p.max_distance = 물소리_거리
			p.attenuation = 1.6
			var 크기: Vector2 = n.get("크기")
			# 넓은 물막일수록 크게(-14 ~ -4 dB) · 물줄기마다 높낮이를 조금 달리해 겹쳐도 한 소리로 뭉개지지 않게.
			p.volume_db = lerpf(-14.0, -4.0, clampf((크기.x - 32.0) / 400.0, 0.0, 1.0)) + linear_to_db(물소리_배율)
			p.pitch_scale = _난수.randf_range(0.85, 1.15)
			p.position = Vector2(0.0, 크기.y)
			n.add_child(p)
			_물줄기[n] = p
		var 소리 := _물줄기[n] as AudioStreamPlayer2D
		if 켜짐 and not 소리.playing:
			소리.play(_난수.randf_range(0.0, 2.5))
		elif not 켜짐 and 소리.playing:
			소리.stop()
