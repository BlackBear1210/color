extends SceneTree
## ============================================================================
## [2026-08-24 신규] grass_v4 코너 합성 진단 씬 빌더 (신규 경로 · 기존 씬 무수정)
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/진단_grass_v4_코너합성.gd
## 결과:
##   scenes/smartshape_test/grass_v4_코너진단2.tscn
##
## ▣ 왜 만들었나
##   최종검증 씬을 확대해 보니 볼록/오목 코너 자리에 **직사각형 타일 경계**가
##   눈에 보인다. 수치 검사(코너 쿼드 개수, 단면 이음매 1/255)는 전부 통과했는데
##   합성된 화면에서는 각진 단차가 남는다. 원인을 추측하지 않고 갈라서 본다.
##
## ▣ 가설
##   하이브리드 구성에서 4방향 엣지와 코너전용 엣지는 **서로 다른 머티리얼**이다.
##   SS2D 는 같은 엣지 안에서만 코너 자리를 비워 주므로(코너 쿼드가 마지막 쿼드를
##   대체한다), 다른 머티리얼에서 온 코너는 4방향 엣지를 **덮어쓰기만** 한다.
##   -> 코너 정사각형이 엣지 위에 그대로 겹쳐 그려져서 사각 경계가 드러난다.
##
## ▣ 검증 방법 — 같은 도형을 여러 구성으로 나란히 굽는다
##   A. 4방향 엣지만            (코너전용 머티리얼 제거)
##   B. 코너전용 엣지만          (4방향 제거)
##   C. 현재 구성 (A + B)        = 커밋된 .tres 그대로 (코너 z=1, 배열 끝)
##   D. 코너를 배열 맨 앞 + z=0   -> 4방향 엣지가 코너 **위에** 그려진다
##   E. 코너 z = -1              -> 코너를 엣지 아래로 내린다
##   D/E 는 .tres 설정만 바꾸는 1순위 해결책 후보다. 먼저 이것부터 시험한다.
##
##   A 의 세로 이음매가 낮으면 원인은 코너 겹침(A/B),
##   A 도 높으면 원인은 띠 접합 자체(E) 다.
## ============================================================================

const 셰이프_S := preload("res://addons/rmsmartshape/shapes/shape.gd")
const 저장경로 := "res://scenes/smartshape_test/grass_v4_코너진단2.tscn"
const 머티경로 := "res://assets/textures/smartshape/grass_v4/tres/지형_잔디_v4_black_detail.tres"
## 변형 하나가 차지하는 가로 폭. 배경 크기를 이걸로 계산하므로 한 군데서만 고친다.
const 간격 := 1000.0

var _root: Node2D
var _원본: SS2D_Material_Shape


func _init() -> void:
	call_deferred("_실행")


func _사각(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)])


## 원. 짧은 곡선 검사용 — taper 가 짧은 쿼드에서 터지는지 보려는 것.
## shape.gd:1724 의 fit 검사가 실패하면 쿼드 **전체**가 taper 텍스처로 바뀐다.
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


func _복합(크기: float) -> PackedVector2Array:
	var s := 크기
	return PackedVector2Array([
		Vector2(0.00 * s, 0.28 * s), Vector2(0.30 * s, 0.00 * s),
		Vector2(0.55 * s, 0.18 * s), Vector2(0.72 * s, 0.05 * s),
		Vector2(1.00 * s, 0.34 * s), Vector2(0.86 * s, 0.62 * s),
		Vector2(0.95 * s, 0.86 * s), Vector2(0.58 * s, 0.98 * s),
		Vector2(0.34 * s, 0.80 * s), Vector2(0.12 * s, 0.92 * s)])


func _L자(w: float, h: float, 두께: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, 0), Vector2(w, 0), Vector2(w, 두께),
		Vector2(두께, 두께), Vector2(두께, h), Vector2(0, h)])


## 코너전용 메타(전방향 0~360)인지 판별. 4방향은 distance 90 이다.
func _코너전용(meta) -> bool:
	return meta.normal_range != null and meta.normal_range.distance > 300.0


