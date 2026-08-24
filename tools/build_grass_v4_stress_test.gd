extends SceneTree
## ============================================================================
## [2026-08-24 신규] grass_v4 스트레스 테스트 씬 빌더
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/build_grass_v4_stress_test.gd
## 결과:
##   scenes/smartshape_test/grass_v4_stress_test.tscn  (새로 만든다)
##
## ⚠ 기존 grass_v2_size_test.tscn / grass_v3_test.tscn / test_smartshape_edge.tscn 은
##   건드리지 않는다. 이 도구는 오직 grass_v4_stress_test.tscn 만 쓴다.
##
## ▣ 무엇을 확인하려고 만드나
##   1행  검정 테마 도형 9종 — 긴직선/짧은직선/정사각/직사각/볼록/오목L/오목S/톱니/복합폐곡선
##   2행  흰색 테마 같은 9종 (반전 구조가 그대로 동작하는지)
##   3행  ★texture_scale 비교 — 0.15 / 0.20 / 0.25 / 0.30 / 0.35 / 0.45
##        같은 도형에 배율만 바꿔 나란히 두어 눈으로 고르게 한다
##   4행  ★짧은 엣지 고문 — 60 / 100 / 150 / 240px 엣지
##        1024px 텍스처보다 훨씬 짧다. 예전 코드라면 UV 가 붕괴하는 구간이다 (P0-2)
##
## 배경은 테마별로 반대 밝기를 깔아 실루엣이 보이게 한다.
## ============================================================================

const 셰이프_S := preload("res://addons/rmsmartshape/shapes/shape.gd")

const 저장경로 := "res://scenes/smartshape_test/grass_v4_stress_test.tscn"
const 머티_검정 := "res://assets/textures/smartshape/grass_v4/tres/지형_잔디_v4_black_detail.tres"
const 머티_흰색 := "res://assets/textures/smartshape/grass_v4/tres/지형_잔디_v4_white_detail.tres"

var _root: Node2D


func _init() -> void:
	call_deferred("_실행")


## 도형 9종. 전부 시계방향(화면좌표)으로 감는다 —
## 그래야 바깥 노멀이 위=90도가 되어 normal_range 표(TOP 45~135)와 맞는다.
func _도형표() -> Array:
	return [
		["긴직선", PackedVector2Array([
			Vector2(0, 0), Vector2(2000, 0), Vector2(2000, 300), Vector2(0, 300)])],
		["짧은직선", PackedVector2Array([
			Vector2(0, 0), Vector2(320, 0), Vector2(320, 300), Vector2(0, 300)])],
		["정사각", PackedVector2Array([
			Vector2(0, 0), Vector2(600, 0), Vector2(600, 600), Vector2(0, 600)])],
		["직사각", PackedVector2Array([
			Vector2(0, 0), Vector2(1100, 0), Vector2(1100, 400), Vector2(0, 400)])],
		["볼록_육각", PackedVector2Array([
			Vector2(250, 0), Vector2(750, 0), Vector2(1000, 350),
			Vector2(750, 700), Vector2(250, 700), Vector2(0, 350)])],
		["오목_L자", PackedVector2Array([
			Vector2(0, 0), Vector2(800, 0), Vector2(800, 350),
			Vector2(350, 350), Vector2(350, 800), Vector2(0, 800)])],
		["오목_S자", PackedVector2Array([
			Vector2(0, 0), Vector2(1000, 0), Vector2(1000, 350), Vector2(350, 350),
			Vector2(350, 550), Vector2(1000, 550), Vector2(1000, 900), Vector2(0, 900)])],
		["톱니_급전환", PackedVector2Array([
			Vector2(0, 0), Vector2(200, 0), Vector2(200, 180), Vector2(420, 180),
			Vector2(420, 0), Vector2(620, 0), Vector2(620, 600), Vector2(0, 600)])],
		["복합폐곡선", PackedVector2Array([
			Vector2(0, 250), Vector2(280, 0), Vector2(680, 60), Vector2(950, 300),
			Vector2(880, 680), Vector2(500, 880), Vector2(160, 720), Vector2(30, 480)])],
	]


func _배경(위치: Vector2, 크기: Vector2, 색: Color, 이름: String) -> void:
	var r := ColorRect.new()
	r.name = 이름
	r.position = 위치
	r.size = 크기
	r.color = 색
	r.z_index = -100
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(r)
	r.owner = _root


func _라벨(위치: Vector2, 글: String, 색: Color) -> void:
	var l := Label.new()
	l.name = "라벨_" + 글.replace(" ", "_").replace(".", "_")
	l.position = 위치
	l.text = 글
	l.add_theme_color_override("font_color", 색)
	l.add_theme_font_size_override("font_size", 44)
	_root.add_child(l)
	l.owner = _root


func _도형(이름: String, 위치: Vector2, 점들: PackedVector2Array, 머티: SS2D_Material_Shape) -> void:
	var s: Node2D = 셰이프_S.new()
	s.name = 이름
	s.position = 위치
	s.shape_material = 머티
	_root.add_child(s)
	# owner 는 새로 만든 노드에만 준다 (CLAUDE.md 규칙 6)
	s.owner = _root

	var pa: SS2D_Point_Array = s.get_point_array()
	pa.begin_update()
	pa.add_points(점들)
	pa.end_update()
	pa.close_shape()


