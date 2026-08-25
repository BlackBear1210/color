extends SceneTree
## ============================================================================
## [2026-08-25 신규] STEP 2.9 — 작업자 교육용 실내 예제 씬
## ----------------------------------------------------------------------------
## 실행: Godot --headless --path . -s res://tools/build_작업자예제_실내.gd
## 결과: scenes/집/스마트 매쉬 assets/WORKER_EXAMPLE_INTERIOR.tscn
##
## ▣ 이건 게임 스테이지가 아니다.
##   "이 타일셋으로 실제 맵을 어떻게 구성하는가" 를 보여주는 **샘플**이다.
##   그래서 실제 stage 와 같은 구성(월드.gd + 페인트코어 + 지형/ + Player)으로 만들어
##   작업자가 직접 걸어 다녀 볼 수 있게 했다.
##
## ▣ 재질 역할 분담
##   GRASS — 바깥 자연 지형        BRICK — 건물 바닥·벽·계단        WOOD — 실내 선반·플랫폼
##
## ▣ 치수는 STEP 2.8 실측 규칙을 지킨다
##   발판 두께 180 이상 · 계단 폭 180 x 높이 110 · 부드러운 원 폐곡선 금지(다각형만)
## ============================================================================

const 지형_S := preload("res://scripts/스마트월드/지형.gd")
const 월드_S := preload("res://scripts/스마트월드/월드.gd")
const 코어_S := preload("res://scripts/스마트월드/페인트_코어.gd")
const 플레이어_씬 := preload("res://scenes/player/Player.tscn")
const 저장경로 := "res://scenes/집/스마트 매쉬 assets/WORKER_EXAMPLE_INTERIOR.tscn"
const T := "res://assets/textures/smartshape"

const M_BRICK := T + "/brick_v2/tres/지형_벽돌v2_black_detail.tres"
const M_BRICK_H := T + "/brick_v2/tres/지형_벽돌v2_black_detail_속빔.tres"
const M_WOOD := T + "/wood_v2/tres/지형_나무v2_black_detail.tres"
const M_GRASS := T + "/grass_v4/tres/지형_잔디_v4_black_detail.tres"

var _root: Node2D
var _지형: Node2D


func _init() -> void:
	call_deferred("_실행")


