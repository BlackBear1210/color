extends SceneTree
## 실제 덮개 생성기로 접합부를 검사한다. 면적과 삼각형 중심을 확인하여 빈 메시·이웃 침범을 잡는다.
const Deck = preload("res://scripts/스마트월드/목재_상판메시.gd")
var failures := 0
func _init() -> void:
	call_deferred("run")
func rect(x: float,y: float,w: float,h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x,y),Vector2(x+w,y),Vector2(x+w,y+h),Vector2(x,y+h)])
func check(label: String,p: PackedVector2Array,others: Array[PackedVector2Array]) -> void:
	var mesh := Deck.생성(p,others)
	if mesh.get_surface_count() != 1:
		failures += 1
		return
	var a := mesh.surface_get_arrays(0)
	var v: PackedVector2Array = a[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	for i in range(0,idx.size(),3):
		var center := (v[idx[i]]+v[idx[i+1]]+v[idx[i+2]])/3.0
		for other in others:
			if Geometry2D.is_point_in_polygon(center,other):
				failures += 1
	print(label," triangles=",idx.size()/3)
func run() -> void:
	check("isolated",rect(0,0,320,96),[])
	check("joined-left",rect(0,0,160,96),[rect(160,0,160,96)])
	check("joined-right",rect(160,0,160,96),[rect(0,0,160,96)])
	check("step",rect(0,0,160,192),[rect(160,96,160,96)])
	check("concave",PackedVector2Array([Vector2(0,0),Vector2(96,0),Vector2(96,64),Vector2(320,64),Vector2(320,192),Vector2(0,192)]),[])
	check("narrow",rect(0,0,32,32),[])
	print("FAILURES=",failures)
	quit(0 if failures == 0 else 1)
