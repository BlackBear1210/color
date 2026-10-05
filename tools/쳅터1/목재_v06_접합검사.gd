extends SceneTree
## 실제 메시 생성기로 사선 평행·네모 막음 재발·동일 높이 접합을 검사한다.
## 사용자에게 Godot 실행을 명시적으로 허용받은 뒤에만 실행한다.
const Deck = preload("res://scripts/스마트월드/목재_상판메시.gd")
var failures := 0

func _init() -> void:
	call_deferred("run")

func rect(w: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2.ZERO,Vector2(w,0),Vector2(w,96),Vector2(0,96)])

func expect(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func run() -> void:
	for width in [32.0,64.0,160.0,320.0]:
		var p := rect(width)
		var cuts := Deck.모서리절단(p,[])
		# [2026-10-06 Claude] 외딴 발판은 오른 위 + 왼 아래 두 모서리를 깎는다(뒷면이 왼 위로 밀린 투영).
		expect(cuts.size() == 2,"isolated corner cut (top-right + bottom-left)")
		# 앞면 채우기는 Clipper 대신 꼭짓점 옮기기 — 두 모서리 바깥 점이 윤곽 밖이어야 한다.
		var outline := Deck.깎은_윤곽(p,[])
		expect(not Geometry2D.is_point_in_polygon(Vector2(width-0.5,0.5),outline),"fill outline cut at top-right")
		if width >= 64.0:
			expect(not Geometry2D.is_point_in_polygon(Vector2(0.5,95.5),outline),"fill outline cut at bottom-left")
		var parts: Array[PackedVector2Array] = [p]
		parts = Deck.가림(parts,cuts)
		for part in parts:
			expect(not Geometry2D.is_point_in_polygon(Vector2(width-0.5,1),part),"no rectangular body behind slant")
		var mesh := Deck.생성(p,[])
		expect(mesh.get_surface_count() == 1,"nonempty cap")
		if mesh.get_surface_count() == 0:
			continue
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector2Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var shift := minf(18.0,width*0.375)
		var rear_left := false
		var rear_right := false
		var front_left := false
		var front_right := false
		for i in vertices.size():
			expect(floori(uv[i].y) != 5,"no upright closing post")
			if uv[i].y >= 2.0:
				continue
			rear_left = rear_left or vertices[i].is_equal_approx(Vector2(0,-4))
			rear_right = rear_right or vertices[i].is_equal_approx(Vector2(width-shift,-4))
			front_left = front_left or vertices[i].is_equal_approx(Vector2(shift,18))
			front_right = front_right or vertices[i].is_equal_approx(Vector2(width,18))
		expect(rear_left and rear_right and front_left and front_right,"parallel top depth edges")
	var neighbor := PackedVector2Array([Vector2(160,0),Vector2(320,0),Vector2(320,96),Vector2(160,96)])
	# 오른쪽에 같은 높이 이웃이 붙으면 오른 위는 깎지 않는다(왼 아래는 이웃과 떨어져 있어 그대로 깎는다).
	for cut in Deck.모서리절단(rect(160),[neighbor]):
		expect(not Geometry2D.is_point_in_polygon(Vector2(159.5,-1),cut),"joined boards have no top-right cut")
	# 낮은 왼 단에서 높은 오른 단으로 올라가는 안쪽 모서리는 사선으로 맞물려야 한다.
	var stair := PackedVector2Array([Vector2(0,64),Vector2(96,64),Vector2(96,0),Vector2(256,0),Vector2(256,192),Vector2(0,192)])
	var step_mesh := Deck.생성(stair,[])
	var step_arrays := step_mesh.surface_get_arrays(0)
	var step_vertices: PackedVector2Array = step_arrays[Mesh.ARRAY_VERTEX]
	expect(step_vertices.has(Vector2(114,82)),"concave tread reaches side-face front")
	print("wood v06 failures=",failures)
	quit(0 if failures == 0 else 1)