func _사각(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


## 계단 — 폭 180 x 높이 110 + 꼭대기 발판
func _계단(x0: float, y0: float, n: int, 바닥: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	var x := x0
	var y := y0
	p.push_back(Vector2(x, y))
	for i in n:
		x += 180.0
		p.push_back(Vector2(x, y))
		y -= 110.0
		p.push_back(Vector2(x, y))
	x += 180.0
	p.push_back(Vector2(x, y))
	p.push_back(Vector2(x, 바닥))
	p.push_back(Vector2(x0, 바닥))
	return p


## ★ 다각형 링 — 부드러운 원은 금지(CLOSED-LOOP-TAPER-01)라 8각형으로 만든다.
##   모서리에는 코너 쿼드가 들어가 taper 틈을 메워 준다.
func _다각형(cx: float, cy: float, r: float, 변: int) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 변:
		var a: float = -PI * 0.5 + TAU * float(i) / float(변)
		p.push_back(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	return p


func _지형만들기(이름: String, 머티: String, 점들: PackedVector2Array) -> void:
	if not ResourceLoader.exists(머티):
		push_error("머티리얼 없음: %s" % 머티)
		return
	var n = 지형_S.new()
	n.name = 이름
	n.shape_material = load(머티)
	n.시작상태 = 0
	_지형.add_child(n)
	n.owner = _root
	var pa: SS2D_Point_Array = n.get_point_array()
	pa.begin_update()
	pa.add_points(점들)
	pa.end_update()
	pa.close_shape()
	var body := StaticBody2D.new()
	body.name = "StaticBody2D"
	n.add_child(body)
	var poly := CollisionPolygon2D.new()
	poly.name = "CollisionPolygon2D"
	body.add_child(poly)
	n.collision_update_mode = 2
	n.collision_size = 24.0
	n.collision_polygon_node_path = NodePath("StaticBody2D/CollisionPolygon2D")
	n.force_update()
	body.owner = _root
	poly.owner = _root


func _라벨(위치: Vector2, 글: String, 크기: int, 색: Color) -> void:
	var l := Label.new()
	l.name = "설명_%d_%d" % [int(위치.x), int(위치.y)]
	l.position = 위치
	l.text = 글
	l.add_theme_color_override("font_color", 색)
	l.add_theme_font_size_override("font_size", 크기)
	l.z_index = 50
	_root.add_child(l)
	l.owner = _root


func _실행() -> void:
	_root = Node2D.new()
	_root.name = "WORKER_EXAMPLE_INTERIOR"
	_root.set_script(월드_S)
	_root.set("스테이지_이름", "작업자 예제 — 실내 구성")
	_root.set("시작_위치", Vector2(-200, 700))
	_root.set("카메라_줌", 0.82)
	_root.set("카메라_리밋", Rect2(-700, -600, 5000, 2100))
	_root.set("낙사_y", 1700.0)
	root.add_child(_root)

	var 코어 := Node.new()
	코어.name = "페인트코어"
	코어.set_script(코어_S)
	코어.add_to_group("페인트코어")
	_root.add_child(코어)
	코어.owner = _root

	var bg := ColorRect.new()
	bg.name = "배경"
	bg.position = Vector2(-800, -600)
	bg.size = Vector2(5200, 2500)
	bg.color = Color(0.62, 0.64, 0.68)
	bg.z_index = -100
	_root.add_child(bg)
	bg.owner = _root

	_지형 = Node2D.new()
	_지형.name = "지형"
	_root.add_child(_지형)
	_지형.owner = _root

	# 바깥 — 자연 지형
	_지형만들기("SS_GRASS_FLOOR_01", M_GRASS, _사각(-600, 800, 700, 1150))
	# 건물 — 바닥 / 계단 / 뒷벽
	# ★ 계단 뒤에 낮은 바닥을 남기면 **거기 떨어졌을 때 못 나오는 웅덩이**가 된다.
	#   (실제로 레벨검사가 소프트락 1개로 잡았다) 그래서 계단 위는 통째로 윗층으로 만든다.
	_지형만들기("SS_BRICK_FLOOR_01", M_BRICK, _사각(700, 800, 1400, 1150))
	_지형만들기("SS_BRICK_STAIRS_01", M_BRICK, _계단(1400, 800, 3, 1150))
	_지형만들기("SS_BRICK_FLOOR_02", M_BRICK, _사각(2120, 470, 2650, 1150))
	# 건물 — 천장에서 내려온 기둥 (아래로 지나갈 수 있게 띄운다)
	_지형만들기("SS_BRICK_PILLAR_01", M_BRICK, _사각(1000, 180, 1260, 660))
	# 실내 목재 — 선반 두 단.
	# ★ 선반을 **걸어다니는 바닥 바로 위**에 두면 안 된다.
	#   선반 두께 192 + 플레이어 키 105 = 297px 를 못 띄우면 그 아래가 '설 수 없는 칸'이
	#   되어 바닥이 끊긴다 (레벨검사가 잡아냈다). 그래서 바닥이 끝난 뒤에 올려 붙인다.
	_지형만들기("SS_WOOD_SHELF_01", M_WOOD, _사각(2700, 360, 3100, 552))
	_지형만들기("SS_WOOD_SHELF_02", M_WOOD, _사각(3150, 250, 3550, 442))
	_지형만들기("SS_BRICK_WALL_01", M_BRICK, _사각(3600, -250, 3860, 470))
	# 장식 — 링. ★ 원도 8각형도 대각선 변에서 taper 틈이 생긴다.
	#   틈이 확실히 안 생기는 것은 **직각(축 정렬) 사각형** 뿐이다 (모서리에 코너 쿼드가 들어간다).
	_지형만들기("SS_BRICK_HOLLOW_01", M_BRICK_H, _사각(300, 180, 700, 580))

	_라벨(Vector2(-640, -420), "작업자 예제 — 실내 구성 (게임 스테이지 아님)", 78, Color(0.75, 0.05, 0.05))
	_라벨(Vector2(-640, -320),
		"GRASS = 바깥 자연 지형   /   BRICK = 건물 바닥·벽·계단   /   WOOD = 실내 선반·플랫폼",
		52, Color(0.08, 0.08, 0.10))
	_라벨(Vector2(-640, -250),
		"계단 폭 180 x 높이 110  ·  발판 두께 180 이상  ·  부드러운 원 폐곡선 금지(다각형만)",
		48, Color(0.45, 0.05, 0.05))

	var 설명 := [
		[Vector2(-580, 730), "GRASS 바깥 바닥"], [Vector2(300, 120), "직각 링 (HOLLOW)"],
		[Vector2(760, 730), "BRICK 건물 바닥"], [Vector2(1000, 120), "BRICK 기둥"],
		[Vector2(1420, 730), "BRICK 계단"], [Vector2(2710, 300), "WOOD 선반 1"],
		[Vector2(3160, 190), "WOOD 선반 2"], [Vector2(3610, -310), "BRICK 벽"],
		[Vector2(2140, 410), "BRICK 윗층"],
	]
	for s in 설명:
		_라벨(s[0], s[1], 44, Color(0.08, 0.08, 0.10))

	var p := 플레이어_씬.instantiate()
	p.name = "Player"
	p.position = Vector2(-200, 700)
	p.set("move_speed", 300.0)
	p.set("점프_거리_칸", 15.0)
	p.set("상승_배수", 9.0)
	p.set("낙하_가속_증가율", 9.0)
	_root.add_child(p)
	p.owner = _root

	var packed := PackedScene.new()
	if packed.pack(_root) != OK:
		push_error("pack 실패")
		quit(1)
		return
	if ResourceSaver.save(packed, 저장경로) != OK:
		push_error("저장 실패")
		quit(1)
		return
	print("[build] 저장: %s  (지형 %d개)" % [저장경로, _지형.get_child_count()])
	quit(0)
