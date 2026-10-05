@tool
extends RefCounted
## 하수도 마감메시의 노출 구간/이웃 가림 방식을 참고한 목재 전용 덮개.
## 모든 마감을 메시 하나로 합친다. 충돌 점 추가·매 프레임 재생성·픽셀별 경계 검색은 없다.

static func 정리(points: PackedVector2Array) -> PackedVector2Array:
	var p := points.duplicate()
	if p.size() > 1 and p[0].is_equal_approx(p[-1]):
		p.remove_at(p.size() - 1)
	var changed := true
	while changed and p.size() > 3:
		changed = false
		for i in p.size():
			var a := p[i] - p[(i - 1 + p.size()) % p.size()]
			var b := p[(i + 1) % p.size()] - p[i]
			if a.length_squared() < 0.0001 or (absf(a.cross(b)) < 0.001 and a.dot(b) > 0.0):
				p.remove_at(i)
				changed = true
				break
	if Geometry2D.is_polygon_clockwise(p):
		p.reverse()
	return p

static func 노출(a: Vector2, b: Vector2, others: Array[PackedVector2Array]) -> Array[Vector2]:
	var v := b - a
	var length := v.length()
	var n := Vector2(v.y, -v.x).normalized()
	var start := a + n * 0.5
	var finish := b + n * 0.5
	var cuts: Array[float] = [0.0, 1.0]
	for polygon in others:
		for i in polygon.size():
			var hit: Variant = Geometry2D.segment_intersects_segment(start, finish, polygon[i], polygon[(i + 1) % polygon.size()])
			if hit != null:
				cuts.append(clampf((Vector2(hit) - start).dot(v / length) / length, 0.0, 1.0))
	cuts.sort()
	var result: Array[Vector2] = []
	for i in range(cuts.size() - 1):
		if cuts[i + 1] - cuts[i] < 0.00001:
			continue
		var mid := start.lerp(finish, (cuts[i] + cuts[i + 1]) * 0.5)
		var covered := false
		for polygon in others:
			if Geometry2D.is_point_in_polygon(mid, polygon):
				covered = true
				break
		if not covered:
			result.append(Vector2(cuts[i], cuts[i + 1]))
	return result