## 원본을 깊은 복제한 뒤 원하는 메타만 남긴다. 원본 .tres 는 건드리지 않는다.
## 코너포함/방향포함 = 어떤 메타를 남길지.
## 코너z = null 이 아니면 코너 메타의 z_index 를 그 값으로 덮어쓴다.
## 코너먼저 = true 면 코너 메타를 배열 맨 앞으로 옮긴다 (같은 z 에서 먼저 = 아래로 깔린다).
func _변형(코너포함: bool, 방향포함: bool, 코너z = null, 코너먼저: bool = false,
		방향z = null) -> SS2D_Material_Shape:
	# ★ 매번 .tres 를 새로 로드한다. duplicate 로 얻은 메타를 setter 에 넘기면
	#   원본과 signal 연결이 얽혀서 멈춘 적이 있다 (한 번 겪음).
	var m: SS2D_Material_Shape = ResourceLoader.load(머티경로, "", ResourceLoader.CACHE_MODE_IGNORE)
	# setter 가 Array[SS2D_Material_Edge_Metadata] 타입을 요구한다. 무타입 Array 면 거부된다.
	var 남길: Array[SS2D_Material_Edge_Metadata] = []
	var 코너메타: Array[SS2D_Material_Edge_Metadata] = []
	for meta in m.get_all_edge_meta_materials():
		var c := _코너전용(meta)
		if c and 코너포함:
			if 코너z != null:
				meta.z_index = int(코너z)
			코너메타.push_back(meta)
		elif not c and 방향포함:
			if 방향z != null:
				meta.z_index = int(방향z)
			남길.push_back(meta)
	if 코너먼저:
		for meta in 남길:
			코너메타.push_back(meta)
		남길 = 코너메타
	else:
		for meta in 코너메타:
			남길.push_back(meta)
	m.set_edge_meta_materials(남길)
	return m


## 4방향 엣지에 taper 텍스처를 달아 준다.
## 어느 방향인지는 normal_range.begin 으로 판별한다 (45 top / 135 left / 225 bottom / 315 right).
## 이름으로 짐작하지 않는다 — .tres 의 배열 순서에 기대면 나중에 조용히 어긋난다.
const TAPER폴더 := "res://assets/textures/smartshape/grass_v4/taper/black/"
const 방향이름 := {45: "top", 135: "left", 225: "bottom", 315: "right"}


func _taper붙이기(m: SS2D_Material_Shape) -> void:
	for meta in m.get_all_edge_meta_materials():
		if _코너전용(meta):
			continue
		var b := int(round(meta.normal_range.begin))
		if not 방향이름.has(b):
			push_warning("모르는 normal_range.begin: %d" % b)
			continue
		var d: String = 방향이름[b]
		var l: Texture2D = load(TAPER폴더 + "taper_%s_left.png" % d)
		var r: Texture2D = load(TAPER폴더 + "taper_%s_right.png" % d)
		if l == null or r == null:
			push_error("taper 텍스처 없음: %s" % d)
			continue
		var al: Array[Texture2D] = [l]
		var ar: Array[Texture2D] = [r]
		meta.edge_material.textures_taper_left = al
		meta.edge_material.textures_taper_right = ar
		meta.edge_material.use_taper_texture = true


func _도형(이름: String, 위치: Vector2, 점들: PackedVector2Array, 머티) -> Node2D:
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


func _라벨(위치: Vector2, 글: String, 크기: int) -> void:
	var l := Label.new()
	l.name = "L_%d_%d" % [int(위치.x), int(위치.y)]
	l.position = 위치
	l.text = 글
	l.add_theme_color_override("font_color", Color(0.10, 0.10, 0.12))
	l.add_theme_font_size_override("font_size", 크기)
	_root.add_child(l)
	l.owner = _root


