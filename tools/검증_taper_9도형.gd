extends SceneTree
## ============================================================================
## [2026-08-24 신규] taper 수정 검증용 9도형 씬 빌더
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/검증_taper_9도형.gd
##       [-- --taper=res://.../taper/black/ --출력=res://scenes/smartshape_test/xxx.tscn]
##
## ▣ 목적
##   애드온의 taper 를 고치기 **전과 후**를 같은 조건에서 비교하기 위한 고정 시험대.
##   왼쪽 열 = taper 없음(현재 확정 상태) / 오른쪽 열 = taper 있음.
##   한 씬에 둘 다 있으므로 렌더 한 번으로 before/after 를 나란히 본다.
##
## ▣ 지시받은 검증 대상 9종을 전부 넣는다
##   1 직선  2 90도코너  3 L자  4 볼록curve  5 오목curve
##   6 작은curve  7 큰curve  8 복합폐곡선  9 매우짧은edge
##
## ▣ 배경 크기는 손으로 안 적고 계산한다.
##   일부 도형만 배경 밖으로 나가면 반투명한 잔디 술이 다른 색과 섞여서
##   수치 비교가 통째로 무효가 된다 (이걸로 두 번 헛짚었다).
## ============================================================================

const 셰이프_S := preload("res://addons/rmsmartshape/shapes/shape.gd")
## 기본값은 grass_v4. --머티= 로 다른 재질을 넘기면 그 재질로 굽는다
## (기본값을 유지하므로 grass 쪽 동작은 바뀌지 않는다)
var 머티경로 := "res://assets/textures/smartshape/grass_v4/tres/지형_잔디_v4_black_detail.tres"
const 방향이름 := {45: "top", 135: "left", 225: "bottom", 315: "right"}

## 한 열이 차지하는 폭 / 한 행의 높이
const 열폭 := 2600.0
const 행높이 := 1150.0

var _root: Node2D
var _taper폴더 := "res://assets/textures/smartshape/grass_v4/taper/black/"
var _출력 := "res://scenes/smartshape_test/grass_v4_taper검증.tscn"


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--taper="):
			_taper폴더 = a.substr("--taper=".length())
		elif a.begins_with("--머티="):
			머티경로 = a.substr("--머티=".length())
		elif a.begins_with("--출력="):
			_출력 = a.substr("--출력=".length())
	call_deferred("_실행")


# ---------------------------------------------------------------- 도형
func _사각(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)])


func _L자(w: float, h: float, 두께: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, 0), Vector2(w, 0), Vector2(w, 두께),
		Vector2(두께, 두께), Vector2(두께, h), Vector2(0, h)])


