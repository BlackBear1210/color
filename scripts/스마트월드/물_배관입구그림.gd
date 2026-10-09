@tool
extends Node2D
## 본체의 셰이더 재질을 공유해 입구 위쪽만 그린다. 별도 물 그림/애니메이션 시계는 없다.
var _폭 := 0.0
var _깊이 := 0.0

func 설정(width: float, depth: float) -> void:
	if is_equal_approx(_폭, width) and is_equal_approx(_깊이, depth):
		return
	_폭 = width
	_깊이 = depth
	queue_redraw()

func _draw() -> void:
	# 본체는 y=0부터, 입구는 y<0만 그려 겹침/두 겹 명암 없이 한 물줄기로 만난다.
	if _폭 > 0.0 and _깊이 > 0.0:
		draw_rect(Rect2(-_폭 * .5 - 1.0, -_깊이, _폭 + 2.0, _깊이), Color.WHITE)
