@tool
extends RefCounted
## 누름 발판을 지형과 같은 사선으로 투영한다. 원본에 그려진 대칭 원근은 면 안쪽만 잘라 제거한다.
const 부품 = preload("res://assets/textures/obstacles/switch/cast_iron_v1/parts.png")
const 지형투영 = preload("res://scripts/스마트월드/목재_상판메시.gd")
## 게임 배율에서 누름 전후가 구분되도록 기존 2~3px 대신 8px 스트로크를 쓴다. 그림만 움직인다.
const 상판_돌출 := 8.0
const 상판_두께 := 4.0

static func 상판_올림(pressed: float) -> float:
	return (1.0 - clampf(pressed, 0.0, 1.0)) * 상판_돌출

static func 기하(width: float, height: float) -> Dictionary:
	var shift := minf(지형투영.투영폭, width * 0.375)
	var depth := shift * 22.0 / 지형투영.투영폭
	var back := -height - 4.0
	return {"left": -width * 0.5, "run": width - shift, "shift": shift,
		"back": back, "front": back + depth, "thickness": minf(14.0, maxf(6.0, height * 0.4375))}

static func 윤곽(width: float, height: float) -> PackedVector2Array:
	var g := 기하(width, height)
	var l: float = g.left
	var r: float = l + g.run
	var s: float = g.shift
	var b: float = g.back
	var f: float = g.front
	var t: float = g.thickness
	return PackedVector2Array([Vector2(l, b), Vector2(r, b), Vector2(r + s, f),
		Vector2(r + s, f + t), Vector2(l + s, f + t), Vector2(l, b + t)])

static func _면(item: CanvasItem, points: PackedVector2Array, source: Rect2, shade: float) -> void:
	var size := Vector2(부품.get_size())
	var uv := PackedVector2Array([source.position / size,
		(source.position + Vector2(source.size.x, 0)) / size, source.end / size,
		(source.position + Vector2(0, source.size.y)) / size])
	item.draw_polygon(points, PackedColorArray([Color(shade, shade, shade)]), uv, 부품)

static func _띠(item: CanvasItem, left: float, run: float, back: float, front: float,
		shift: float, source: Rect2, cap: float, shade: float) -> void:
	# 볼트는 양끝 폭을 고정하고 중앙 재질만 늘린다. 원본의 사선 외곽은 투영 면에 넣지 않는다.
	var edge := minf(18.0, run * 0.24)
	var cuts: Array[float] = [0.0, edge, run - edge, run]
	var sources: Array[Rect2] = [Rect2(source.position, Vector2(cap, source.size.y)),
		Rect2(source.position + Vector2(cap, 0), Vector2(source.size.x - cap * 2.0, source.size.y)),
		Rect2(source.position + Vector2(source.size.x - cap, 0), Vector2(cap, source.size.y))]
	for i in 3:
		_면(item, PackedVector2Array([Vector2(left + cuts[i], back), Vector2(left + cuts[i + 1], back),
			Vector2(left + cuts[i + 1] + shift, front), Vector2(left + cuts[i] + shift, front)]), sources[i], shade)

static func 압력_그리기(item: CanvasItem, width: float, height: float, pressed: float, active: bool) -> void:
	var g := 기하(width, height)
	var l: float = g.left
	var run: float = g.run
	var s: float = g.shift
	var b: float = g.back
	var f: float = g.front
	var t: float = g.thickness
	# 고정 프레임은 돌 윗면과 같은 높이, 움직이는 판만 8px 올라간다. 충돌/누름 감지는 보존한다.
	_면(item, PackedVector2Array([Vector2(l, b), Vector2(l + s, f), Vector2(l + s, f + t), Vector2(l, b + t)]),
		Rect2(36, 432, 26, 54), 0.48)
	_띠(item, l + s, run, f, f + t, 0.0, Rect2(32, 429, 562, 60), 86.0, 0.67)
	item.draw_colored_polygon(PackedVector2Array([Vector2(l, b), Vector2(l + run, b),
		Vector2(l + run + s, f), Vector2(l + s, f)]), Color(0.06, 0.06, 0.06))
	var lift := 상판_올림(pressed)
	var inset := minf(3.0, run * 0.05)
	# 올라간 판이 허공에 뜬 것처럼 보이지 않게 틈 안쪽에 작은 가이드 축을 둔다. 눌리면 프레임 안에 가려진다.
	if lift > 0.01:
		for ratio: float in [0.18, 0.82]:
			var x := l + inset + s + (run - inset * 2.0) * ratio
			item.draw_texture_rect_region(부품, Rect2(x - 2.0, f - lift + 상판_두께, 4.0, lift),
				Rect2(694, 442, 18, 30), Color(0.42, 0.42, 0.42))
	# 윗면/얇은 앞 단면에 서로 다른 평면 원본을 써 대칭 모따기와 사선을 이중으로 그리지 않는다.
	_면(item, PackedVector2Array([Vector2(l + inset, b - lift), Vector2(l + inset + s, f - lift),
		Vector2(l + inset + s, f - lift + 상판_두께), Vector2(l + inset, b - lift + 상판_두께)]), Rect2(694, 445, 22, 26), 0.52)
	_띠(item, l + inset, run - inset * 2.0, b - lift, f - lift, s, Rect2(718, 401, 444, 31), 68.0, 0.76)
	_띠(item, l + inset + s, run - inset * 2.0, f - lift, f - lift + 상판_두께, 0.0, Rect2(694, 442, 492, 30), 60.0, 0.58)
	# 접합 명암은 면 안쪽 1px에만 두어 바깥에 밝은 스티커 테두리가 생기지 않게 한다.
	item.draw_line(Vector2(l + s + 1.0, f + 상판_두께 + 0.5), Vector2(l + run + s - 1.0, f + 상판_두께 + 0.5), Color(0.025, 0.025, 0.025, 0.75), 1.0)
	if active:
		# 출력이 실제로 켜진 표시창은 게임 배율에서도 읽히도록 2.5px로 키운다. 유지형 버튼의 활성 의미는 보존한다.
		item.draw_rect(Rect2(-width * 0.12 + s * 0.5, f + t * 0.52, width * 0.24, 2.5), Color(0.87, 0.87, 0.85))
