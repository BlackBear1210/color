extends SceneTree
## ============================================================================
## [2026-08-24 신규] SS2D 코너 쿼드가 "언제" 생성되는지 실측하는 진단 도구
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/test_ss2d_코너생성.gd
##
## ▣ 왜 필요한가
##   grass_v4 는 상/하/좌/우 4방향 normal_range 를 쓰는데,
##   이 구성에서는 코너 쿼드가 단 하나도 생성되지 않는다 (이미 실측함).
##   "코너 타일을 45/90/135 도로 세분화해서 만들자" 는 계획이 성립하려면
##   먼저 SS2D 가 어떤 조건에서 코너 쿼드를 만드는지 확정해야 한다.
##
##   코너는 shape.gd 의 _build_edge_with_material() 안,
##   "하나의 엣지 머티리얼이 담당하는 점 나열" 을 도는 루프에서만 생성된다.
##   따라서 방향이 꺾이는 지점이 서로 다른 머티리얼의 경계면 코너가 안 생긴다.
##   이 가설을 여러 구성으로 검증한다.
## ============================================================================

const 셰이프_S := preload("res://addons/rmsmartshape/shapes/shape.gd")
const TEX := "res://assets/textures/smartshape/grass_v4/black/grass_edge_top.png"
## [2026-08-30] grass_corner_top.png 은 없다. grass_v4 는 코너를 inner/outer 두 장으로 굽는다.
const TEX_CORNER := "res://assets/textures/smartshape/grass_v4/black/grass_corner_outer.png"


func _init() -> void:
	call_deferred("_실행")


## 전방향(0~360) 머티리얼 하나. 코너 텍스처 켬.
func _머티_단일(코너: bool) -> SS2D_Material_Shape:
	var e := SS2D_Material_Edge.new()
	e.textures = [load(TEX)] as Array[Texture2D]
	e.textures_corner_outer = [load(TEX_CORNER)] as Array[Texture2D]
	e.textures_corner_inner = [load(TEX_CORNER)] as Array[Texture2D]
	e.use_corner_texture = 코너
	e.use_taper_texture = false
	e.texture_scale = 0.35
	var meta := SS2D_Material_Edge_Metadata.new()
	meta.edge_material = e
	meta.normal_range = SS2D_NormalRange.new(0.0, 360.0)
	var m := SS2D_Material_Shape.new()
	m.set_edge_meta_materials([meta] as Array[SS2D_Material_Edge_Metadata])
	return m


## 4방향 머티리얼. 각 범위의 폭(distance)을 인자로 받아 넓히거나 좁힐 수 있다.
## 폭을 90 보다 크게 하면 범위가 서로 겹쳐서, 꺾이는 지점이 같은 머티리얼 안에 들어올 수 있다.
func _머티_4방향(폭: float, 코너: bool) -> SS2D_Material_Shape:
	var metas: Array[SS2D_Material_Edge_Metadata] = []
	# 중심각: TOP 90, LEFT 180, BOTTOM 270, RIGHT 0
	for 중심 in [90.0, 180.0, 270.0, 0.0]:
		var e := SS2D_Material_Edge.new()
		e.textures = [load(TEX)] as Array[Texture2D]
		e.textures_corner_outer = [load(TEX_CORNER)] as Array[Texture2D]
		e.textures_corner_inner = [load(TEX_CORNER)] as Array[Texture2D]
		e.use_corner_texture = 코너
		e.use_taper_texture = false
		e.texture_scale = 0.35
		var meta := SS2D_Material_Edge_Metadata.new()
		meta.edge_material = e
		meta.normal_range = SS2D_NormalRange.new(중심 - 폭 * 0.5, 폭)
		metas.push_back(meta)
	var m := SS2D_Material_Shape.new()
	m.set_edge_meta_materials(metas)
	return m


func _사각(변: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, 0), Vector2(변, 0), Vector2(변, 변), Vector2(0, 변)])


## 모서리를 45도로 잘라낸(모따기) 사각형. 꺾임이 90도 한 번 -> 45도 두 번으로 나뉜다.
func _모따기사각(변: float, 컷: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(컷, 0), Vector2(변 - 컷, 0),
		Vector2(변, 컷), Vector2(변, 변 - 컷),
		Vector2(변 - 컷, 변), Vector2(컷, 변),
		Vector2(0, 변 - 컷), Vector2(0, 컷)])