## 머티리얼을 깊은 복제해서 엣지 배율만 바꾼다.
## 깊은 복제를 해야 edge_material 서브리소스까지 따로 복사되어
## 원본 .tres 의 배율이 오염되지 않는다.
func _배율변형(원본: SS2D_Material_Shape, 배율: float) -> SS2D_Material_Shape:
	var m: SS2D_Material_Shape = 원본.duplicate(true)
	for meta in m.get_all_edge_meta_materials():
		if meta.edge_material != null:
			meta.edge_material.texture_scale = 배율
	# 필도 같이 맞춰야 붓자국 크기가 엣지와 어긋나지 않는다
	m.fill_texture_scale = 배율
	return m


func _실행() -> void:
	var 검정: SS2D_Material_Shape = load(머티_검정)
	var 흰색: SS2D_Material_Shape = load(머티_흰색)
	if 검정 == null or 흰색 == null:
		push_error("grass_v4 머티리얼을 못 찾았다. make_tres 를 먼저 돌려라.")
		quit(1)
		return

	_root = Node2D.new()
	_root.name = "grass_v4_stress_test"

	var 도형들 := _도형표()

	# ---------------------------------------------------------------- 1행 검정
	# 검정 지형은 밝은 배경 위에 놓아야 실루엣이 보인다
	_배경(Vector2(-200, -400), Vector2(11000, 1700), Color(0.66, 0.68, 0.71), "배경_검정행")
	_라벨(Vector2(-160, -360), "1행 · black_detail · texture_scale 0.35", Color(0.1, 0.1, 0.1))
	var x := 0.0
	for 항목 in 도형들:
		_도형("검정_" + 항목[0], Vector2(x, 0), 항목[1], 검정)
		_라벨(Vector2(x, -120), 항목[0], Color(0.15, 0.15, 0.15))
		x += _폭(항목[1]) + 320.0

	# ---------------------------------------------------------------- 2행 흰색
	var y2 := 1500.0
	_배경(Vector2(-200, y2 - 400), Vector2(11000, 1700), Color(0.10, 0.11, 0.13), "배경_흰색행")
	_라벨(Vector2(-160, y2 - 360), "2행 · white_detail · texture_scale 0.35", Color(0.9, 0.9, 0.9))
	x = 0.0
	for 항목 in 도형들:
		_도형("흰색_" + 항목[0], Vector2(x, y2), 항목[1], 흰색)
		_라벨(Vector2(x, y2 - 120), 항목[0], Color(0.85, 0.85, 0.85))
		x += _폭(항목[1]) + 320.0

	# ---------------------------------------------------------------- 3행 배율 비교
	var y3 := 3100.0
	_배경(Vector2(-200, y3 - 400), Vector2(11000, 1400), Color(0.66, 0.68, 0.71), "배경_배율행")
	_라벨(Vector2(-160, y3 - 360), "3행 · texture_scale 비교 (같은 도형, 배율만 다름)", Color(0.1, 0.1, 0.1))
	var 비교도형 := PackedVector2Array([
		Vector2(0, 0), Vector2(900, 0), Vector2(900, 500), Vector2(0, 500)])
	x = 0.0
	for 배율 in [0.15, 0.20, 0.25, 0.30, 0.35, 0.45]:
		var m := _배율변형(검정, 배율)
		_도형("배율_%03d" % int(배율 * 100), Vector2(x, y3), 비교도형, m)
		_라벨(Vector2(x, y3 - 120), "scale %.2f  (띠 %.0fpx)" % [배율, 256.0 * 배율],
			Color(0.15, 0.15, 0.15))
		x += 900.0 + 320.0

	# ---------------------------------------------------------------- 4행 짧은 엣지 고문
	# 1024px 텍스처보다 훨씬 짧은 엣지들. P0-2 가 없으면 여기서 UV 가 붕괴한다.
	var y4 := 4400.0
	_배경(Vector2(-200, y4 - 400), Vector2(11000, 1200), Color(0.66, 0.68, 0.71), "배경_짧은행")
	_라벨(Vector2(-160, y4 - 360),
		"4행 · ★짧은 엣지 (P0-2) — 전부 텍스처 폭 358px 보다 짧다", Color(0.1, 0.1, 0.1))
	x = 0.0
	for 변 in [60, 100, 150, 240, 320]:
		var pts := PackedVector2Array([
			Vector2(0, 0), Vector2(변, 0), Vector2(변, 변), Vector2(0, 변)])
		_도형("짧은_%d" % 변, Vector2(x, y4), pts, 검정)
		_라벨(Vector2(x, y4 - 120), "%dpx" % 변, Color(0.15, 0.15, 0.15))
		x += 변 + 420.0

	# ---------------------------------------------------------------- 카메라
	var cam := Camera2D.new()
	cam.name = "미리보기_카메라"
	cam.position = Vector2(5000, 2400)
	cam.zoom = Vector2(0.12, 0.12)
	_root.add_child(cam)
	cam.owner = _root

	# ---------------------------------------------------------------- 저장
	var packed := PackedScene.new()
	var err := packed.pack(_root)
	if err != OK:
		push_error("pack 실패: %d" % err)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://scenes/smartshape_test")
	err = ResourceSaver.save(packed, 저장경로)
	if err != OK:
		push_error("저장 실패: %d" % err)
		quit(1)
		return

	print("[build] 저장 완료: %s" % 저장경로)
	print("[build] 노드 %d 개" % _root.get_child_count())
	quit(0)


func _폭(점들: PackedVector2Array) -> float:
	var 최소 := INF
	var 최대 := -INF
	for p in 점들:
		최소 = minf(최소, p.x)
		최대 = maxf(최대, p.x)
	return 최대 - 최소
