extends SceneTree
## ============================================================================
## [2026-08-24 신규] SmartShape2D 타일셋 쇼케이스 씬 (전 재질 한눈에)
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/생성_타일셋_쇼케이스.gd
## 결과:
##   scenes/smartshape_test/SmartShape2D_Tileset_Showcase.tscn
##
## ▣ 배치
##   재질 4 (잔디/벽돌/하수/나무) x 테마 2 (검정/흰색) x 내부 2 (채움/속빔)
##   = 16 블록, 각 블록에 도형 9종.
##   검정 테마는 밝은 배경 위에, 흰색 테마는 어두운 배경 위에 놓아 실루엣을 본다.
##
## ▣ 색은 머티리얼이 아니라 `시작상태` 로 준다 (지형.gd 의 런타임 상태).
##   '흰색 전용 머티리얼' 을 만들면 그 지형은 검정으로 칠할 수 없게 되기 때문이다.
## ============================================================================

const 지형_S := preload("res://scripts/스마트월드/지형.gd")
const 저장경로 := "res://scenes/smartshape_test/SmartShape2D_Tileset_Showcase.tscn"

const 재질표 := [
	["잔디", "res://assets/textures/smartshape/grass_v4/tres/지형_잔디_v4_black_detail.tres",
		"res://assets/textures/smartshape/grass_v4/tres/지형_잔디v4_black_detail_속빔.tres"],
	["벽돌 v2", "res://assets/textures/smartshape/brick_v2/tres/지형_벽돌v2_black_detail.tres",
		"res://assets/textures/smartshape/brick_v2/tres/지형_벽돌v2_black_detail_속빔.tres"],
	["하수 v1(보류)", "res://assets/textures/smartshape/sewer_v1/tres/지형_하수v1_black_detail.tres",
		"res://assets/textures/smartshape/sewer_v1/tres/지형_하수v1_black_detail_속빔.tres"],
	["나무 v2", "res://assets/textures/smartshape/wood_v2/tres/지형_나무v2_black_detail.tres",
		"res://assets/textures/smartshape/wood_v2/tres/지형_나무v2_black_detail_속빔.tres"],
]

const 행높이 := 1150.0
const 블록폭 := 9600.0     # 도형 9종이 들어가는 가로 폭

var _root: Node2D


func _init() -> void:
	call_deferred("_실행")


# ---------------------------------------------------------------- 도형 9종
func _사각(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)])


func _L자(w: float, h: float, 두께: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, 0), Vector2(w, 0), Vector2(w, 두께),
		Vector2(두께, 두께), Vector2(두께, h), Vector2(0, h)])


func _ㄷ자(w: float, h: float, 두께: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, 0), Vector2(w, 0), Vector2(w, 두께),
		Vector2(두께, 두께), Vector2(두께, h - 두께),
		Vector2(w, h - 두께), Vector2(w, h), Vector2(0, h)])


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


func _도형표() -> Array:
	# 라벨에 무엇을 보는 도형인지 같이 적는다 (QA 하는 사람이 바로 알게)
	return [
		["직선 tiling", _사각(1300, 230), 1300.0],
		["사각 OUTER x4", _사각(560, 560), 560.0],
		["L자 OUTER+INNER", _L자(700, 700, 260), 700.0],
		["ㄷ자 INNER x2", _ㄷ자(700, 700, 250), 700.0],
		["작은 볼록", _사각(430, 430), 430.0],
		["작은 폐곡선", _원(150, 16), 300.0],
		["완만한 curve", _언덕(420, 170, 24), 840.0],
		["원형 폐곡선", _원(280, 24), 560.0],
		["복합 폐곡선", _복합(640), 640.0],
	]


func _도형(이름: String, 위치: Vector2, 점들: PackedVector2Array,
		머티경로: String, 시작상태: int) -> void:
	var n = 지형_S.new()
	n.name = 이름
	n.position = 위치
	n.shape_material = load(머티경로)
	n.시작상태 = 시작상태
	_root.add_child(n)
	n.owner = _root
	var pa: SS2D_Point_Array = n.get_point_array()
	pa.begin_update()
	pa.add_points(점들)
	pa.end_update()
	pa.close_shape()
	n.force_update()


