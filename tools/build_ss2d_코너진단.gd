extends SceneTree
## ============================================================================
## [2026-08-24 신규] 코너 쿼드 방향 진단 씬 빌더 (임시 진단용)
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/build_ss2d_코너진단.gd
## 결과:
##   scenes/smartshape_test/ss2d_코너진단.tscn
##
## ▣ 검증하려는 것 — "하이브리드" 구성이 성립하는가
##   grass_v4 는 상/하/좌/우 4방향 머티리얼을 쓰는데, 그 구성에서는
##   90도 꺾임이 항상 '서로 다른 엣지의 경계' 라서 코너 쿼드가 0개다 (실측).
##   반면 전방향(0~360) 머티리얼 1개는 도형 전체를 엣지 1개로 잡아 코너를 만든다 (실측).
##
##   그래서 5번째 메타 머티리얼을 얹는다:
##     normal_range 0~360 / 엣지 텍스처는 완전 투명 / use_corner_texture = true
##   -> 일반 엣지는 투명해서 안 보이고, 코너 쿼드만 얹힌다.
##   -> 4방향 텍스처는 그대로 살아 있다.
##   코드는 한 줄도 안 고친다.
##
## ▣ 동시에 코너 텍스처의 UV 방향도 읽는다.
##   코너 쿼드의 UV 는 항상 (0,0)(0,1)(1,1)(1,0) 고정이고 쿼드만 회전한다.
##   텍스처의 어느 모서리가 지형 바깥을 향하는지는 추측하지 말고 화면으로 확인한다.
## ============================================================================

const 셰이프_S := preload("res://addons/rmsmartshape/shapes/shape.gd")
const 저장경로 := "res://scenes/smartshape_test/ss2d_코너진단.tscn"

const T_TOP := "res://assets/textures/smartshape/grass_v4/black/grass_edge_top.png"
const T_LEFT := "res://assets/textures/smartshape/grass_v4/black/grass_edge_left.png"
const T_RIGHT := "res://assets/textures/smartshape/grass_v4/black/grass_edge_right.png"
const T_BOTTOM := "res://assets/textures/smartshape/grass_v4/black/grass_edge_bottom.png"
const T_FILL := "res://assets/textures/smartshape/grass_v4/black/grass_fill_detail.png"
const T_투명 := "res://assets/textures/smartshape/grass_v4/공용/투명_256.png"
const T_진단 := "res://assets/textures/smartshape/grass_v4/공용/코너디버그_256.png"

const 배율 := 0.35

var _root: Node2D


func _init() -> void:
	call_deferred("_실행")


func _엣지(tex_path: String, 중심: float, 폭: float) -> SS2D_Material_Edge_Metadata:
	var e := SS2D_Material_Edge.new()
	e.textures = [load(tex_path)] as Array[Texture2D]
	e.use_corner_texture = false
	e.use_taper_texture = false
	e.texture_scale = 배율
	var meta := SS2D_Material_Edge_Metadata.new()
	meta.edge_material = e
	meta.normal_range = SS2D_NormalRange.new(중심 - 폭 * 0.5, 폭)
	return meta


## ★코너 전용 메타. 일반 엣지는 투명, 코너 텍스처만 보인다.
func _코너전용(코너텍스: String, z: int) -> SS2D_Material_Edge_Metadata:
	var e := SS2D_Material_Edge.new()
	e.textures = [load(T_투명)] as Array[Texture2D]          # 안 보이는 캐리어
	e.textures_corner_outer = [load(코너텍스)] as Array[Texture2D]
	e.textures_corner_inner = [load(코너텍스)] as Array[Texture2D]
	e.use_corner_texture = true
	e.use_taper_texture = false
	e.texture_scale = 배율
	var meta := SS2D_Material_Edge_Metadata.new()
	meta.edge_material = e
	meta.normal_range = SS2D_NormalRange.new(0.0, 360.0)     # 도형 전체를 엣지 1개로
	meta.z_index = z                                          # 코너를 엣지 위로
	return meta


