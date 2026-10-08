extends "res://scripts/스마트월드/월드.gd"
## 유령 위의 자동 저장점은 사망 후 페인트 회수로 사라지므로 이 맵은 고정 준비대만 저장한다.
## 공통 월드의 사망/페인트/레버 규칙을 바꾸지 않고, 이 씬의 재시작 위치와 바탕색만 보정한다.

var _재시작색: int = 0


func _안전점_갱신(_delta: float, 죽는가: bool) -> void:
	if not 안전지점_자동저장 or 죽는가 or _플레이어 == null:
		return
	# 순간이동 직후 남아 있는 is_on_floor 값만으로 공중을 저장하지 않는다.
	if not _플레이어.is_on_floor() or not _발밑에_땅있나():
		return
	for 이름 in ["CP_갈래앞", "CP_종합앞", "CP_출구"]:
		var 지점 := get_node_or_null(NodePath(이름)) as Node2D
		if 지점 == null:
			continue
		var 차이 := _플레이어.global_position - 지점.global_position
		if absf(차이.x) > 64.0 or absf(차이.y) > 4.0:
			continue
		_안전점 = 지점.global_position
		# 사망하면 페인트가 초기화되므로 현재 칠한 색이 아니라 이 준비대의 원래 바탕색을 저장한다.
		# 씬 메타데이터 식별자는 ASCII로 저장해 한글 키의 로드 오류를 피한다.
		_재시작색 = int(지점.get_meta("checkpoint_base_color", 0))
		if 지점.has_method("켜기"):
			지점.call("켜기")
		return


func _부활_후처리() -> void:
	# 공통 사망이 비동기가 되었으므로 실제 부활 직후에 준비대 색을 복원한다.
	super._부활_후처리()
	# 흰 몸으로 죽고 검정 준비대에 돌아와 반복 사망하는 경우를 막는다.
	if _플레이어 != null:
		_플레이어.set("player_color", _재시작색)
