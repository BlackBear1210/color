@tool
extends RefCounted
## 챕터1의 기하만 재사용한다. 앞면 UV·흑백 돌 재질·페인트 좌표는 하수도 그대로다.
const 투영 = preload("res://scripts/스마트월드/목재_상판메시.gd")

static func 윤곽(points: PackedVector2Array) -> PackedVector2Array:
	# 기존 돌의 4~5px 모따기를 큰 투영 사선과 겹쳐 쓰면 윗면/옆면 접합이 어긋난다.
	# 그림용 사본에서 작은 직각 모따기만 펴고, 이후 챕터1의 사선 절단을 적용한다.
	var p := 투영.정리(points)
	var changed := true
	while changed and p.size() > 3:
		changed = false
		for i in p.size():
			var j := (i + 1) % p.size()
			var a := p[i]
			var b := p[j]
			var v := b - a
			if absf(v.x) < 0.01 or absf(v.y) < 0.01 or absf(v.x) > 8.0 or absf(v.y) > 8.0:
				continue
			var before := a - p[(i - 1 + p.size()) % p.size()]
			var after := p[(i + 2) % p.size()] - b
			if absf(before.y) < 0.01 and absf(after.x) < 0.01:
				p[i] = Vector2(b.x, a.y)
			elif absf(before.x) < 0.01 and absf(after.y) < 0.01:
				p[i] = Vector2(a.x, b.y)
			else:
				continue
			p.remove_at(j)
			changed = true
			break
	return p

static func 이웃(terrain, points: PackedVector2Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if points.is_empty() or terrain.get_parent() == null:
		return result
	var bounds := Rect2(points[0], Vector2.ZERO)
	for p in points:
		bounds = bounds.expand(p)
	for node in terrain.get_parent().get_children():
		if node == terrain or not node is Node2D or not node.has_method("get_point_array") or not node.is_visible_in_tree():
			continue
		var array: Resource = node.call("get_point_array")
		if array == null:
			continue
		var polygon := PackedVector2Array()
		for p in array.call("get_tessellated_points"):
			polygon.append(terrain.to_local(node.to_global(p)))
		if polygon.size() < 3:
			continue
		var other_bounds := Rect2(polygon[0], Vector2.ZERO)
		for p in polygon:
			other_bounds = other_bounds.expand(p)
		if bounds.grow(30.0).intersects(other_bounds, true):
			result.append(윤곽(polygon))
	return result

static func 생성(terrain, points: PackedVector2Array, others: Array[PackedVector2Array], top: bool, side: bool, submerged: Array[PackedVector2Array]) -> Array[MeshInstance2D]:
	var result: Array[MeshInstance2D] = []
	if terrain.shape_material == null or terrain.shape_material.fill_textures.is_empty():
		return result
	# 본체와 덮개가 동일한 그림용 윤곽으로 만난다. 원본 점/충돌은 변경하지 않는다.
	var visual_others: Array[PackedVector2Array] = []
	for other in others:
		visual_others.append(윤곽(other))
	var source := 투영.생성(윤곽(points), visual_others, terrain.global_position,
		{"top": top, "side": side, "bottom": false, "tile_width": 198.0 * 0.2353, "submerged": submerged})
	if source.get_surface_count() == 0:
		return result
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector2Array = arrays[Mesh.ARRAY_VERTEX]
	var projected_uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uv_bounds := Rect2(projected_uv[0], Vector2.ZERO)
	for uv in projected_uv:
		uv_bounds = uv_bounds.expand(uv)
	var span := Vector2(maxf(uv_bounds.size.x, 0.001), maxf(uv_bounds.size.y, 0.001))
	for i in colors.size():
		# 색 채널에는 투영 UV만 정규화해 넣는다. 실제 돌/유령 텍스처 UV는 기존 계산을 유지한다.
		var packed := (projected_uv[i] - uv_bounds.position) / span
		colors[i] = Color(packed.x, colors[i].g, packed.y, 1.0)
	var texture: Texture2D = terrain.shape_material.fill_textures[0]
	arrays[Mesh.ARRAY_TEX_UV] = terrain._get_uv_points(vertices, terrain.shape_material, texture.get_size())
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance2D.new()
	instance.name = "_CachedTrim_Chapter1"
	instance.mesh = mesh
	instance.texture = texture
	instance.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var body: ShaderMaterial = terrain.shape_material.fill_mesh_material as ShaderMaterial
	var material: ShaderMaterial
	if body != null:
		material = body.duplicate() as ShaderMaterial
	else:
		material = terrain._셰이더_만들기(texture, true, false)
	material.shader = terrain.자연면_셰이더
	# 기존 돌 색/페인트/명도 유니폼을 복제하고 투영 마감만 선택한다.
	material.set_shader_parameter("chapter_trim", true)
	material.set_shader_parameter("chapter_uv_bounds", Vector4(uv_bounds.position.x, uv_bounds.position.y, uv_bounds.position.x + span.x, uv_bounds.position.y + span.y))
	material.set_shader_parameter("cached_draw_mode", 2)
	material.set_shader_parameter("ground_edge_count", 0)
	material.set_shader_parameter("ground_cover_count", 0)
	material.set_shader_parameter("ground_cap_tex", terrain.상면_그림)
	# 사각형 전체용 셰이더에서 물려받은 외곽 명암은 투영된 면 자체의 명암과 중복하지 않는다.
	material.set_shader_parameter("ground_platform", true)
	instance.material = material
	result.append(instance)
	return result
