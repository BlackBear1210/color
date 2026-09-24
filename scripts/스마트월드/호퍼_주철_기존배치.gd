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
	var ratio := Vector2(폭 / 400.0, 높이 / 440.0)
	var destination := Rect2(Vector2(-256.0 * ratio.x, -높이 - 20.0 * ratio.y), Vector2(512,480) * ratio)
	draw_texture_rect_region(주철_아틀라스, destination, Rect2(0,240,512,480))
