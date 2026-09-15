@tool
extends "res://scripts/스마트월드/지형.gd"
const SEWER_SHADER = preload("res://shaders/하수도_벽돌_페인트.gdshader")
@export_range(0.0, 0.2, 0.01) var 근접반사_세기: float = 0.10
@export_range(80.0, 350.0, 10.0) var 근접반사_반경: float = 190.0
## 아틀라스의 잘린 영역을 실제 텍스처로 풀어야 페인트 셰이더의 UV와 흑백 짝이 일치한다.
## 공용 지형 규칙은 그대로 상속하고 이 재질의 아틀라스 준비만 담당한다.

func _영역_텍스처(source: Texture2D) -> Texture2D:
	if not source is AtlasTexture:
		return source
	var img := source.get_image()
	if img == null:
		return source
	var result := ImageTexture.create_from_image(img)
	result.set_meta("sewer_source", source.resource_path)
	return result

func _셰이더_설치() -> void:
	if shape_material == null:
		return
	# 공유 재질과 다른 인스턴스에 칠한 내용이 전파되지 않도록 먼저 복제한다.
	var original_shape = shape_material
	shape_material = original_shape.duplicate(true)
	for i in shape_material.fill_textures.size():
		shape_material.fill_textures[i] = _영역_텍스처(original_shape.fill_textures[i])
	var metas = shape_material.get_all_edge_meta_materials()
	var originals = original_shape.get_all_edge_meta_materials()
	for index in metas.size():
		var meta = metas[index]
		if meta == null or meta.edge_material == null:
			continue
		var edge = meta.edge_material
		# 외관 시험의 고정 명암 셰이더가 모서리의 페인트 셰이더를 가리지 않게 한다.
		edge.material = null
		for field in ["textures", "textures_corner_outer", "textures_corner_inner", "textures_taper_left", "textures_taper_right"]:
			var values = edge.get(field)
			for i in values.size():
				# 복제 리소스의 경로 유무에 의존하지 않고 원본에서 짝 찾기 정보를 읽는다.
				values[i] = _영역_텍스처(originals[index].edge_material.get(field)[i])
			edge.set(field, values)
	super._셰이더_설치()

func _짝_찾기(source: Texture2D) -> Dictionary:
	if not source.has_meta("sewer_source"):
		return super._짝_찾기(source)
	var original := str(source.get_meta("sewer_source"))
	var white := original.contains("/white/")
	var counterpart := original.replace("/white/", "/black/") if white else original.replace("/black/", "/white/")
	if counterpart == original or not ResourceLoader.exists(counterpart):
		return {"짝": null, "흰색이_기본": white}
	return {"짝": _영역_텍스처(load(counterpart) as Texture2D), "흰색이_기본": white}

func _셰이더_만들기(source: Texture2D, quiet: bool = false, edge: bool = false) -> ShaderMaterial:
	var result := super._셰이더_만들기(source, quiet, edge)
	if result != null:
		# 공통 색칠 셰이더와 같은 유니폼을 유지해 판정·회수 동작에 영향을 주지 않는다.
		result.shader = SEWER_SHADER
		# 검정 상면에 그려진 밝은 띠를 낮춰 원거리에서는 고정 흰 윤곽처럼 보이지 않게 한다.
		result.set_shader_parameter("sewer_trim", edge)
	return result

func _process(delta: float) -> void:
	super._process(delta)
	if Engine.is_editor_hint():
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var polygon := get_collision_polygon_node()
	if polygon == null:
		return
	var light := player.global_position + Vector2(0, -48)
	var segments: Array[Vector4] = []
	var visibility := PackedFloat32Array()
	var points := polygon.polygon
	for i in mini(points.size(), 32):
		var a := polygon.to_global(points[i])
		var b := polygon.to_global(points[(i+1) % points.size()])
		segments.append(Vector4(a.x,a.y,b.x,b.y))
		var target := Geometry2D.get_closest_point_to_segment(light,a,b)
		var normal := Vector2((b-a).y,-(b-a).x).normalized()
		var clear := 0.0
		if light.distance_to(target) < 근접반사_반경 and normal.dot(light-target) > 0:
			# 다른 벽 뒤쪽까지 선이 비치지 않도록 실제 지형으로 가려짐을 확인한다.
			var query := PhysicsRayQueryParameters2D.create(light,target+normal*2.0,1)
			if player is CollisionObject2D:
				query.exclude = [player.get_rid()]
			clear = 1.0 if get_world_2d().direct_space_state.intersect_ray(query).is_empty() else 0.0
		visibility.append(clear)
	for material in _셰이더들:
		material.set_shader_parameter("sewer_light",light)
		material.set_shader_parameter("sewer_radius",근접반사_반경)
		material.set_shader_parameter("sewer_strength",근접반사_세기)
		material.set_shader_parameter("sewer_edge_count",segments.size())
		material.set_shader_parameter("sewer_edges",segments)
		material.set_shader_parameter("sewer_visible",visibility)