func _머티(코너텍스: String) -> SS2D_Material_Shape:
	var metas: Array[SS2D_Material_Edge_Metadata] = [
		_엣지(T_TOP, 90.0, 90.0),
		_엣지(T_LEFT, 180.0, 90.0),
		_엣지(T_BOTTOM, 270.0, 90.0),
		_엣지(T_RIGHT, 0.0, 90.0),
		_코너전용(코너텍스, 2),
	]
	var m := SS2D_Material_Shape.new()
	m.set_edge_meta_materials(metas)
	m.fill_textures = [load(T_FILL)] as Array[Texture2D]
	m.fill_texture_scale = 배율
	m.fill_texture_z_index = -1
	return m


func _도형(이름: String, 위치: Vector2, 점들: PackedVector2Array, 머티: SS2D_Material_Shape) -> Node2D:
	var s: Node2D = 셰이프_S.new()
	s.name = 이름
	s.position = 위치
	s.shape_material = 머티
	_root.add_child(s)
	s.owner = _root
	var pa: SS2D_Point_Array = s.get_point_array()
	pa.begin_update()
	pa.add_points(점들)
	pa.end_update()
	pa.close_shape()
	s.force_update()
	return s


func _라벨(위치: Vector2, 글: String) -> void:
	var l := Label.new()
	l.name = "라벨_%d_%d" % [int(위치.x), int(위치.y)]
	l.position = 위치
	l.text = 글
	l.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	l.add_theme_font_size_override("font_size", 40)
	_root.add_child(l)
	l.owner = _root


func _세기(s: Node2D) -> String:
	var o := 0
	var i := 0
	for e in s._edges:
		for q in e.quads:
			if q.corner == SS2D_Quad.CORNER.OUTER:
				o += 1
			elif q.corner == SS2D_Quad.CORNER.INNER:
				i += 1
	return "OUTER %d / INNER %d" % [o, i]


func _실행() -> void:
	_root = Node2D.new()
	_root.name = "ss2d_코너진단"
	# ★반드시 트리에 붙여야 한다. SS2D 의 force_update() 는 is_node_ready() 가 false 면
	# 아무것도 하지 않고 돌아간다 -> 메시도 코너도 안 생기고 개수 집계가 전부 0 이 된다.
	root.add_child(_root)

	var bg := ColorRect.new()
	bg.name = "배경"
	bg.position = Vector2(-400, -400)
	bg.size = Vector2(5200, 3000)
	bg.color = Color(0.66, 0.68, 0.71)
	bg.z_index = -100
	_root.add_child(bg)
	bg.owner = _root

	var 사각 := PackedVector2Array([
		Vector2(0, 0), Vector2(700, 0), Vector2(700, 700), Vector2(0, 700)])
	var L자 := PackedVector2Array([
		Vector2(0, 0), Vector2(900, 0), Vector2(900, 400),
		Vector2(400, 400), Vector2(400, 900), Vector2(0, 900)])

	_라벨(Vector2(0, -160), "진단 코너 텍스처 (좌상240·1점 / 우상180·2점 / 우하120·3점 / 좌하60·4점)")
	var a := _도형("진단_사각", Vector2(0, 0), 사각, _머티(T_진단))
	print("[진단] 사각 하이브리드: %s" % _세기(a))

	var b := _도형("진단_L자", Vector2(1200, 0), L자, _머티(T_진단))
	print("[진단] L자 하이브리드: %s" % _세기(b))

	_라벨(Vector2(2600, -160), "실제 grass 코너 텍스처")
	var c := _도형("실제_사각", Vector2(2600, 0), 사각, _머티(
		"res://assets/textures/smartshape/grass_v4/black/grass_corner_outer.png"))
	print("[진단] 사각 실제코너: %s" % _세기(c))

	var d := _도형("실제_L자", Vector2(3600, 0), L자, _머티(
		"res://assets/textures/smartshape/grass_v4/black/grass_corner_outer.png"))
	print("[진단] L자 실제코너: %s" % _세기(d))

	var cam := Camera2D.new()
	cam.name = "카메라"
	cam.position = Vector2(2300, 500)
	cam.zoom = Vector2(0.35, 0.35)
	_root.add_child(cam)
	cam.owner = _root

	var packed := PackedScene.new()
	if packed.pack(_root) != OK:
		push_error("pack 실패")
		quit(1)
		return
	if ResourceSaver.save(packed, 저장경로) != OK:
		push_error("저장 실패")
		quit(1)
		return
	print("[build] 저장: %s" % 저장경로)
	quit(0)