func _셰이프(머티: SS2D_Material_Shape, 점들: PackedVector2Array, 둥글기: float = 0.0) -> Node2D:
	var s: Node2D = 셰이프_S.new()
	s.shape_material = 머티
	root.add_child(s)
	var pa: SS2D_Point_Array = s.get_point_array()
	pa.begin_update()
	pa.add_points(점들)
	pa.end_update()
	pa.close_shape()

	# 둥글기 > 0 이면 각 점에 베지어 제어점을 넣어 모서리를 곡선으로 만든다.
	# SS2D 는 곡선을 잘게 테셀레이션하므로, 법선이 서서히 회전하며
	# 여러 개의 작은 선분으로 나뉜다.
	if 둥글기 > 0.0:
		var keys := pa.get_all_point_keys()
		var n := keys.size()
		for i in n:
			var 이전: Vector2 = pa.get_point_position(keys[(i - 1 + n) % n])
			var 현재: Vector2 = pa.get_point_position(keys[i])
			var 다음: Vector2 = pa.get_point_position(keys[(i + 1) % n])
			pa.set_point_in(keys[i], (이전 - 현재).normalized() * 둥글기)
			pa.set_point_out(keys[i], (다음 - 현재).normalized() * 둥글기)

	s.force_update()
	return s


func _세기(s: Node2D) -> Dictionary:
	var outer := 0
	var inner := 0
	var 일반 := 0
	for e in s._edges:
		for q in e.quads:
			if q.corner == SS2D_Quad.CORNER.OUTER:
				outer += 1
			elif q.corner == SS2D_Quad.CORNER.INNER:
				inner += 1
			else:
				일반 += 1
	return {"outer": outer, "inner": inner, "일반": 일반,
			"엣지수": s._edges.size(), "메시수": s._meshes.size()}


func _보고(이름: String, s: Node2D) -> void:
	var r := _세기(s)
	print("  %-42s  OUTER %2d / INNER %2d   (엣지 %d, 일반쿼드 %3d, 메시 %d)"
		% [이름, r["outer"], r["inner"], r["엣지수"], r["일반"], r["메시수"]])
	s.queue_free()


func _실행() -> void:
	print("\n=== SS2D 코너 쿼드 생성 조건 실측 ===\n")

	print("[1] 하드 90도 사각형 (600px)")
	_보고("전방향 0~360 머티리얼 1개", _셰이프(_머티_단일(true), _사각(600)))
	_보고("4방향 폭 90 (현재 grass_v4 구성)", _셰이프(_머티_4방향(90.0, true), _사각(600)))
	_보고("4방향 폭 150 (범위 겹침)", _셰이프(_머티_4방향(150.0, true), _사각(600)))
	_보고("4방향 폭 200 (많이 겹침)", _셰이프(_머티_4방향(200.0, true), _사각(600)))

	print("\n[2] 45도 모따기 사각형 (600px, 컷 120px)")
	_보고("전방향 0~360", _셰이프(_머티_단일(true), _모따기사각(600, 120)))
	_보고("4방향 폭 90", _셰이프(_머티_4방향(90.0, true), _모따기사각(600, 120)))
	_보고("4방향 폭 150", _셰이프(_머티_4방향(150.0, true), _모따기사각(600, 120)))

	print("\n[3] 베지어로 둥글린 사각형 (600px, 둥글기 150)")
	_보고("전방향 0~360", _셰이프(_머티_단일(true), _사각(600), 150.0))
	_보고("4방향 폭 90", _셰이프(_머티_4방향(90.0, true), _사각(600), 150.0))
	_보고("4방향 폭 150", _셰이프(_머티_4방향(150.0, true), _사각(600), 150.0))

	print("\n[4] 오목(내부) 코너 — L자")
	var L := PackedVector2Array([
		Vector2(0, 0), Vector2(800, 0), Vector2(800, 350),
		Vector2(350, 350), Vector2(350, 800), Vector2(0, 800)])
	_보고("전방향 0~360", _셰이프(_머티_단일(true), L))
	_보고("4방향 폭 90", _셰이프(_머티_4방향(90.0, true), L))
	_보고("4방향 폭 150", _셰이프(_머티_4방향(150.0, true), L))

	print("\n[5] use_corner_texture = false 대조군")
	_보고("전방향 0~360, 코너 끔", _셰이프(_머티_단일(false), _사각(600)))

	print("\n끝")
	quit(0)
