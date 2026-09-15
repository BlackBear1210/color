@tool
extends "res://scripts/스마트월드/하수도_벽돌지형.gd"

const 자연면_셰이더 = preload("res://shaders/sewer_natural_platform.gdshader")
const 선반_셰이더 = preload("res://shaders/sewer_ledge_v03.gdshader")
const 상면_그림 = preload("res://assets/textures/smartshape/sewer_ledge_v03/black/fill.png")

## 공중 선반은 벽 반복 대신 끝돌을 보존하는 전용 UV를 사용한다.
@export var 석조선반: bool = false

## 땅은 아래로 이어지는 덩어리이므로 공중 발판의 하단 음영을 표시하지 않는다.
@export var 땅지형: bool = false

func _셰이더_만들기(source: Texture2D, quiet: bool = false, edge: bool = false) -> ShaderMaterial:
	var result := super._셰이더_만들기(source, quiet, edge)
	if result != null:
		# 페인트 유니폼은 부모가 준비하고 외곽 명암만 비교판 전용 셰이더로 바꾼다.
		result.shader = 선반_셰이더 if 석조선반 else 자연면_셰이더
		result.set_shader_parameter("ground_platform", 땅지형)
		var polygon := get_collision_polygon_node()
		if polygon != null and not polygon.polygon.is_empty():
			var bounds := Rect2(polygon.polygon[0], Vector2.ZERO)
			for point in polygon.polygon:
				bounds = bounds.expand(point)
			# 길이를 점으로 바꿔도 오른쪽 옆면이 새 끝을 따라가게 한다.
			result.set_shader_parameter("surface_bounds", Vector4(bounds.position.x, bounds.position.y, bounds.end.x, bounds.end.y))
			if 땅지형 and not 석조선반:
				# 사각 경계가 아니라 실제 계단/경사 외곽을 보내 각 윗면에 돌 마감을 붙인다.
				var edges: Array[Vector4] = []
				var points := polygon.polygon
				for i in mini(points.size(), 64):
					var a := points[i]
					var b := points[(i + 1) % points.size()]
					edges.append(Vector4(a.x, a.y, b.x, b.y))
				result.set_shader_parameter("ground_edges", edges)
				result.set_shader_parameter("ground_edge_count", edges.size())
				result.set_shader_parameter("ground_cap_tex", 상면_그림)
	return result
