@tool
extends "res://scripts/스마트월드/하수도_자연발판.gd"
## 내부 장식 전용. 외곽 접촉선에는 무늬를 배치하지 않는다.
@export var 내부_바탕흰색: bool = false
@export var 내부_벽돌영역: Array[Rect2] = []

func 기본_아트색() -> int:
	# 시작상태는 무색(페인트 시드 없음)이지만 바탕은 실제 흑백 지형이다.
	if 칠하기_방식 == 칠방식.안칠해짐 or not 안칠한_바탕도_색이다:
		return -1
	return ColorDefs.WHITE if 내부_바탕흰색 else ColorDefs.BLACK

func _셰이더_만들기(source: Texture2D, quiet: bool = false, edge: bool = false) -> ShaderMaterial:
	var result := super._셰이더_만들기(source, quiet, edge)
	if result != null:
		# 기존 물감 처리보다 먼저 바탕만 뒤집어야 색칠·회수와 충돌하지 않는다.
		var rectangles := PackedVector4Array()
		for area in 내부_벽돌영역.slice(0, 16):
			rectangles.append(Vector4(area.position.x, area.position.y, area.end.x, area.end.y))
		result.set_shader_parameter("inlay_count", rectangles.size())
		rectangles.resize(16)
		result.set_shader_parameter("inlay_rects", rectangles)
	return result