func _원(반지름: float, 분할: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 분할:
		var ang: float = -PI * 0.5 + TAU * float(i) / float(분할)
		pts.push_back(Vector2(반지름 + cos(ang) * 반지름, 반지름 + sin(ang) * 반지름))
	return pts


func _언덕(반지름: float, 밑변: float, 분할: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 분할 + 1:
		var ang: float = PI - (float(i) / float(분할)) * PI
		pts.push_back(Vector2(반지름 + cos(ang) * 반지름, 반지름 - sin(ang) * 반지름))
	pts.push_back(Vector2(반지름 * 2.0, 반지름 + 밑변))
	pts.push_back(Vector2(0, 반지름 + 밑변))
	return pts


## 오목 곡선 — 위쪽이 안으로 파인 그릇 모양. 안쪽으로 휘는 호를 만든다.
func _그릇(폭: float, 깊이: float, 분할: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	# 위 가장자리를 왼쪽->오른쪽으로 훑되, 가운데가 아래로 파이게 한다
	for i in 분할 + 1:
		var t: float = float(i) / float(분할)
		var x: float = t * 폭
		var y: float = 깊이 * sin(PI * t)     # 가운데가 아래로 내려간다 = 오목
		pts.push_back(Vector2(x, y))
	pts.push_back(Vector2(폭, 깊이 + 420.0))
	pts.push_back(Vector2(0, 깊이 + 420.0))
	return pts


func _복합(크기: float) -> PackedVector2Array:
	var s := 크기
	return PackedVector2Array([
		Vector2(0.00 * s, 0.28 * s), Vector2(0.30 * s, 0.00 * s),
		Vector2(0.55 * s, 0.18 * s), Vector2(0.72 * s, 0.05 * s),
		Vector2(1.00 * s, 0.34 * s), Vector2(0.86 * s, 0.62 * s),
		Vector2(0.95 * s, 0.86 * s), Vector2(0.58 * s, 0.98 * s),
		Vector2(0.34 * s, 0.80 * s), Vector2(0.12 * s, 0.92 * s)])


# ---------------------------------------------------------------- 머티리얼
func _코너전용(meta) -> bool:
	return meta.normal_range != null and meta.normal_range.distance > 300.0


## taper 를 붙일지 말지만 다른 머티리얼 두 벌을 만든다.
## ★ 매번 .tres 를 새로 로드한다 (CACHE_MODE_IGNORE).
##   duplicate 로 얻은 메타를 setter 에 넘기면 signal 이 얽혀서 멈춘 적이 있다.
func _머티(taper: bool) -> SS2D_Material_Shape:
	var m: SS2D_Material_Shape = ResourceLoader.load(
		머티경로, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not taper:
		return m
	for meta in m.get_all_edge_meta_materials():
		if _코너전용(meta):
			continue
		# 방향은 이름이 아니라 normal_range.begin 으로 판별한다 (배열 순서에 기대지 않는다)
		var b := int(round(meta.normal_range.begin))
		if not 방향이름.has(b):
			push_warning("모르는 normal_range.begin: %d" % b)
			continue
		var d: String = 방향이름[b]
		var l: Texture2D = load(_taper폴더 + "taper_%s_left.png" % d)
		var r: Texture2D = load(_taper폴더 + "taper_%s_right.png" % d)
		if l == null or r == null:
			push_error("taper 텍스처 없음: %s%s" % [_taper폴더, d])
			continue
		var al: Array[Texture2D] = [l]
		var ar: Array[Texture2D] = [r]
		meta.edge_material.textures_taper_left = al
		meta.edge_material.textures_taper_right = ar
		meta.edge_material.use_taper_texture = true
	return m


# ---------------------------------------------------------------- 조립
func _도형(이름: String, 위치: Vector2, 점들: PackedVector2Array,
		머티: SS2D_Material_Shape) -> Node2D:
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
	s.force_update()   # 이걸 빼면 메시가 0개로 조용히 나온다
	return s


func _라벨(위치: Vector2, 글: String, 크기: int) -> void:
	var l := Label.new()
	l.name = "L_%d_%d_%s" % [int(위치.x), int(위치.y), 글.substr(0, 4)]
	l.position = 위치
	l.text = 글
	l.add_theme_color_override("font_color", Color(0.10, 0.10, 0.12))
	l.add_theme_font_size_override("font_size", 크기)
	_root.add_child(l)
	l.owner = _root


## taper 가 들어갈 자리(각 엣지의 첫/마지막 쿼드) 길이의 최솟값.
## shape.gd 의 fit 검사가 이 값과 taper 길이를 비교한다.
func _끝쿼드최소(s: Node2D) -> float:
	var 최소 := 1e9
	for e in s.get_edges():
		if e.quads.is_empty():
			continue
		for q in [e.quads[0], e.quads[e.quads.size() - 1]]:
			if q.corner == SS2D_Quad.CORNER.NONE:
				최소 = minf(최소, q.get_length_average())
	return 최소 if 최소 < 1e8 else 0.0


func _실행() -> void:
	_root = Node2D.new()
	_root.name = "grass_v4_taper검증"
	root.add_child(_root)   # 트리에 없으면 force_update() 가 아무 일도 안 한다

	# [이름, 점들, 이 도형이 놓일 행]
	var 도형표 := [
		["1_직선", _사각(1500, 230)],
		["2_90도코너", _사각(560, 560)],
		["3_L자", _L자(700, 700, 260)],
		["4_볼록curve", _원(300, 24)],
		["5_오목curve", _그릇(900, 300, 20)],
		["6_작은curve", _원(110, 14)],
		["7_큰curve", _언덕(520, 200, 26)],
		["8_복합폐곡선", _복합(700)],
		["9_매우짧은edge", _사각(120, 230)],
	]

	var 열 := [["A_taper없음", false], ["B_taper있음", true]]

	var bg := ColorRect.new()
	bg.name = "배경"
	bg.position = Vector2(-500, -500)
	bg.size = Vector2(열.size() * 열폭 + 800, 도형표.size() * 행높이 + 900)
	bg.color = Color(0.66, 0.68, 0.71)
	bg.z_index = -100
	_root.add_child(bg)
	bg.owner = _root

	for ci in 열.size():
		var m := _머티(열[ci][1])
		var x: float = ci * 열폭
		_라벨(Vector2(x, -380), 열[ci][0], 90)
		for ri in 도형표.size():
			var y: float = ri * 행높이
			var n := _도형("%s_%s" % [열[ci][0], 도형표[ri][0]],
				Vector2(x, y), 도형표[ri][1], m)
			if ci == 0:
				_라벨(Vector2(x - 480, y), 도형표[ri][0], 46)
			if ci == 0:
				print("  %-16s 끝쿼드 최소 %7.1f 월드px" % [도형표[ri][0], _끝쿼드최소(n)])

	var cam := Camera2D.new()
	cam.name = "카메라"
	cam.position = Vector2(열.size() * 열폭 * 0.5, 도형표.size() * 행높이 * 0.5)
	cam.zoom = Vector2(0.16, 0.16)
	_root.add_child(cam)
	cam.owner = _root

	var packed := PackedScene.new()
	if packed.pack(_root) != OK:
		push_error("pack 실패")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://scenes/smartshape_test")
	if ResourceSaver.save(packed, _출력) != OK:
		push_error("저장 실패")
		quit(1)
		return
	print("[build] 저장: %s   (taper 폴더: %s)" % [_출력, _taper폴더])
	quit(0)
