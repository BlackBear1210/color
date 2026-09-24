@tool
extends "res://scripts/스마트월드/호퍼.gd"
## 승인된 주철 아트만 교체하고 기존 입구/혼합/끊김 유예 로직을 상속한다.
const 주철_아틀라스 = preload("res://assets/textures/obstacles/hopper/cast_iron_v1/hopper_atlas.png")
@export_enum("직하:0", "좌하:1", "우하:2") var 출구방향: int = 0:
	set(value):
		출구방향 = clampi(value, 0, 2)
		_다시_만들기()

func _다시_만들기() -> void:
	super._다시_만들기()
	if not is_inside_tree():
		return
	# 몸통 목을 원점으로 유지하고 실제 노즐 끝으로 출구 포트만 옮긴다.
	# 연결된 물의 위치/판정은 임의로 회전시키지 않는다. 맵 제작 시 포트에 맞춘다.
	var port := get_node_or_null("출구_포트") as Marker2D
	if port != null:
		var offset := Vector2(0,112) if 출구방향 == 0 else Vector2(-85 if 출구방향 == 1 else 85, 90)
		port.position = offset * Vector2(폭 / 400.0, 높이 / 328.0)
	queue_redraw()

func _draw() -> void:
	# 투명 배경 원본의 셀을 직접 그려 색칠/발판 충돌과 아트 스케일을 분리한다.
	var ratio := Vector2(폭 / 400.0, 높이 / 328.0)
	var destination := Rect2(Vector2(-256.0 * ratio.x, -높이 - 20.0 * ratio.y), Vector2(512,480) * ratio)
	draw_texture_rect_region(주철_아틀라스, destination, Rect2(512 * 출구방향,240,512,480))
