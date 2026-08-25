extends SceneTree
## ============================================================================
## [2026-08-25 신규] STEP 2.8 — 실제 stage 형식의 지형 통합 테스트 씬 빌더
## ----------------------------------------------------------------------------
## 실행: Godot --headless --path . -s res://tools/build_지형통합테스트.gd
## 결과: scenes/smartshape_test/TERRAIN_INTEGRATION_TEST.tscn
##
## ▣ 왜 실제 stage 형식인가
##   쇼케이스처럼 도형만 늘어놓으면 "보이는가" 만 알 수 있다.
##   밟히는가 · 올라가지는가 · 벽에 걸리는가는 **월드.gd + Player + 페인트코어**
##   가 다 있는 진짜 스테이지 구조여야 확인된다. 그래서 스마트월드_1 과 같은
##   노드 구성을 그대로 따랐다 (루트=월드.gd · 페인트코어 · 지형/ · Player).
##
## ▣ 기존 stage 는 건드리지 않는다. 이 씬은 별도 파일이다.
##
## ▣ 치수는 두 제약을 동시에 만족시켜야 한다 (실측)
##   시각: 코너 쿼드가 89.6 월드px → 계단 한 칸 >= 90px, 발판 두께 >= 140px
##   조작: 플레이어 점프 높이 160px → 계단 한 칸 높이 <= 150px 여야 올라간다
##   그래서 계단은 **폭 180 x 높이 110** 으로 잡았다.
##   ★ 높이 상한은 점프 높이가 아니라 그 80%(128px) 다 — 조작 오차 여유를 뺀 값.
## ============================================================================

const 지형_S := preload("res://scripts/스마트월드/지형.gd")
const 월드_S := preload("res://scripts/스마트월드/월드.gd")
const 코어_S := preload("res://scripts/스마트월드/페인트_코어.gd")
const 플레이어_씬 := preload("res://scenes/player/Player.tscn")
const 저장경로 := "res://scenes/smartshape_test/TERRAIN_INTEGRATION_TEST.tscn"
const T := "res://assets/textures/smartshape"

const M_BRICK := T + "/brick_v2/tres/지형_벽돌v2_black_detail.tres"
const M_BRICK_H := T + "/brick_v2/tres/지형_벽돌v2_black_detail_속빔.tres"
const M_WOOD := T + "/wood_v2/tres/지형_나무v2_black_detail.tres"
const M_WOOD_H := T + "/wood_v2/tres/지형_나무v2_black_detail_속빔.tres"
const M_GRASS := T + "/grass_v4/tres/지형_잔디_v4_black_detail.tres"

var _root: Node2D
var _지형: Node2D


func _init() -> void:
	call_deferred("_실행")


func _사각(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


## 계단 — 폭 180 x 높이 110, n 칸. 바닥까지 채운다.
## ★ 높이 상한은 시각이 아니라 **조작**이 정한다. 레벨검사는 점프 높이의 80%
##   (160 x 0.8 = 128px) 까지만 올라갈 수 있다고 본다. 140 은 초과라 도달 불가로 잡혔다.
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
	# ★ 마지막 단에도 **발판(가로면)** 을 만들어 준다.
	#   이걸 빼면 맨 위가 폭 0 짜리 수직 스파이크가 되어 밟을 면이 없다.
	#   실제로 이 버그 때문에 계단 꼭대기가 '도달 불가' 로 잡혔다.
	x += 180.0
	p.push_back(Vector2(x, y))
	p.push_back(Vector2(x, 바닥))
	p.push_back(Vector2(x0, 바닥))
	return p


## L자 선반 + 아래로 내려오는 다리
func _L자(x0: float, y0: float, 폭: float, 두께: float, 바닥: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x0, y0), Vector2(x0 + 폭, y0), Vector2(x0 + 폭, y0 + 두께),
		Vector2(x0 + 두께, y0 + 두께), Vector2(x0 + 두께, 바닥), Vector2(x0, 바닥)])


