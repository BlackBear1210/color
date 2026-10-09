@tool
extends RefCounted
## 기존 주철 원본의 질감·볼트·투명 구멍을 면별로 투영한다. 충돌이나 색 규칙은 바꾸지 않는다.
const 아틀라스 = preload("res://assets/textures/obstacles/grate/cast_iron_v1/grate_atlas.png")
const 지형투영 = preload("res://scripts/스마트월드/목재_상판메시.gd")

static func _면(item: CanvasItem, points: PackedVector2Array, source: Rect2, shade: float = 1.0) -> void:
	# 원본 구멍의 알파를 유지해야 물과 배경이 통과하는 격자로 읽힌다.
	var size := Vector2(아틀라스.get_size())
	var uv := PackedVector2Array([source.position / size,
		(source.position + Vector2(source.size.x, 0)) / size,
		source.end / size, (source.position + Vector2(0, source.size.y)) / size])
	item.draw_polygon(points, PackedColorArray([Color(shade, shade, shade, 1.0)]), uv, 아틀라스)

static func 그리기(item: CanvasItem, size: Vector2, white: bool) -> void:
	var source := Rect2(90, 810, 1075, 116) if white else Rect2(90, 326, 1074, 114)
	var left := -size.x * 0.5
	var right := size.x * 0.5
	var top := -size.y * 0.5
	# 돌과 동일하게 뒤(-4)에서 앞(+18)으로 22px 내려가며 오른쪽으로 18px 기운다.
	# 아주 좁은 발판만 같은 비율로 줄여 사선이 격자 전체를 삼키지 않게 한다.
	var shift := minf(지형투영.투영폭, size.x * 0.375)
	var depth := shift * 22.0 / 지형투영.투영폭
	var back_y := top - 4.0
	var front_y := back_y + depth
	var thickness := minf(8.0, size.y * 0.4)
	var run := size.x - shift
	var cap := minf(10.0, run * 0.2)
	# 왼쪽 옆면은 얇은 주철 테두리다. 볼트는 위쪽 고정판에 남긴다.
	_면(item, PackedVector2Array([Vector2(left, back_y), Vector2(left + shift, front_y),
		Vector2(left + shift, front_y + thickness), Vector2(left, back_y + thickness)]),
		Rect2(source.position + Vector2(2, 22), Vector2(18, 68)), 0.78)
	var cuts: Array[float] = [0.0, cap]
	var middle := maxf(run - cap * 2.0, 0.01)
	# 가운데만 통째로 늘리면 1040px 발판의 구멍이 거대해진다. 약 19px 모듈 수를 먼저 맞춘다.
	var count := maxi(1, roundi(middle / 19.0))
	for i in range(1, count + 1):
		cuts.append(cap + middle * float(i) / float(count))
	cuts.append(run)
	for i in range(cuts.size() - 1):
		var a := cuts[i]
		var b := cuts[i + 1]
		var piece := Rect2(source.position + Vector2(63, 0), Vector2(82, source.size.y))
		if i == 0:
			piece = Rect2(source.position, Vector2(48, source.size.y))
		elif i == cuts.size() - 2:
			piece = Rect2(source.position + Vector2(source.size.x - 48, 0), Vector2(48, source.size.y))
		# 윗면 전체와 구멍을 같은 평행사변형으로 투영해 바깥 테두리와 격자 방향이 일치한다.
		_면(item, PackedVector2Array([Vector2(left + a, back_y), Vector2(left + b, back_y),
			Vector2(left + b + shift, front_y), Vector2(left + a + shift, front_y)]), piece, 0.88 if white else 0.82)
		# 앞 단면에는 원본 아랫 테두리만 사용한다. 구멍 아래를 불투명한 큰 판으로 막지 않는다.
		var rim := Rect2(Vector2(piece.position.x, source.end.y - 16), Vector2(piece.size.x, 12))
		_면(item, PackedVector2Array([Vector2(left + a + shift, front_y), Vector2(left + b + shift, front_y),
			Vector2(left + b + shift, front_y + thickness), Vector2(left + a + shift, front_y + thickness)]), rim, 0.72)
