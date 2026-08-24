extends SceneTree
## ============================================================================
## [2026-08-24 신규] grass_v4 최종 시각 품질 검증 씬 빌더
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/build_grass_v4_최종검증.gd
## 결과:
##   scenes/smartshape_test/grass_v4_최종검증.tscn   (신규)
##
## ▣ 확정된 값 (실측으로 정한 것)
##   texture_scale      0.35   -> 띠 90px / 잔디 술 33px / 반복 주기 358px
##   fill_texture_scale 0.35   -> 붓자국 크기가 엣지와 일치
##   대비 감마          1.60   -> BLACK 평균 31 / WHITE 평균 224
##
## ▣ 구성
##   4개 머티리얼(black solid/detail, white solid/detail) x 도형 9종.
##   검정 테마는 밝은 배경 위에, 흰색 테마는 어두운 배경 위에 놓아 실루엣을 본다.
##   각 행 왼쪽에 플레이어 크기(55x264) 실루엣을 놓아 스케일 기준을 준다.
## ============================================================================

const 셰이프_S := preload("res://addons/rmsmartshape/shapes/shape.gd")
const 저장경로 := "res://scenes/smartshape_test/grass_v4_최종검증.tscn"
const 머티폴더 := "res://assets/textures/smartshape/grass_v4/tres/"

const 행간격 := 1400.0
const 여백 := 300.0

var _root: Node2D


func _init() -> void:
	call_deferred("_실행")


func _사각(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)])


func _언덕(반지름: float, 밑변: float, 분할: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 분할 + 1:
		var ang: float = PI - (float(i) / float(분할)) * PI
		pts.push_back(Vector2(반지름 + cos(ang) * 반지름, 반지름 - sin(ang) * 반지름))
	pts.push_back(Vector2(반지름 * 2.0, 반지름 + 밑변))
	pts.push_back(Vector2(0, 반지름 + 밑변))
	return pts


func _원(반지름: float, 분할: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 분할:
		var ang: float = -PI * 0.5 + TAU * float(i) / float(분할)
		pts.push_back(Vector2(반지름 + cos(ang) * 반지름, 반지름 + sin(ang) * 반지름))
	return pts


func _ㄷ자(w: float, h: float, 두께: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, 0), Vector2(w, 0), Vector2(w, 두께),
		Vector2(두께, 두께), Vector2(두께, h - 두께),
		Vector2(w, h - 두께), Vector2(w, h), Vector2(0, h)])


func _L자(w: float, h: float, 두께: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, 0), Vector2(w, 0), Vector2(w, 두께),
		Vector2(두께, 두께), Vector2(두께, h), Vector2(0, h)])


## 볼록 코너 전용 — 뾰족한 90도 볼록 모서리 4개가 확실히 보이는 십자.
func _십자(팔: float, 두께: float) -> PackedVector2Array:
	var a := 팔
	var t := 두께
	var o: float = (a - t) * 0.5
	return PackedVector2Array([
		Vector2(o, 0), Vector2(o + t, 0), Vector2(o + t, o),
		Vector2(a, o), Vector2(a, o + t), Vector2(o + t, o + t),
		Vector2(o + t, a), Vector2(o, a), Vector2(o, o + t),
		Vector2(0, o + t), Vector2(0, o), Vector2(o, o)])


func _복합(s: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.00 * s, 0.28 * s), Vector2(0.30 * s, 0.00 * s),
		Vector2(0.55 * s, 0.18 * s), Vector2(0.72 * s, 0.05 * s),
		Vector2(1.00 * s, 0.34 * s), Vector2(0.86 * s, 0.62 * s),
		Vector2(0.95 * s, 0.86 * s), Vector2(0.58 * s, 0.98 * s),
		Vector2(0.34 * s, 0.80 * s), Vector2(0.12 * s, 0.92 * s)])


func _도형(이름: String, 위치: Vector2, 점들: PackedVector2Array, 머티: SS2D_Material_Shape) -> void:
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
	# set_as_dirty() 는 call_deferred 라 이 자리에서 바로 메시가 안 생긴다.
	# 아래에서 코너 쿼드를 세려면 지금 강제로 구워야 한다.
	s.force_update()


func _라벨(위치: Vector2, 글: String, 크기: int, 색: Color) -> void:
	var l := Label.new()
	l.name = "L_%d_%d" % [int(위치.x), int(위치.y)]
	l.position = 위치
	l.text = 글
	l.add_theme_color_override("font_color", 색)
	l.add_theme_font_size_override("font_size", 크기)
	_root.add_child(l)
	l.owner = _root