func _원(cx: float, cy: float, r: float, 분할: int) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 분할:
		var a: float = -PI * 0.5 + TAU * float(i) / float(분할)
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
	_root.name = "TERRAIN_INTEGRATION_TEST"
	_root.set_script(월드_S)
	_root.set("스테이지_이름", "지형 통합 테스트 (STEP 2.8)")
	_root.set("시작_위치", Vector2(200, 700))
	_root.set("카메라_줌", 0.82)
	_root.set("카메라_리밋", Rect2(-300, -400, 10800, 2000))
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
	bg.position = Vector2(-400, -600)
	bg.size = Vector2(11200, 2400)
	bg.color = Color(0.62, 0.64, 0.68)
	bg.z_index = -100
	_root.add_child(bg)
	bg.owner = _root

	_지형 = Node2D.new()
	_지형.name = "지형"
	_root.add_child(_지형)
	_지형.owner = _root

	# ── 지형 배치 ─────────────────────────────────────────────────────────
	# ★ 실제로 걸어서 끝까지 갈 수 있어야 검증이 된다.
	#   그래서 섬처럼 띄우지 않고 **연결된 한 줄 레벨**로 짰다.
	#   구멍은 점프 거리 240px 안에서만 두고, 낙차는 치명 520px 를 넘기지 않는다.
	#   벽은 세워 두면 길을 막아 그 뒤가 전부 '도달 불가' 가 되므로
	#   **천장에서 내려온 기둥**으로 만들어 아래로 지나가게 했다 (SIDE 방향 확인은 동일).

	# BRICK — 바닥 / 구멍 위 공중발판 / 바닥 / 계단 / L자 선반
	_지형만들기("BRICK_1_바닥", M_BRICK, _사각(-200, 800, 1000, 1100))
	_지형만들기("BRICK_3_공중발판", M_BRICK, _사각(1040, 680, 1360, 872))
	_지형만들기("BRICK_1b_바닥", M_BRICK, _사각(1400, 800, 2000, 1100))
	_지형만들기("BRICK_2_기둥", M_BRICK, _사각(1700, 180, 1960, 660))
	_지형만들기("BRICK_4_계단", M_BRICK, _계단(2000, 800, 3, 1100))
	_지형만들기("BRICK_5_L자", M_BRICK, _L자(2780, 360, 600, 260, 1100))
	_지형만들기("BRICK_1c_바닥", M_BRICK, _사각(3380, 800, 4900, 1100))
	_지형만들기("BRICK_6_폐곡선_속빔", M_BRICK_H, _원(4100, 380, 280, 24))

	# WOOD — 구멍 위 공중발판 / 바닥 / 계단 / L자 선반 / 천장 기둥 2개 / 폐곡선
	_지형만들기("WOOD_3_공중발판", M_WOOD, _사각(4940, 680, 5260, 872))
	_지형만들기("WOOD_1_바닥", M_WOOD, _사각(5300, 800, 6200, 1100))
	_지형만들기("WOOD_6_폐곡선_속빔", M_WOOD_H, _원(5700, 380, 280, 24))
	_지형만들기("WOOD_4_계단", M_WOOD, _계단(6200, 800, 3, 1100))
	_지형만들기("WOOD_5_L자", M_WOOD, _L자(6980, 360, 600, 260, 1100))
	_지형만들기("WOOD_1b_바닥", M_WOOD, _사각(7580, 800, 8400, 1100))
	_지형만들기("WOOD_2_기둥", M_WOOD, _사각(7600, 180, 7860, 660))
	_지형만들기("WOOD_2b_기둥", M_WOOD, _사각(8000, 180, 8260, 660))

	# GRASS — 스타일 비교용 (변경 없음 · LOCK)
	_지형만들기("GRASS_1_바닥", M_GRASS, _사각(8400, 800, 9800, 1100))

	# ── 라벨 ──────────────────────────────────────────────────────────────
	_라벨(Vector2(-260, -520), "지형 통합 테스트 — STEP 2.8", 90, Color(0.75, 0.05, 0.05))
	_라벨(Vector2(-260, -400),
		"BRICK v2 — production   /   WOOD v2 — production   /   GRASS v4 — production"
		+ "   /   IRON — provisional · do not use", 56, Color(0.08, 0.08, 0.10))
	_라벨(Vector2(-260, -320),
		"계단 한 칸 = 폭 180 x 높이 110   (시각 90px 이상 · 오를 수 있는 한계 128px 이하 — 둘 다 만족)",
		52, Color(0.45, 0.05, 0.05))

	var 설명 := [
		[Vector2(-180, 730), "BRICK 1 바닥"], [Vector2(1040, 610), "3 공중발판 (두께 192)"],
		[Vector2(1700, 120), "2 기둥 (SIDE 방향)"], [Vector2(2020, 730), "4 계단 180x110"],
		[Vector2(2800, 290), "5 L자"], [Vector2(3840, 90), "6 폐곡선 (속빔)"],
		[Vector2(4940, 610), "WOOD 3 공중발판"], [Vector2(5320, 730), "1 바닥"],
		[Vector2(5440, 90), "6 폐곡선 (속빔)"], [Vector2(6220, 730), "4 계단"],
		[Vector2(7000, 290), "5 L자"], [Vector2(7620, 120), "2 기둥"],
		[Vector2(8420, 730), "GRASS (비교용 · LOCK)"],
	]
	for s in 설명:
		_라벨(s[0], s[1], 46, Color(0.08, 0.08, 0.10))

	# ── Player ────────────────────────────────────────────────────────────
	var p := 플레이어_씬.instantiate()
	p.name = "Player"
	p.position = Vector2(200, 700)
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