static func 가림(parts: Array[PackedVector2Array], others: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	for other in others:
		var next: Array[PackedVector2Array] = []
		for piece in parts:
			for clipped in Geometry2D.clip_polygons(piece, other):
				if not Geometry2D.is_polygon_clockwise(clipped):
					next.append(clipped)
		parts = next
	return parts

## [2026-10-05 Claude] run_l / run_w = 이 상판 구간의 왼쪽 끝 x 와 '맞춘' 판자 폭(px).
##   도형님: "윗면 이미지의 나무판자 타일 크기에 맞추어 끝나는 지점을 맞춰야" — 월드 좌표 64px 반복을 쓰면
##   32px 격자 발판(예: 5칸 = 160px)의 끝에서 판자가 반 장씩 잘린다. 그래서 구간마다 판자 수 n = round(길이/64) 로
##   폭을 살짝 늘이거나 줄여 **왼쪽 끝 사선과 오른쪽 끝이 정확히 이음새**가 되게 한다.
static func 면추가(data: Dictionary, poly: PackedVector2Array, own: PackedVector2Array, others: Array[PackedVector2Array], a: Vector2, b: Vector2, kind: int, inside: bool = true, run_l: float = 0.0, run_w: float = 64.0) -> void:
	if Geometry2D.is_polygon_clockwise(poly):
		poly = poly.duplicate()
		poly.reverse()
	var parts: Array[PackedVector2Array] = []
	if inside:
		for clipped in Geometry2D.intersect_polygons(poly, own):
			if not Geometry2D.is_polygon_clockwise(clipped):
				parts.append(clipped)
	else:
		# 충돌선 위 4px의 뒷모서리만 돌출시킨다. 같은 지형의 벽에 가려진 부분은 뺀다.
		for clipped in Geometry2D.clip_polygons(poly, own):
			if not Geometry2D.is_polygon_clockwise(clipped):
				parts.append(clipped)
	parts = 가림(parts, others)
	var inward := Vector2(-(b-a).y, (b-a).x).normalized()
	for piece in parts:
		var triangles := Geometry2D.triangulate_polygon(piece)
		if triangles.is_empty():
			continue
		var offset: int = data["vertices"].size()
		for p in piece:
			data["vertices"].append(p)
			var origin: Vector2 = data["origin"]
			var uv := Vector2((p.x+origin.x) / 256.0, (p.y-a.y+4.0)/30.0)
			if kind == 0:
				# 상판(뒤 4px 돌출 포함)·앞 단면: 판자 좌표를 메시에서 미리 굽는다(셰이더는 uv.x*4 를 그대로 판자 번호로 쓴다).
				#   깊이(뒤 0 → 앞 1, 22px)만큼 18px 오른쪽으로 밀린 사선 = 왼쪽 끝 단면과 같은 투영 방향.
				#   상판 사각형 안에서는 선형이라 꼭짓점에만 넣어도 정확하다.
				var depth := clampf((p.y - (a.y - 4.0)) / 22.0, 0.0, 1.0)
				uv.x = ((p.x - run_l - 18.0 * depth) / run_w) / 4.0
			elif kind == 2 or kind == 3:
				uv.y = float(kind) + clampf((p.y-a.y+4.0)/30.0, 0.0, 0.999)
			elif kind >= 4:
				var width := 3.0 if kind == 6 else (18.0 if kind == 4 else (3.0 if kind == 7 else 8.0))
				var across := clampf((p-a).dot(inward)/width, 0.0, 0.999)
				var along := 0.0
				if kind == 4:
					# [2026-10-05 Claude] 왼 단면 = 상자의 옆면. 앞면 판자 줄(월드 y 32px)이 모서리를 돌아
					#   옆면으로 이어지도록, 옆면 이음새는 바깥(뒤)으로 갈수록 22px 올라가는 사선이다.
					#   across 0 = 바깥 모서리(뒤) · 1 = 앞면과 만나는 선 → 거기서 앞면 이음새와 정확히 이어진다.
					along = (p.y + origin.y + (1.0 - across) * 22.0) / 32.0
				elif kind == 5:
					along = (p.y + origin.y) / 32.0      # 오른쪽은 가려진 면 — 앞면 줄과 같은 높이의 그늘
				else:
					along = (p.x + origin.x) / 64.0
				uv = Vector2(along, float(kind) + across)
			data["uvs"].append(uv)
		for index in triangles:
			data["indices"].append(offset + index)

static func 생성(points: PackedVector2Array, others: Array[PackedVector2Array], origin: Vector2 = Vector2.ZERO) -> ArrayMesh:
	var p := 정리(points)
	var mesh := ArrayMesh.new()
	if p.size() < 3:
		return mesh
	# Dictionary 안의 Array를 쓴 뒤 마지막에 PackedArray로 변환한다(값 복사로 정점이 유실되는 것 방지).
	var data := {"vertices": [], "uvs": [], "indices": [], "origin": origin}
	# 왼 단면은 18px 폭의 독립된 면, 오른쪽은 8px 그늘. 상판 그림을 돌려 쓰지 않는다.
	for i in p.size():
		var a := p[i]
		var b := p[(i+1)%p.size()]
		var t := (b-a).normalized()
		var n := Vector2(t.y,-t.x)
		var kind := 6 if n.y > 0.65 else (4 if n.x < 0.0 else 5)
		if n.y < -0.001 or (absf(n.x) < 0.90 and n.y < 0.65):
			continue
		for interval in 노출(a,b,others):
			var l := a.lerp(b,interval.x)
			var r := a.lerp(b,interval.y)
			var width := 3.0 if kind == 6 else (18.0 if kind == 4 else 8.0)
			면추가(data,PackedVector2Array([l,r,r-n*width,l-n*width]),p,others,a,b,kind)
	for i in p.size():
		var a := p[i]
		var b := p[(i+1)%p.size()]
		# 수평인 발판만 덮는다. 세로벽·모따기·깨진 단면에는 상판을 생성하지 않는다.
		if b.x-a.x < 12.0 or absf(b.y-a.y) > 0.01:
			continue
		var left_end := (a-p[(i-1+p.size())%p.size()]).cross(b-a) > 0.01
		var right_end := (b-a).cross(p[(i+2)%p.size()]-b) > 0.01
		# 같은 높이의 이웃에 붙은 끝은 단면이 아니다. 연결된 상판 안에 사선 틈이 생기지 않게 한다.
		for other in others:
			if Geometry2D.is_point_in_polygon(a+Vector2(-0.5,0.5),other):
				left_end = false
			if Geometry2D.is_point_in_polygon(b+Vector2(0.5,0.5),other):
				right_end = false
		for interval in 노출(a,b,others):
			var l := a.lerp(b,interval.x)
			var r := a.lerp(b,interval.y)
			if r.x-l.x < 12.0:
				continue
			# 왼 끝 단면 폭은 옆벽 단면(18px)과 같게 — 두 면이 한 장의 옆면으로 이어진다. 아주 짧은 발판만 줄인다.
			var li := minf(18.0,(r.x-l.x)*0.375) if left_end and interval.x < 0.0001 else 0.0
			# 판자 맞춤: 이 구간에 들어갈 판자 수 n 과 폭 w. 뒤 왼쪽 모서리(l)와 뒤 오른쪽 모서리(r)가 이음새.
			var run_n := maxi(1, roundi((r.x-l.x)/64.0))
			var run_w := (r.x-l.x)/float(run_n)
			# 투영은 왼 단면 방향으로 통일한다. 오른 위를 깎으면 본체가 검은 삼각형으로 노출된다.
			var ri := 0.0
			# 22px 윗면 + 8px 앞 단면. 볼록 끝은 사다리꼴 상판과 작은 나무 단면으로 닫는다.
			if li > 0.0:
				# [2026-10-05 Claude] 끝 단면을 옆면(kind 4)과 같은 좌표로 그린다 — 사선 윗변이 상판 첫 이음새와 겹치고,
				#   아래로는 왼 벽 단면과 한 면으로 이어진다. 기준선 = 이 끝의 세로선(아래→위, 안쪽 = +x).
				var ea := l + Vector2(0.0, 40.0)
				var eb := l
				var end := PackedVector2Array([l+Vector2(0,-4),l+Vector2(li,18),l+Vector2(li,26),l+Vector2(0,4)])
				면추가(data,end,p,others,ea,eb,4)
				면추가(data,end,p,others,ea,eb,4,false)
			if ri > 0.0:
				var end := PackedVector2Array([r-Vector2(ri,4),r+Vector2(0,18),r+Vector2(0,26),r+Vector2(-ri,4)])
				면추가(data,end,p,others,a,b,3)
				면추가(data,end,p,others,a,b,3,false)
			var top := PackedVector2Array([l+Vector2(0,-4),r+Vector2(-ri,-4),r+Vector2(0,18),l+Vector2(li,18)])
			면추가(data,top,p,others,a,b,0,true,l.x,run_w)
			면추가(data,top,p,others,a,b,0,false,l.x,run_w)
			var front := PackedVector2Array([l+Vector2(li,18),r+Vector2(0,18),r+Vector2(0,26),l+Vector2(li,26)])
			면추가(data,front,p,others,a,b,0,true,l.x,run_w)
			if right_end and interval.y > 0.9999:
				# 오른 끝 마감선: 상판·앞 단면 끝을 3px 어두운 세로 띠로 닫는다(투영상 오른 옆면은 가려진다).
				var cap := PackedVector2Array([r+Vector2(-3,-4),r+Vector2(0,-4),r+Vector2(0,26),r+Vector2(-3,26)])
				면추가(data,cap,p,others,r,r+Vector2(0,40),7)
				면추가(data,cap,p,others,r,r+Vector2(0,40),7,false)
	if data["vertices"].is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array(data["vertices"])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(data["uvs"])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(data["indices"])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
