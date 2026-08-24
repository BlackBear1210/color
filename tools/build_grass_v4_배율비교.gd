extends SceneTree
## ============================================================================
## [2026-08-24 신규] grass_v4 texture_scale 비교 씬 빌더
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/build_grass_v4_배율비교.gd
## 결과:
##   scenes/smartshape_test/grass_v4_배율비교.tscn   (신규 · 기존 씬 안 건드림)
##
## ▣ 목적
##   texture_scale 을 "보기 좋다" 가 아니라 실제 게임 스케일 기준으로 고르기 위한 시트.
##
## ▣ 실제 게임 기준(코드에서 읽은 값, 추측 아님)
##   플레이어 충돌 상자 : 55 x 264 월드px   (scenes/player/Player.tscn)
##   카메라 줌          : 0.82             (scripts/스마트월드/월드.gd:36 카메라_줌)
##   뷰포트             : 1920 x 1080      (project.godot)
##   -> 실제 플레이 화면이 담는 월드 영역 = 2341 x 1317 px
##
## ▣ 배율이 뜻하는 것 (SS2D 구조상)
##   잔디 띠 두께 = TOP 텍스처 높이(256) x scale
##   반복 주기    = TOP 텍스처 폭(1024)  x scale
##   코너 정사각형 한 변 = 투명 캐리어 높이(256) x scale  = 띠 두께와 항상 같다
##   -> 코너와 엣지의 크기 관계는 배율과 무관하게 자동으로 일치한다.
##
## ▣ 각 행에 플레이어 크기 실루엣을 같이 놓아 스케일 감각의 기준으로 삼는다.
## ============================================================================

const 셰이프_S := preload("res://addons/rmsmartshape/shapes/shape.gd")
const 저장경로 := "res://scenes/smartshape_test/grass_v4_배율비교.tscn"
const 머티경로 := "res://assets/textures/smartshape/grass_v4/tres/지형_잔디_v4_black_detail.tres"

const 배율목록 := [0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45]
const 행간격 := 1250.0
const 여백 := 300.0

var _root: Node2D
var _원본: SS2D_Material_Shape


func _init() -> void:
	call_deferred("_실행")


# ---------------------------------------------------------------- 도형 생성기
## 시계방향(화면좌표) 사각형. 반시계로 감으면 상/하 텍스처가 뒤바뀐다.
func _사각(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)])


## 위쪽이 둥근 언덕. 큰 곡선 검사용.
## 위 호를 왼쪽->오른쪽으로 돌기 때문에 시계방향이 된다.
func _언덕(반지름: float, 밑변높이: float, 분할: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 분할 + 1:
		var t: float = float(i) / float(분할)
		var ang: float = PI - t * PI            # 180도 -> 0도
		pts.push_back(Vector2(반지름 + cos(ang) * 반지름, 반지름 - sin(ang) * 반지름))
	pts.push_back(Vector2(반지름 * 2.0, 반지름 + 밑변높이))
	pts.push_back(Vector2(0, 반지름 + 밑변높이))
	return pts


## 원. 작은 곡선 검사용. 시계방향으로 샘플링한다.
func _원(반지름: float, 분할: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 분할:
		var ang: float = -PI * 0.5 + TAU * float(i) / float(분할)
		pts.push_back(Vector2(반지름 + cos(ang) * 반지름, 반지름 + sin(ang) * 반지름))
	return pts


## ㄷ자 — 오목 코너 2개를 만든다.
func _ㄷ자(w: float, h: float, 두께: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, 0), Vector2(w, 0), Vector2(w, 두께),
		Vector2(두께, 두께), Vector2(두께, h - 두께),
		Vector2(w, h - 두께), Vector2(w, h), Vector2(0, h)])


func _L자(w: float, h: float, 두께: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, 0), Vector2(w, 0), Vector2(w, 두께),
		Vector2(두께, 두께), Vector2(두께, h), Vector2(0, h)])


## 볼록/오목이 섞인 자유 폐곡선.
func _복합(크기: float) -> PackedVector2Array:
	var s := 크기
	return PackedVector2Array([
		Vector2(0.00 * s, 0.28 * s), Vector2(0.30 * s, 0.00 * s),
		Vector2(0.55 * s, 0.18 * s), Vector2(0.72 * s, 0.05 * s),
		Vector2(1.00 * s, 0.34 * s), Vector2(0.86 * s, 0.62 * s),
		Vector2(0.95 * s, 0.86 * s), Vector2(0.58 * s, 0.98 * s),
		Vector2(0.34 * s, 0.80 * s), Vector2(0.12 * s, 0.92 * s)])