func _실행() -> void:
	_원본 = load(머티경로)
	if _원본 == null:
		push_error("머티리얼 로드 실패")
		quit(1)
		return

	_root = Node2D.new()
	_root.name = "grass_v4_코너진단2"
	root.add_child(_root)   # 트리에 없으면 force_update() 가 아무것도 안 한다

	# [이름, 코너포함, 방향포함, 코너z(null=원본), 코너먼저]
	var 구성 := [
		["A_4방향만", false, true, null, false],
		["B_코너전용만", true, false, null, false],
		["C_현재구성", true, true, null, false],
		["D_코너를앞으로", true, true, 0, true],
		["E_코너z마이너스", true, true, -1, false],
		# F: 층을 명시적으로 못 박는다. 필 -1 < 코너 0 < 엣지 1 — 동률이 없다.
		["F_층명시", true, true, 0, false, 1],
		# G: 현재 구성 + 4방향 엣지에 taper. 띠가 코너 앞에서 알파로 사라진다.
		["G_taper", true, true, null, false, null, true],
	]
	# ★ 배경은 모든 변형을 덮어야 한다. 일부 변형만 다른 배경 위에 놓이면
	#   반투명한 잔디 술이 배경과 섞이는 정도가 달라져서 비교 자체가 무효가 된다.
	#   (이걸로 두 번 잘못된 결론을 낼 뻔했다 — 그래서 크기를 손으로 안 적고 계산한다)
	var bg := ColorRect.new()
	bg.name = "배경"
	bg.position = Vector2(-400, -400)
	bg.size = Vector2(구성.size() * 간격 + 1400, 3600)
	bg.color = Color(0.66, 0.68, 0.71)
	bg.z_index = -100
	_root.add_child(bg)
	bg.owner = _root

	var x := 0.0
	for c in 구성:
		var m := _변형(c[1], c[2], c[3], c[4], c[5] if c.size() > 5 else null)
		if c.size() > 6 and c[6]:
			_taper붙이기(m)
		_라벨(Vector2(x, -220), c[0], 46)
		var 사각 := _도형("%s_사각" % c[0], Vector2(x, 0), _사각(560, 560), m)
		var L := _도형("%s_L자" % c[0], Vector2(x, 800), _L자(700, 700, 260), m)
		# 짧은 쿼드에서 taper 가 터지는지 보는 줄 (곡선 · 짧은 직선 · 복합)
		var 짧 := _도형("%s_짧은직선" % c[0], Vector2(x, 1750), _사각(300, 230), m)
		var 원 := _도형("%s_작은원" % c[0], Vector2(x + 380, 1700), _원(150, 16), m)
		var 언 := _도형("%s_큰언덕" % c[0], Vector2(x, 2100), _언덕(300, 140, 24), m)
		var 복 := _도형("%s_복합" % c[0], Vector2(x + 640, 2050), _복합(340), m)
		if c[0].begins_with("C_"):
			for 쌍 in [["사각", 사각], ["L자", L], ["짧은직선", 짧], ["작은원", 원],
					["큰언덕", 언], ["복합", 복]]:
				var r := _끝쿼드길이(쌍[1])
				print("      끝쿼드 최소길이  %-10s %7.1f 월드px  (끝쿼드 %d개)"
					% [쌍[0], r[0], r[1]])
		print("  %-16s 엣지메타 %d개 | 사각 코너 OUT %d/IN %d | L자 코너 OUT %d/IN %d"
			% [c[0], m.get_all_edge_meta_materials().size(),
				_코너수(사각, true), _코너수(사각, false),
				_코너수(L, true), _코너수(L, false)])
		x += 간격

	var cam := Camera2D.new()
	cam.name = "카메라"
	cam.position = Vector2(1400, 750)
	cam.zoom = Vector2(0.5, 0.5)
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


## taper 가 들어갈 자리(각 엣지의 첫/마지막 쿼드)의 길이를 잰다.
## shape.gd:1724 의 fit 검사가 `taper_size.x <= quad.get_length_average()` 이므로
## 이 값보다 긴 taper 를 쓰면 쿼드 **전체**가 taper 텍스처로 덮여 뭉갠 슬래브가 된다.
## -> taper 길이의 상한을 그림이 아니라 이 수치로 정한다.
func _끝쿼드길이(s: Node2D) -> Array:
	var 최소 := 1e9
	var 값 := PackedFloat64Array()
	for e in s.get_edges():
		if e.quads.is_empty():
			continue
		var 후보 := [e.quads[0], e.quads[e.quads.size() - 1]]
		for q in 후보:
			if q.corner != SS2D_Quad.CORNER.NONE:
				continue
			var l: float = q.get_length_average()
			값.push_back(l)
			최소 = minf(최소, l)
	return [최소 if 최소 < 1e8 else 0.0, 값.size()]


## 코너 쿼드 개수를 센다 (추측 금지 — 실제로 몇 개 만들어졌는지 본다)
func _코너수(s: Node2D, 바깥: bool) -> int:
	var n := 0
	for e in s.get_edges():
		for q in e.quads:
			if 바깥 and q.corner == SS2D_Quad.CORNER.OUTER:
				n += 1
			elif not 바깥 and q.corner == SS2D_Quad.CORNER.INNER:
				n += 1
	return n