func _배경(y: float, 색: Color, 이름: String) -> void:
	var r := ColorRect.new()
	r.name = 이름
	r.position = Vector2(-520, y - 330)
	r.size = Vector2(11500, 행간격)
	r.color = 색
	r.z_index = -100
	_root.add_child(r)
	r.owner = _root


func _플레이어(위치: Vector2, 색: Color) -> void:
	var r := ColorRect.new()
	r.name = "player_%d" % int(위치.y)
	r.position = 위치
	r.size = Vector2(55, 264)
	r.color = 색
	r.z_index = 50
	_root.add_child(r)
	r.owner = _root


func _실행() -> void:
	_root = Node2D.new()
	_root.name = "grass_v4_최종검증"
	root.add_child(_root)   # force_update() 는 트리에 없으면 아무것도 안 한다

	var 도형표 := [
		["1 직선", _사각(1500, 230), 1500.0],
		["2 사각형", _사각(560, 560), 560.0],
		["3 둥근형태", _원(300, 28), 600.0],
		["4 L자", _L자(700, 700, 260), 700.0],
		["5 오목코너", _ㄷ자(700, 700, 250), 700.0],
		["6 볼록코너", _십자(700, 260), 700.0],
		["7 작은곡선", _원(150, 16), 300.0],
		["8 큰곡선", _언덕(520, 180, 24), 1040.0],
		["9 복합폐곡선", _복합(760), 760.0],
	]

	var 변형 := [
		["black_solid", Color(0.66, 0.68, 0.71), Color(0.10, 0.10, 0.12), Color(0.85, 0.2, 0.2, 0.9)],
		["black_detail", Color(0.66, 0.68, 0.71), Color(0.10, 0.10, 0.12), Color(0.85, 0.2, 0.2, 0.9)],
		["white_solid", Color(0.09, 0.10, 0.12), Color(0.88, 0.88, 0.90), Color(0.95, 0.35, 0.35, 0.9)],
		["white_detail", Color(0.09, 0.10, 0.12), Color(0.88, 0.88, 0.90), Color(0.95, 0.35, 0.35, 0.9)],
	]

	for r in 변형.size():
		var 이름: String = 변형[r][0]
		var 머티: SS2D_Material_Shape = load(머티폴더 + "지형_잔디_v4_%s.tres" % 이름)
		if 머티 == null:
			push_error("머티리얼 없음: %s" % 이름)
			quit(1)
			return
		var y: float = r * 행간격
		_배경(y, 변형[r][1], "bg_" + 이름)

		var 배율: float = 머티.get_all_edge_meta_materials()[0].edge_material.texture_scale
		_라벨(Vector2(-500, y - 300),
			"%s   texture_scale %.2f   띠 %.0fpx   잔디술 %.0fpx   주기 %.0fpx"
			% [이름, 배율, 256.0 * 배율, 256.0 * 배율 * 0.367, 1024.0 * 배율],
			44, 변형[r][2])
		_플레이어(Vector2(-360, y), 변형[r][3])

		var x := 0.0
		for 항목 in 도형표:
			_도형("%s_%s" % [이름, 항목[0]], Vector2(x, y), 항목[1], 머티)
			if r == 0:
				_라벨(Vector2(x, y - 190), 항목[0], 36, Color(0.25, 0.25, 0.28))
			x += 항목[2] + 여백

	var cam := Camera2D.new()
	cam.name = "카메라"
	cam.position = Vector2(4400, 변형.size() * 행간격 * 0.5 - 300)
	cam.zoom = Vector2(0.13, 0.13)
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
	print("[build] 머티 %d x 도형 %d" % [변형.size(), 도형표.size()])

	# 코너 쿼드가 실제로 생성되는지 도형별로 센다 (추측 금지)
	for n in _root.get_children():
		if not n.name.begins_with("black_detail_"):
			continue
		var o := 0
		var i := 0
		for e in n._edges:
			for q in e.quads:
				if q.corner == SS2D_Quad.CORNER.OUTER:
					o += 1
				elif q.corner == SS2D_Quad.CORNER.INNER:
					i += 1
		print("   %-22s OUTER %2d / INNER %2d" % [n.name.replace("black_detail_", ""), o, i])
	quit(0)