# ---------------------------------------------------------------- 씬 조립
func _배율변형(배율: float) -> SS2D_Material_Shape:
	# 깊은 복제라야 edge_material 서브리소스까지 따로 복사되어 원본 .tres 가 안 더럽혀진다.
	var m: SS2D_Material_Shape = _원본.duplicate(true)
	for meta in m.get_all_edge_meta_materials():
		if meta.edge_material != null:
			meta.edge_material.texture_scale = 배율
	# 필도 같은 배율로 맞춰야 붓자국 크기가 엣지와 어긋나지 않는다.
	m.fill_texture_scale = 배율
	return m


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


func _라벨(위치: Vector2, 글: String, 크기: int, 색: Color) -> void:
	var l := Label.new()
	l.name = "L_%d_%d_%s" % [int(위치.x), int(위치.y), 글.substr(0, 6)]
	l.position = 위치
	l.text = 글
	l.add_theme_color_override("font_color", 색)
	l.add_theme_font_size_override("font_size", 크기)
	_root.add_child(l)
	l.owner = _root


## 플레이어 크기 기준 실루엣 (55 x 264). 배율 감각을 눈으로 잡기 위한 것.
func _플레이어_기준(위치: Vector2) -> void:
	var r := ColorRect.new()
	r.name = "플레이어기준_%d" % int(위치.y)
	r.position = 위치
	r.size = Vector2(55, 264)
	r.color = Color(0.85, 0.2, 0.2, 0.9)
	r.z_index = 50
	_root.add_child(r)
	r.owner = _root
	_라벨(위치 + Vector2(-10, 275), "player 55x264", 26, Color(0.6, 0.1, 0.1))


func _실행() -> void:
	_원본 = load(머티경로)
	if _원본 == null:
		push_error("grass_v4 머티리얼 로드 실패: %s" % 머티경로)
		quit(1)
		return

	_root = Node2D.new()
	_root.name = "grass_v4_배율비교"
	# force_update() 는 is_node_ready() 가 false 면 아무것도 안 한다 -> 반드시 트리에 붙인다.
	root.add_child(_root)

	# 각 행에 놓을 도형 8종 (이름, 점들, 차지하는 폭)
	var 도형표 := [
		["긴직선", _사각(1700, 240), 1700.0],
		["짧은직선", _사각(300, 240), 300.0],
		["큰곡선", _언덕(520, 200, 22), 1040.0],
		["작은곡선", _원(190, 20), 380.0],
		["볼록코너", _사각(520, 520), 520.0],
		["오목코너", _ㄷ자(700, 700, 240), 700.0],
		["L자", _L자(700, 700, 260), 700.0],
		["복합폐곡선", _복합(760), 760.0],
	]

	var bg := ColorRect.new()
	bg.name = "배경"
	bg.position = Vector2(-500, -500)
	bg.size = Vector2(11000, 배율목록.size() * 행간격 + 900)
	bg.color = Color(0.66, 0.68, 0.71)
	bg.z_index = -100
	_root.add_child(bg)
	bg.owner = _root

	for r in 배율목록.size():
		var 배율: float = 배율목록[r]
		var y: float = r * 행간격
		var 머티 := _배율변형(배율)

		var 띠: float = 256.0 * 배율
		var 주기: float = 1024.0 * 배율
		_라벨(Vector2(-460, y - 110),
			"scale %.2f   띠 %.0fpx   주기 %.0fpx   코너 %.0fpx   플레이어키의 %.0f%%   화면당 반복 %.1f회"
			% [배율, 띠, 주기, 띠, 띠 / 264.0 * 100.0, 2341.0 / 주기],
			40, Color(0.10, 0.10, 0.12))

		_플레이어_기준(Vector2(-330, y))

		var x := 0.0
		for 항목 in 도형표:
			_도형("s%02d_%s" % [int(배율 * 100), 항목[0]], Vector2(x, y), 항목[1], 머티)
			if r == 0:
				_라벨(Vector2(x, y - 200), 항목[0], 34, Color(0.25, 0.25, 0.28))
			x += 항목[2] + 여백

	var cam := Camera2D.new()
	cam.name = "카메라"
	cam.position = Vector2(4200, 배율목록.size() * 행간격 * 0.5)
	cam.zoom = Vector2(0.11, 0.11)
	_root.add_child(cam)
	cam.owner = _root

	var packed := PackedScene.new()
	if packed.pack(_root) != OK:
		push_error("pack 실패")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://scenes/smartshape_test")
	if ResourceSaver.save(packed, 저장경로) != OK:
		push_error("저장 실패")
		quit(1)
		return

	print("[build] 저장: %s" % 저장경로)
	print("[build] 행 %d 개 x 도형 %d 종" % [배율목록.size(), 도형표.size()])
	# 테셀레이션이 실제로 되는지 확인 (곡선 도형이 정말 잘게 쪼개졌는가)
	for n in _root.get_children():
		if n.name.begins_with("s15_"):
			var cnt: int = n.get_point_array().get_tessellated_points().size()
			print("   %-18s 점 %2d -> 테셀레이션 %d"
				% [n.name, n.get_point_array().get_point_count(), cnt])
	quit(0)
