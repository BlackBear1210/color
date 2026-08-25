extends SceneTree
## ============================================================================
## [2026-08-25 신규] 작업자 전용 가이드 씬 (STEP 2.7)
## ----------------------------------------------------------------------------
## 실행: Godot --headless --path . -s res://tools/생성_작업자가이드씬.gd
## 결과: scenes/집/스마트 매쉬 assets/WORKER_GUIDE.tscn
##
## ▣ 목적
##   예쁜 쇼케이스가 아니다. **다른 작업자가 5분 안에 SmartShape2D 를 이해하는 것.**
##   그래서 실제로 맵에서 쓰는 7가지 형태만 딱 보여준다.
##   치수는 전부 실측으로 정한 안전선을 지킨다 —
##     공중 발판 두께 >= 180 월드px · 계단 한 칸 >= 180 월드px
##   (89.6px 짜리 엣지 띠가 위아래로 겹치면 FILL 이 사라지고,
##    코너 쿼드도 89.6px 이라 그보다 작은 계단은 서로 겹쳐 뭉개진다)
## ============================================================================

const 지형_S := preload("res://scripts/스마트월드/지형.gd")
const 저장경로 := "res://scenes/집/스마트 매쉬 assets/WORKER_GUIDE.tscn"
const T := "res://assets/textures/smartshape"

const 재질표 := [
	["BRICK (벽돌)", T + "/brick_v2/tres/지형_벽돌v2_black_detail.tres"],
	["WOOD (나무)", T + "/wood_v2/tres/지형_나무v2_black_detail.tres"],
]

const 칸폭 := 1180.0
const 행높이 := 1250.0

var _root: Node2D


func _init() -> void:
	call_deferred("_실행")


func _원(r: float, 분할: int) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 분할:
		var a: float = -PI * 0.5 + TAU * float(i) / float(분할)
		p.push_back(Vector2(r + cos(a) * r, r + sin(a) * r))
	return p


## 계단 — 한 칸 180x180, 4단. 이 크기 아래로 내려가면 코너가 겹쳐 깨진다.
func _계단() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, 330), Vector2(180, 330), Vector2(180, 220),
		Vector2(360, 220), Vector2(360, 110), Vector2(540, 110),
		Vector2(540, 0), Vector2(720, 0),
		Vector2(720, 900), Vector2(0, 900)])


func _예제표() -> Array:
	return [
		["1. 기본 바닥", PackedVector2Array([
			Vector2(0, 0), Vector2(900, 0), Vector2(900, 260), Vector2(0, 260)])],
		["2. 긴 벽", PackedVector2Array([
			Vector2(0, 0), Vector2(260, 0), Vector2(260, 900), Vector2(0, 900)])],
		["3. 공중 발판 (두께 192)", PackedVector2Array([
			Vector2(0, 0), Vector2(520, 0), Vector2(520, 192), Vector2(0, 192)])],
		["4. 계단 (폭 180 x 높이 110)", _계단()],
		["5. L자", PackedVector2Array([
			Vector2(0, 0), Vector2(700, 0), Vector2(700, 260),
			Vector2(260, 260), Vector2(260, 700), Vector2(0, 700)])],
		["6. ㄷ자", PackedVector2Array([
			Vector2(0, 0), Vector2(700, 0), Vector2(700, 250),
			Vector2(250, 250), Vector2(250, 450), Vector2(700, 450),
			Vector2(700, 700), Vector2(0, 700)])],
		["7. 폐곡선 — 부드러운 원은 45도 4곳에 틈 (다각형 권장)", _원(300.0, 24)],
	]


func _라벨(위치: Vector2, 글: String, 크기: int, 색: Color) -> void:
	var l := Label.new()
	l.name = "L_%d_%d" % [int(위치.x), int(위치.y)]
	l.position = 위치
	l.text = 글
	l.add_theme_color_override("font_color", 색)
	l.add_theme_font_size_override("font_size", 크기)
	_root.add_child(l)
	l.owner = _root


func _실행() -> void:
	_root = Node2D.new()
	_root.name = "WORKER_GUIDE"
	root.add_child(_root)

	var 예제 := _예제표()
	var 전체폭: float = 칸폭 * float(예제.size())

	# ── 배경 ──────────────────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.name = "배경"
	bg.position = Vector2(-400, -900)
	bg.size = Vector2(전체폭 + 800, 행높이 * float(재질표.size() - 1) + 2200.0)
	bg.color = Color(0.68, 0.70, 0.73)
	bg.z_index = -100
	_root.add_child(bg)
	bg.owner = _root

	# ── 맨 위 안내 ────────────────────────────────────────────────────────
	_라벨(Vector2(-360, -840), "이 씬은 예제입니다.", 150, Color(0.75, 0.05, 0.05))
	_라벨(Vector2(-360, -650),
		"실제 맵에서는 TEMPLATE_*.tscn 을 DUPLICATE 해서 쓰세요. 이 씬은 고치지 마세요.",
		96, Color(0.10, 0.10, 0.12))
	_라벨(Vector2(-360, -500),
		"작업 순서:  ① Template 복제  ②  이름 변경  ③  SmartShape2D 노드 선택"
		+ "  ④  점을 끌어서 모양 만들기  ⑤  저장   — 이게 전부입니다.",
		84, Color(0.16, 0.16, 0.20))
	_라벨(Vector2(-360, -370),
		"치수 규칙:  공중 발판 두께 180px 이상  ·  계단 폭 180px 이상 · 높이 110px"
		+ "   (발판 140px 미만이면 검은 막대 · 계단 폭 90px 미만이면 코너가 뭉갬 · 계단 높이는 120px 이하여야 올라갑니다)",
		84, Color(0.45, 0.05, 0.05))
	_라벨(Vector2(-360, -240),
		"texture · material · corner · texture_scale 은 건드리지 마세요. 사용법은 README_지형찍기.md",
		84, Color(0.16, 0.16, 0.20))

	# ── 예제 배치 ─────────────────────────────────────────────────────────
	for ri in 재질표.size():
		var 재질: Array = 재질표[ri]
		if not ResourceLoader.exists(재질[1]):
			push_warning("머티리얼 없음: %s" % 재질[1])
			continue
		var y: float = float(ri) * 행높이
		_라벨(Vector2(-360, y + 320), 재질[0], 110, Color(0.10, 0.10, 0.12))
		for ci in 예제.size():
			var x: float = float(ci) * 칸폭
			var n = 지형_S.new()
			n.name = "%s_%d" % [재질[0].split(" ")[0], ci + 1]
			n.position = Vector2(x, y)
			n.shape_material = load(재질[1])
			n.시작상태 = 0
			_root.add_child(n)
			n.owner = _root
			var pa: SS2D_Point_Array = n.get_point_array()
			pa.begin_update()
			pa.add_points(예제[ci][1])
			pa.end_update()
			pa.close_shape()
			n.force_update()
			if ri == 0:
				_라벨(Vector2(x, y - 130), 예제[ci][0], 76, Color(0.10, 0.10, 0.12))

	var cam := Camera2D.new()
	cam.name = "카메라"
	# 내용 위끝 -900(제목) ~ 아래끝 (행수-1)*행높이+900(가장 큰 도형) 의 한가운데
	cam.position = Vector2(전체폭 * 0.5 - 200.0,
		(-900.0 + 행높이 * float(재질표.size() - 1) + 900.0) * 0.5)
	cam.zoom = Vector2(0.24, 0.24)
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
	print("[build] 저장: %s  (예제 %d x 재질 %d)" % [저장경로, 예제.size(), 재질표.size()])
	quit(0)
