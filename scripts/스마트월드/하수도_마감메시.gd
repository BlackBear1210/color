@tool
extends RefCounted
## 정적인 노출 경계를 CPU에서 한 번 잘라 좁은 마감 메시를 만든다.
## 충돌/SS2D 점은 바꾸지 않으며 모든 꼭짓점은 부모 지형의 로컬 좌표다.

static func _노출구간(a: Vector2, b: Vector2, others: Array[PackedVector2Array]) -> Array[Vector2]:
	var direction := b - a
	var length := direction.length()
	var tangent := direction / length
	var outward := Vector2(tangent.y, -tangent.x)
	var cuts: Array[float] = [0.0, 1.0]
	# 바깥 0.5px 선과 모든 이웃 변의 교차점을 기준으로 부분 접촉도 나눈다.
	var start := a + outward * 0.5
	var finish := b + outward * 0.5
	for polygon in others:
		for i in polygon.size():
			var hit: Variant = Geometry2D.segment_intersects_segment(start, finish, polygon[i], polygon[(i + 1) % polygon.size()])
			if hit != null:
				cuts.append(clampf((Vector2(hit) - start).dot(tangent) / length, 0.0, 1.0))
	cuts.sort()
	var result: Array[Vector2] = []
	for i in range(cuts.size() - 1):
		if cuts[i + 1] - cuts[i] < 0.00001:
			continue
		var midpoint := start.lerp(finish, (cuts[i] + cuts[i + 1]) * 0.5)
		var covered := false
		for polygon in others:
			if Geometry2D.is_point_in_polygon(midpoint, polygon):
				covered = true
				break
		if not covered:
			result.append(Vector2(cuts[i], cuts[i + 1]))
	return result

static func _자르기(parts: Array[PackedVector2Array], others: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	for polygon in others:
		var next: Array[PackedVector2Array] = []
		for part in parts:
			for clipped in Geometry2D.clip_polygons(part, polygon):
				# 좁은 띠의 차집합에 홀은 없어야 한다. 역방향 홀을 채우지 않는다.
				if not Geometry2D.is_polygon_clockwise(clipped):
					next.append(clipped)
		parts = next
	return parts

static func 생성(terrain, points: PackedVector2Array, others: Array[PackedVector2Array], top: bool, side: bool) -> Array[MeshInstance2D]:
	var result: Array[MeshInstance2D] = []
	if points.size() < 3 or terrain.shape_material == null or terrain.shape_material.fill_textures.is_empty():
		return result
	# 직선 중간의 편집 점 때문에 마감돌 반복이 재시작하지 않게 복사본만 정리한다.
	points = points.duplicate()
	var changed := true
	while changed and points.size() > 3:
		changed = false
		for index in points.size():
			var before := points[index] - points[(index - 1 + points.size()) % points.size()]
			var after := points[(index + 1) % points.size()] - points[index]
			if before.length_squared() < 0.0001 or (absf(before.cross(after)) < 0.001 and before.dot(after) > 0.0):
				points.remove_at(index)
				changed = true
				break
	if Geometry2D.is_polygon_clockwise(points):
		points.reverse()
	var texture: Texture2D = terrain.shape_material.fill_textures[0]
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var length := a.distance_to(b)
		if length < 0.01:
			continue
		var tangent := (b - a) / length
		var outward := Vector2(tangent.y, -tangent.x)
		var is_top := outward.y < -0.65 and top
		var is_side := absf(tangent.y) >= 0.95 and side
		if not is_top and not is_side:
			continue
		var exposed := _노출구간(a, b, others)
		if exposed.is_empty():
			continue
		var pieces: Array[PackedVector2Array] = []
		for interval in exposed:
			var left := a.lerp(b, interval.x)
			var right := a.lerp(b, interval.y)
			var depth := 24.0 if is_top else 18.0
			var strip := PackedVector2Array([left, right, right - outward * depth, left - outward * depth])
			# 안쪽 띠는 실제 지형으로 잘라 계단 바깥으로 튀어나오지 않게 한다.
			for clipped in Geometry2D.intersect_polygons(strip, points):
				pieces.append(clipped)
			if is_top:
				# 뒤쪽 모따기는 볼록한 끝에만 적용한다. 발밑 충돌선은 움직이지 않는다.
				var prev := (a - points[(i - 1 + points.size()) % points.size()]).normalized()
				var following := (points[(i + 2) % points.size()] - b).normalized()
				var li := minf(3.0, left.distance_to(right) * 0.2) if interval.x < 0.0001 and prev.cross(tangent) > 0.01 else 0.0
				var ri := minf(3.0, left.distance_to(right) * 0.2) if interval.y > 0.9999 and tangent.cross(following) > 0.01 else 0.0
				pieces.append(PackedVector2Array([left + outward * 4.0 + tangent * li, right + outward * 4.0 - tangent * ri, right, left]))
		pieces = _자르기(pieces, others)
		var vertices := PackedVector2Array()
		var indices := PackedInt32Array()
		for piece in pieces:
			var triangles := Geometry2D.triangulate_polygon(piece)
			if triangles.is_empty():
				continue
			var offset := vertices.size()
			vertices.append_array(piece)
			for index in triangles:
				indices.append(offset + index)
		if vertices.is_empty():
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_TEX_UV] = terrain._get_uv_points(vertices, terrain.shape_material, texture.get_size())
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var instance := MeshInstance2D.new()
		instance.name = "_CachedTrim_%d" % i
		instance.mesh = mesh
		instance.texture = texture
		instance.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		# 부모와 로컬 원점/UV를 공유하므로 물감 중심이 어긋나지 않는다.
		# 본체 재질 복제는 현재 흑백 짝/노멀 텍스처/연결 페인트 설정도 함께 보존한다.
		var body_material: ShaderMaterial = terrain.shape_material.fill_mesh_material as ShaderMaterial
		var trim_material: ShaderMaterial
		if body_material != null:
			trim_material = body_material.duplicate() as ShaderMaterial
		else:
			trim_material = terrain._셰이더_만들기(texture, true, false)
		trim_material.shader = terrain.자연면_셰이더
		trim_material.set_shader_parameter("ground_platform", true)
		trim_material.set_shader_parameter("cached_draw_mode", 2)
		trim_material.set_shader_parameter("ground_edges", [Vector4(a.x, a.y, b.x, b.y)])
		trim_material.set_shader_parameter("ground_edge_count", 1)
		trim_material.set_shader_parameter("ground_cover_count", 0)
		trim_material.set_shader_parameter("ground_top_enabled", is_top)
		trim_material.set_shader_parameter("ground_side_enabled", is_side)
		trim_material.set_shader_parameter("ground_cap_tex", terrain.상면_그림)
		instance.material = trim_material
		result.append(instance)
	return result
