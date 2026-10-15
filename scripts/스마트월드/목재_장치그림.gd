@tool
extends RefCounted
## 점프대와 이동 발판은 같은 목재·철띠를 쓰되, 상판의 원근만 지형의 18:22 사선으로 통일한다.
## 원화의 대칭 사다리꼴 외곽을 다시 늘리지 않고 내부 질감만 면별로 투영한다. 물리 노드는 만들지 않는다.
const 판 = preload("res://assets/textures/props/신규기믹_v02/게임용/점프대/집_판.png")
const 받침 = preload("res://assets/textures/props/신규기믹_v02/게임용/점프대/집_받침.png")
const 지형투영 = preload("res://scripts/스마트월드/목재_상판메시.gd")

static func 깊이(width: float) -> float:
	return minf(지형투영.투영폭, width * 0.375) * 22.0 / 지형투영.투영폭

static func _면(item: CanvasItem, points: PackedVector2Array, source: Rect2, tint: Color) -> void:
	var tex_size := Vector2(판.get_size())
	var uv := PackedVector2Array([source.position / tex_size,
		(source.position + Vector2(source.size.x, 0)) / tex_size, source.end / tex_size,
		(source.position + Vector2(0, source.size.y)) / tex_size])
	item.draw_polygon(points, PackedColorArray([tint]), uv, 판)

static func 상판(item: CanvasItem, width: float, center_y: float, thickness: float,
		tint: Color = Color.WHITE, coverage: float = 1.0) -> void:
	var shift := minf(지형투영.투영폭, width * 0.375)
	var depth := 깊이(width)
	var left := -width * 0.5
	var run := width - shift
	var back := center_y - depth * 0.5
	var front := center_y + depth * 0.5
	# 볼트·철띠의 폭을 보존하고 판자 가운데만 늘린다. 부분 칠도 같은 면 좌표에서 잘라야 질감이 뛰지 않는다.
	var cap := minf(24.0, run * 0.28)
	var cuts: Array[float] = [0.0, cap, run - cap, run]
	var uv_cuts: Array[float] = [22.0, 72.0, 228.0, 278.0]
	var end := run * clampf(coverage, 0.0, 1.0)
	for i in 3:
		var a := cuts[i]
		var b := minf(cuts[i + 1], end)
		if b <= a:
			continue
		var u := uv_cuts[i]
		var span := (uv_cuts[i + 1] - u) * (b - a) / (cuts[i + 1] - a)
		_면(item, PackedVector2Array([Vector2(left + a, back), Vector2(left + b, back),
			Vector2(left + b + shift, front), Vector2(left + a + shift, front)]), Rect2(u, 4, span, 36), tint)
		_면(item, PackedVector2Array([Vector2(left + a + shift, front), Vector2(left + b + shift, front),
			Vector2(left + b + shift, front + thickness), Vector2(left + a + shift, front + thickness)]),
			Rect2(u, 49, span, 16), tint * Color(0.76, 0.76, 0.76, 1))
	if end > 0.0:
		_면(item, PackedVector2Array([Vector2(left, back), Vector2(left + shift, front),
			Vector2(left + shift, front + thickness), Vector2(left, back + thickness)]),
			Rect2(3, 48, 16, 16), tint * Color(0.55, 0.55, 0.55, 1))
	if coverage >= 1.0:
		# 검은 바닥에서도 밟는 면을 읽도록, 빛나는 장식 대신 마모된 가장자리를 한 줄만 남긴다.
		item.draw_polyline(PackedVector2Array([Vector2(left, back), Vector2(left + run, back),
			Vector2(left + run + shift, front)]), Color(0.48, 0.48, 0.47, 0.65), 1.0, true)

static func 이동_하부(item: CanvasItem, size: Vector2, vertical: bool) -> void:
	# 코일은 튕기는 장치에만 남긴다. 승강기는 피스톤, 가로형은 작은 도르래로 같은 시대의 장치를 구분한다.
	var y := -size.y * 0.5 + 7.0 + 깊이(size.x) * 0.5 + 7.0
	var w := size.x * 0.64
	item.draw_texture_rect(받침, Rect2(-w * 0.5, y, w, 8), false, Color(0.68, 0.68, 0.66))
	for side: float in [-1.0, 1.0]:
		var x := side * size.x * 0.30
		if vertical:
			item.draw_line(Vector2(x, y + 4), Vector2(x, y + 16), Color(0.10, 0.10, 0.10), 6.0, true)
			item.draw_line(Vector2(x - 1, y + 5), Vector2(x - 1, y + 14), Color(0.42, 0.42, 0.41), 1.5, true)
			item.draw_rect(Rect2(x - 5, y + 13, 10, 4), Color(0.19, 0.19, 0.18))
		else:
			item.draw_circle(Vector2(x, y + 8), 5.0, Color(0.10, 0.10, 0.10))
			item.draw_arc(Vector2(x, y + 8), 4.0, PI, TAU, 10, Color(0.42, 0.42, 0.40), 1.3, true)
			item.draw_circle(Vector2(x, y + 8), 1.3, Color(0.50, 0.50, 0.48))
