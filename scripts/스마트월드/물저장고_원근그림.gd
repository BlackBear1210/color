@tool
extends RefCounted
## [2026-10-10 Codex] 지형과 같은 사선의 철제 저장고. 그림만 바꿔 충돌·물 공급을 보존한다.
const 지형투영 = preload("res://scripts/스마트월드/목재_상판메시.gd")


static func _면(item: CanvasItem, points: Array, shade: float) -> void:
	item.draw_colored_polygon(PackedVector2Array(points), Color(shade, shade, shade))


static func 그리기(item: CanvasItem, size: Vector2, state: int, paint: int, hits: int, required: int) -> void:
	var l := -size.x * 0.5
	var r := size.x * 0.5
	var t := -size.y * 0.5
	var b := size.y * 0.5
	# 깊이는 충돌 사각형 안쪽으로만 넣는다. 아래 접지선이나 배관 포트를 옮기지 않는다.
	var shift := minf(지형투영.투영폭, minf(size.x * 0.18, size.y * 0.25))
	var depth := shift * 22.0 / 지형투영.투영폭
	var front := t + depth
	var edge := minf(7.0, minf(size.x, size.y) * 0.09)
	var white := state == ColorDefs.WHITE
	var body := 0.66 if white else 0.13
	var lid := 0.79 if white else 0.26
	var side := 0.40 if white else 0.095
	# 상면·왼쪽 측면·정면 모두 같은 구조를 유지하고 명도만 바꾼다.
	_면(item, [Vector2(l, t), Vector2(r - shift, t), Vector2(r, front), Vector2(l + shift, front)], lid)
	_면(item, [Vector2(l, t), Vector2(l + shift, front), Vector2(l + shift, b), Vector2(l, b - depth)], side)
	item.draw_rect(Rect2(Vector2(l + shift, front), Vector2(size.x - shift, b - front)), Color(body, body, body))
	item.draw_line(Vector2(l + shift, front), Vector2(r, front), Color(0.035, 0.035, 0.035), 2.0)
	item.draw_line(Vector2(l, t), Vector2(r - shift, t), Color(0.43, 0.43, 0.43), 1.0)
	# 다리를 밖으로 추가하지 않고 본체 안에 받침을 만들어 원래 바닥에 붙여 보인다.
	item.draw_rect(Rect2(Vector2(l + shift, b - edge), Vector2(size.x - shift, edge)), Color(0.12, 0.12, 0.12))
	item.draw_line(Vector2(l + shift, b - edge), Vector2(r, b - edge), Color(0.34, 0.34, 0.34), 1.0)
	# 넓은 관측창과 중간 명도의 얇은 틀로 검정 내용물도 어두운 배경에서 구별한다.
	var window := Rect2(Vector2(l + shift + edge, front + edge), Vector2(size.x - shift - edge * 2.0, b - front - edge * 2.0))
	item.draw_rect(window.grow(2.0), Color(0.055, 0.055, 0.055))
	item.draw_rect(window, Color(0.22, 0.22, 0.22))
	var inner := window.grow(-2.0)
	item.draw_rect(inner, Color(0.075, 0.075, 0.075))
	var progress := 1.0 if state >= 0 else clampf(float(hits) / float(maxi(required, 1)), 0.0, 1.0)
	var color := state if state >= 0 else paint
	var liquid := 0.90 if color == ColorDefs.WHITE else (0.46 if color == ColorDefs.GRAY else 0.035)
	if progress > 0.0:
		# 가득 찬 상태에도 어두운 공기층을 남겨 흰색 간판처럼 보이지 않게 한다.
		var water_height := inner.size.y * 0.86 * progress
		var surface := inner.end.y - water_height
		item.draw_rect(Rect2(Vector2(inner.position.x, surface), Vector2(inner.size.x, water_height)), Color(liquid, liquid, liquid))
		var wave := PackedVector2Array()
		for i in range(13):
			var u := float(i) / 12.0
			wave.append(Vector2(inner.position.x + inner.size.x * u, surface + sin(u * TAU * 1.5) * minf(1.2, water_height * 0.06)))
		var ripple := 0.50 if color == ColorDefs.WHITE else 0.32
		item.draw_polyline(wave, Color(ripple, ripple, ripple), 1.2, true)
		# 약한 가로 물결만 넣어 검정 상태가 회색 액체처럼 보이지 않게 한다.
		for i in range(1, 4):
			var y := surface + water_height * float(i) / 4.0
			var tone := 0.82 if color == ColorDefs.WHITE else (0.40 if color == ColorDefs.GRAY else 0.08)
			item.draw_line(Vector2(inner.position.x + inner.size.x * 0.22, y), Vector2(inner.end.x - inner.size.x * 0.12, y), Color(tone, tone, tone), 1.0)
	else:
		# 무색은 빈 탱크의 교차선으로 표현해 검정색 만수 상태와 구별한다.
		item.draw_line(inner.position + inner.size * 0.25, inner.position + inner.size * 0.75, Color(0.30, 0.30, 0.30), 1.2)
		item.draw_line(inner.position + Vector2(inner.size.x * 0.75, inner.size.y * 0.25), inner.position + Vector2(inner.size.x * 0.25, inner.size.y * 0.75), Color(0.30, 0.30, 0.30), 1.2)
	# 흑백 양쪽에서 눈금을 읽게 하고 짧은 유리 반사로 색 면이 뿌옇게 보이는 것을 막는다.
	var ink := 0.32 if color == ColorDefs.WHITE and progress > 0.0 else 0.52
	for i in range(1, 4):
		var y := inner.position.y + inner.size.y * float(i) / 4.0
		item.draw_line(Vector2(inner.position.x + 2.0, y), Vector2(inner.position.x + minf(8.0, inner.size.x * 0.12), y), Color(ink, ink, ink), 1.2)
	item.draw_line(inner.position + Vector2(2.0, 2.0), inner.position + Vector2(inner.size.x * 0.30, 2.0), Color(0.48, 0.48, 0.48, 0.55), 1.0)
	# 리벳은 같은 자리에 고정하고 작은 탱크에서도 창을 가리지 않게 크기를 제한한다.
	var bolt := minf(1.8, edge * 0.25)
	for x in [l + shift + edge * 0.45, r - edge * 0.45]:
		for y in [front + edge * 0.45, b - edge * 0.45]:
			item.draw_circle(Vector2(x, y), bolt + 0.7, Color(0.055, 0.055, 0.055))
			item.draw_circle(Vector2(x, y), bolt, Color(0.46, 0.46, 0.46))
			item.draw_line(Vector2(x - bolt * 0.6, y), Vector2(x + bolt * 0.6, y), Color(0.15, 0.15, 0.15), 0.7)
	# 상단 중앙 포트의 기존 좌표 (0, t - 16)를 보존하고 둥근 관 명암과 이음쇠만 더한다.
	var neck := minf(12.0, size.x * 0.14)
	item.draw_rect(Rect2(Vector2(-neck, t - 16.0), Vector2(neck * 2.0, depth + 16.0)), Color(0.10, 0.10, 0.10))
	item.draw_rect(Rect2(Vector2(-neck + 2.0, t - 16.0), Vector2(neck * 0.40, depth + 16.0)), Color(0.29, 0.29, 0.29))
	for y in [t - 14.0, front - 3.0]:
		item.draw_rect(Rect2(Vector2(-neck - 2.0, y), Vector2(neck * 2.0 + 4.0, 3.0)), Color(0.32, 0.32, 0.32))
