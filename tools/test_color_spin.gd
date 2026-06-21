extends SceneTree
## ▼ 2026-06-22 (검증용) 색 전환 회전 모션 단독 검증.
##   플레이어를 '지형 없이' 띄워(색 사망 없음) _toggle_color() 의 회전/스케일 모션과
##   player.gd/bullet.gd 컴파일·런타임 에러 0 을 확인한다.
var _player: Node
var _frame := 0
var _base_scale: Vector2
var _color0: int
var _toggles := 0
var _saw_spin := false

func _initialize() -> void:
	var ps: PackedScene = load("res://scenes/player/Player.tscn")
	if ps == null:
		print("FAIL: Player 로드 실패"); quit(1); return
	_player = ps.instantiate()
	get_root().add_child(_player)

func _process(_d: float) -> bool:
	_frame += 1
	if _frame > 4000:
		print("TIMEOUT"); quit(1); return true
	if _player == null:
		return true
	var spr: Node = _player.get_node_or_null("AnimatedSprite2D")
	if spr == null:
		return false
	if _frame == 4:
		_base_scale = spr.scale
		_color0 = _player.player_color
		_player._toggle_color()       # 색 전환 + 회전 모션 시작
		print("토글 직후 player_color = ", _player.player_color, " (이전 ", _color0, ")")
	elif _frame > 4:
		# 회전 트윈 진행 중 한 번이라도 rotation 이 의미있게 돌았는지 확인
		if absf(spr.rotation) > 1.0:
			_saw_spin = true
		# 회전이 한 바퀴 돈 뒤 0 으로 복귀했는지(트윈 콜백). 스케일은 스쿼시가 제어하므로 검사 제외.
		if _saw_spin and absf(spr.rotation) < 0.01:
			var color_changed: bool = _player.player_color != _color0
			print("회전 발생 = ", _saw_spin, ", 복귀 rotation = ", spr.rotation)
			print("스케일(스쿼시 제어중) = ", spr.scale)
			print("색 변경됨 = ", color_changed, ", 사망상태 = ", _player.is_dead, " (기대 false)")
			var ok: bool = _saw_spin and color_changed and not _player.is_dead
			print("COLOR_SPIN_TEST => ", "OK" if ok else "FAIL")
			quit(0 if ok else 1)
			return true
	return false