func _라벨(위치: Vector2, 글: String, 크기: int, 색: Color) -> void:
	var l := Label.new()
	l.name = "L_%d_%d" % [int(위치.x), int(위치.y)]
	l.position = 위치
	l.text = 글
	l.add_theme_color_override("font_color", 색)
	l.add_theme_font_size_override("font_size", 크기)
	_root.add_child(l)
	l.owner = _root


func _배경(y: float, 높이: float, 색: Color, 이름: String) -> void:
	var r := ColorRect.new()
	r.name = 이름
	r.position = Vector2(-900, y)
	r.size = Vector2(블록폭 + 1200, 높이)
	r.color = 색
	r.z_index = -100
	_root.add_child(r)
	r.owner = _root


func _실행() -> void:
	_root = Node2D.new()
	_root.name = "SmartShape2D_Tileset_Showcase"
	root.add_child(_root)   # 트리에 없으면 force_update() 가 아무 일도 안 한다

	# 테마 2 x 내부 2 = 블록 4개, 각 블록 안에 재질 4행
	var 블록 := [
		["검정 · 채움", 1, false, Color(0.66, 0.68, 0.71), Color(0.10, 0.10, 0.12)],
		["검정 · 속빔", 1, true, Color(0.66, 0.68, 0.71), Color(0.10, 0.10, 0.12)],
		["흰색 · 채움", 2, false, Color(0.09, 0.10, 0.12), Color(0.88, 0.88, 0.90)],
		["흰색 · 속빔", 2, true, Color(0.09, 0.10, 0.12), Color(0.88, 0.88, 0.90)],
	]

	var y := 0.0
	var 도형들 := _도형표()
	# ── 맨 위 제목 — 이 씬이 무엇인지 열자마자 알 수 있게 ──────────────────
	_배경(-900.0, 620.0, Color(0.13, 0.14, 0.17), "bg_제목")
	_라벨(Vector2(-860, -840), "SmartShape2D 타일셋 쇼케이스 — QA/미리보기 전용 (게임 씬 아님)",
		120, Color(0.95, 0.95, 0.97))
	_라벨(Vector2(-860, -660),
		"재질 4 (잔디 LOCK · 벽돌 · 하수 · 나무) x 검정/흰색 x 채움(SOLID)/속빔(HOLLOW) x 도형 9",
		74, Color(0.72, 0.74, 0.80))
	_라벨(Vector2(-860, -540),
		"검정은 밝은 배경 · 흰색은 어두운 배경 위에 둔다 (실루엣과 반투명 잔상 확인용)."
		+ "  색은 런타임 상태이므로 여기 흑/백은 '시작상태' 일 뿐이다.",
		62, Color(0.72, 0.74, 0.80))
	for b in 블록:
		var 제목: String = b[0]
		var 상태: int = b[1]
		var 속빔: bool = b[2]
		var 배경색: Color = b[3]
		var 글색: Color = b[4]
		var 블록높이: float = 재질표.size() * 행높이 + 260.0
		_배경(y - 200.0, 블록높이, 배경색, "bg_" + 제목)
		_라벨(Vector2(-860, y - 170), 제목, 88, 글색)
		for ri in 재질표.size():
			var 재질: Array = 재질표[ri]
			var 표시: String = 재질[0]
			var 머티: String = 재질[2] if 속빔 else 재질[1]
			if not ResourceLoader.exists(머티):
				push_warning("머티리얼 없음, 건너뜀: %s" % 머티)
				continue
			var ry: float = y + ri * 행높이
			_라벨(Vector2(-860, ry + 300), 표시, 64, 글색)
			var x := 0.0
			for 항목 in 도형들:
				_도형("%s_%s_%s" % [제목.replace(" ", ""), 표시, 항목[0]],
					Vector2(x, ry), 항목[1], 머티, 상태)
				if ri == 0:
					_라벨(Vector2(x, ry - 150), 항목[0], 52, 글색)
				x += 항목[2] + 320.0
		y += 블록높이 + 200.0

	var cam := Camera2D.new()
	cam.name = "카메라"
	# 내용 전체(제목 포함)의 한가운데. 열자마자 전체가 보이게 한다.
	cam.position = Vector2((블록폭 + 1200.0) * 0.5 - 900.0, (y - 900.0) * 0.5)
	cam.zoom = Vector2(0.095, 0.095)
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
	print("[build] 블록 %d x 재질 %d x 도형 %d = 지형 %d 개"
		% [블록.size(), 재질표.size(), 도형들.size(),
			블록.size() * 재질표.size() * 도형들.size()])
	quit(0)
