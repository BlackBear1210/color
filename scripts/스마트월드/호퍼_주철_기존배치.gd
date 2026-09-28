@tool
extends "res://scripts/스마트월드/호퍼_주철.gd"
## 기존 맵의 입구 높이와 출구 원점을 그대로 둔 주철 외관 교체용 어댑터.
## 연결 유체를 옮기면 길이/착지/퍼즐까지 바뀌므로 직하 아트 전체를 기존 높이에 맞춘다.
func _다시_만들기() -> void:
	super._다시_만들기()
	var port := get_node_or_null("출구_포트") as Marker2D
	if port != null:
		port.position = Vector2.ZERO

func _draw() -> void:
	# 원본 입구 y260과 노즐 끝 y700을 각각 -높이와 0에 맞춘다.
	_주철_그리기(입구_아트_배율(), 0)

func 입구_아트_배율() -> Vector2:
	# 같은 입구 수면이 기존 높이로 눌린 아트에도 정확히 맞도록 배율만 다르게 준다.
	return Vector2(폭 / 400.0, 높이 / 440.0)
