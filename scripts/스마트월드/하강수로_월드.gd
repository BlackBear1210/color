extends "res://scripts/스마트월드/월드.gd"
## 투명·붕괴·이동 발판이 사라진 자리에 리스폰하는 것을 막기 위한 새 맵 전용 정책이다.
@export var 안전구역들: Array[Rect2] = []


func _안전점_갱신(delta: float, 죽는가: bool) -> void:
	var 허용 := false
	if _플레이어 != null and int(_플레이어.call("선택색")) == ColorDefs.BLACK:
		for 구역 in 안전구역들:
			if 구역.has_point(_플레이어.global_position):
				허용 = true
				break
	if not 허용:
		_안전_누적 = 0.0
		return
	# 기존 실제 바닥 레이·낙하 위험·저장 유예 검사는 그대로 수행한다.
	super._안전점_갱신(delta, 죽는가)
