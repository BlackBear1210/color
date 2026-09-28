extends Node2D
## draw 명령은 RID만 보관하므로 메시 리소스를 노드가 계속 소유해야 한다.
var _그림자메시: ArrayMesh
## 그림자는 지형 자식이므로 이동/숨김을 따라간다. 광선 검사나 매 프레임 처리는 없다.
func _ready() -> void:
	z_as_relative = false
	z_index = -90
	var 고정명도 := CanvasItemMaterial.new()
	고정명도.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = 고정명도
	if get_parent().has_signal("points_modified"):
		get_parent().connect("points_modified", queue_redraw)
	queue_redraw()

func _draw() -> void:
	var 지형 := get_parent()
	if not 지형.has_method("get_point_array"):
		return
	var 원본: PackedVector2Array = 지형.get_point_array().get_tessellated_points()
	if 원본.size() > 1 and 원본[0].is_equal_approx(원본[-1]):
		원본.remove_at(원본.size() - 1)
	if 원본.size() < 3:
		return
	if Geometry2D.is_polygon_clockwise(원본):
		원본.reverse()
	var 꼭짓점 := PackedVector2Array()
	var 색들 := PackedColorArray()
	var 인덱스 := PackedInt32Array()
	var 이동 := Vector2(10, 12)
	# 지형 뒤에 가려지는 넓은 내부를 그리지 않는다. 외곽 띠를 하나의 메시로 합친다.
	for i in 원본.size():
		var a := 원본[i]
		var b := 원본[(i + 1) % 원본.size()]
		var 변 := b - a
		if Vector2(변.y, -변.x).dot(이동) <= 0.0:
			continue
		var 시작 := 꼭짓점.size()
		꼭짓점.append_array(PackedVector2Array([a, b, b + 이동, a + 이동]))
		색들.append_array(PackedColorArray([Color(0, 0, 0, 0.16), Color(0, 0, 0, 0.16), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
		인덱스.append_array(PackedInt32Array([시작, 시작 + 1, 시작 + 2, 시작, 시작 + 2, 시작 + 3]))
	if 꼭짓점.is_empty():
		return
	var 배열: Array = []
	배열.resize(Mesh.ARRAY_MAX)
	배열[Mesh.ARRAY_VERTEX] = 꼭짓점
	배열[Mesh.ARRAY_COLOR] = 색들
	배열[Mesh.ARRAY_INDEX] = 인덱스
	_그림자메시 = ArrayMesh.new()
	_그림자메시.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, 배열)
	draw_mesh(_그림자메시, null)
