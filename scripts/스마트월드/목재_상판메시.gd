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

static func 면추가(data: Dictionary, poly: PackedVector2Array, own: PackedVector2Array, others: Array[PackedVector2Array], a: Vector2, b: Vector2, kind: int, inside: bool = true) -> void:
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
			var uv := Vector2(p.x / 256.0, (p.y-a.y+4.0)/30.0)
			if kind == 2 or kind == 3:
				uv.y = float(kind) + clampf((p.y-a.y+4.0)/30.0, 0.0, 0.999)
			elif kind >= 4:
				var width := 3.0 if kind == 6 else 4.0
				uv = Vector2((p-a).dot((b-a).normalized())/32.0, float(kind)+clampf((p-a).dot(inward)/width, 0.0, 0.999))
			data["uvs"].append(uv)
		for index in triangles:
			data["indices"].append(offset + index)

static func 생성(points: PackedVector2Array, others: Array[PackedVector2Array]) -> ArrayMesh:
	var p := 정리(points)
	var mesh := ArrayMesh.new()
	if p.size() < 3:
		return mesh
	# Dictionary 안의 Array를 쓴 뒤 마지막에 PackedArray로 변환한다(값 복사로 정점이 유실되는 것 방지).
	var data := {"vertices": [], "uvs": [], "indices": []}
	# 옆면은 4px의 단면 음영, 아랫면은 3px의 그늘만. 윗면 그림을 돌려 쓰지 않는다.
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
			var width := 3.0 if kind == 6 else 4.0
			면추가(data,PackedVector2Array([l,r,r-n*width,l-n*width]),p,others,a,b,kind)
	for i in p.size():
		var a := p[i]
		var b := p[(i+1)%p.size()]
		# 수평인 발판만 덮는다. 세로벽·모따기·깨진 단면에는 상판을 생성하지 않는다.
		if b.x-a.x < 12.0 or absf(b.y-a.y) > 0.01:
			continue
		var left_end := (a-p[(i-1+p.size())%p.size()]).cross(b-a) > 0.01
		var right_end := (b-a).cross(p[(i+2)%p.size()]-b) > 0.01
		for interval in 노출(a,b,others):
			var l := a.lerp(b,interval.x)
			var r := a.lerp(b,interval.y)
			if r.x-l.x < 12.0:
				continue
			var li := minf(6.0,(r.x-l.x)*0.12) if left_end and interval.x < 0.0001 else 0.0
			var ri := minf(6.0,(r.x-l.x)*0.12) if right_end and interval.y > 0.9999 else 0.0
			# 22px 윗면 + 8px 앞 단면. 볼록 끝은 사다리꼴 상판과 작은 나무 단면으로 닫는다.
			if li > 0.0:
				var end := PackedVector2Array([l+Vector2(li,-4),l+Vector2(0,18),l+Vector2(0,26),l+Vector2(li,4)])
				면추가(data,end,p,others,a,b,2)
				면추가(data,end,p,others,a,b,2,false)
			if ri > 0.0:
				var end := PackedVector2Array([r-Vector2(ri,4),r+Vector2(0,18),r+Vector2(0,26),r+Vector2(-ri,4)])
				면추가(data,end,p,others,a,b,3)
				면추가(data,end,p,others,a,b,3,false)
			var top := PackedVector2Array([l+Vector2(li,-4),r+Vector2(-ri,-4),r+Vector2(0,18),l+Vector2(0,18)])
			면추가(data,top,p,others,a,b,0)
			면추가(data,top,p,others,a,b,0,false)
			var front := PackedVector2Array([l+Vector2(0,18),r+Vector2(0,18),r+Vector2(0,26),l+Vector2(0,26)])
			면추가(data,front,p,others,a,b,0)
	if data["vertices"].is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array(data["vertices"])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(data["uvs"])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(data["indices"])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
