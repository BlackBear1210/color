extends SceneTree
## ▼ 2026-06-21 (죽음/리스폰 검증용) 검정 플레이어를 흰색 지형 위에 놓아 사망→리스폰 확인.
##   실행: Godot --headless --path . -s res://tools/test_death.gd

var _root: Node
var _player: Node
var _sm: Node
var _frame := 0
var _deaths_before := 0
var _saw_dead := false
var _respawn_pos: Vector2

func _initialize() -> void:
	var ps: PackedScene = load("res://scenes/world_1/stage_3/stage_3.tscn")
	_root = ps.instantiate()
	get_root().add_child(_root)
	_sm = get_root().get_node_or_null("SceneManager")

func _process(_d: float) -> bool:
	_frame += 1
	if _player == null:
		_player = _root.get_node_or_null("Player")
		return false
	if _frame == 8:
		# 안착 후 상태 기록 + 흰색 칸(world x≈1150, y≈560) 위로 순간이동
		_respawn_pos = _player.respawn_point
		_deaths_before = int(_sm.death_count) if _sm else 0
		print("리스폰포인트 = ", _respawn_pos, ", 사망전 death_count = ", _deaths_before)
		print("초기 player_color(0=BLACK) = ", _player.player_color)
		_player.global_position = Vector2(1150, 540)
	elif _frame > 8:
		if _player.is_dead:
			_saw_dead = true
		# 사망을 봤고, 리스폰(위치 복귀 + is_dead 해제)까지 확인되면 종료
		if _saw_dead and not _player.is_dead and _player.global_position.distance_to(_respawn_pos) < 5.0:
			var deaths_now := int(_sm.death_count) if _sm else 0
			print("사망 감지 = ", _saw_dead)
			print("리스폰 후 위치 = ", _player.global_position, " (기대 ≈ ", _respawn_pos, ")")
			print("사망후 death_count = ", deaths_now, " (기대 ", _deaths_before + 1, ")")
			var ok: bool = _saw_dead and deaths_now == _deaths_before + 1
			print("DEATH_TEST_DONE  => ", "OK" if ok else "FAIL")
			quit(0 if ok else 1)
			return true
	if _frame > 300:
		print("DEATH_TEST_DONE  => FAIL (시간초과, saw_dead=%s)" % _saw_dead)
		quit(1)
		return true
	return false
