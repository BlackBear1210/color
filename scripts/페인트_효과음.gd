extends RefCounted
## [2026-10-10 Codex] 발사·명중·몬스터 발걸음의 공통 재생기.
## 소리를 현재 씬에 붙여 총알이 사라져도 명중음 꼬리가 잘리지 않게 한다.
## 거리 감쇠로 화면 밖 몬스터가 플레이어 소리를 덮지 않으며, 씬 전환 때 함께 정리된다.

const 경로 := "res://assets/audio/sfx/"
static var _음원: Dictionary = {}


static func 재생(호출자: Node, 이름: String, 위치: Vector2,
		음량: float = -10.0, 높낮이: float = 1.0) -> void:
	if not 호출자.is_inside_tree() or Engine.is_editor_hint():
		return
	var 씬 := 호출자.get_tree().current_scene
	if 씬 == null:
		return
	if not _음원.has(이름):
		var 파일 := 경로 + 이름 + ".ogg"
		# 새 음원의 에디터 임포트 전에는 조용히 쉰다. null은 캐시하지 않아 이후 재시도한다.
		if not ResourceLoader.exists(파일):
			return
		var 스트림 := load(파일) as AudioStream
		if 스트림 == null:
			return
		_음원[이름] = 스트림
	var 소리 := AudioStreamPlayer2D.new()
	# 발사·명중·몬스터 발걸음은 효과음이며 재생기 자체의 거리·음량 조절도 유지한다.
	preload("res://scripts/스마트월드/게임설정.gd").소리_준비()
	소리.bus = "SFX"
	소리.stream = _음원[이름]
	소리.volume_db = 음량
	소리.pitch_scale = 높낮이
	소리.max_distance = 1100.0
	소리.attenuation = 1.4
	씬.add_child(소리)
	# 부모 씬에 변환이 있어도 실제 발사·충돌 위치에서 들려야 한다.
	소리.global_position = 위치
	소리.finished.connect(소리.queue_free)
	소리.play()
