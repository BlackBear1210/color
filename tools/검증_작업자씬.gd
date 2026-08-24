extends SceneTree
## ============================================================================
## [2026-08-25 신규] 작업자용 SmartShape2D 씬 검증
## ----------------------------------------------------------------------------
## 실행: Godot --headless --path . -s res://tools/검증_작업자씬.gd
##
## ▣ 왜 있나
##   "작업자가 씬을 끌어다 놓으면 바로 지형이 찍혀야 한다" 는 요구는
##   씬이 로드된다는 것만으로는 보장되지 않는다. 머티리얼 · 엣지 4방향 ·
##   코너 · taper · 배율 · 채움/속빔 · 콜리전이 전부 물려 있어야 한다.
##   그걸 파일이 아니라 **로드된 객체**에서 확인한다.
## ============================================================================

const 폴더 := "res://scenes/집/스마트 매쉬 assets"
const 배율 := 0.35

var 통과 := 0
var 실패 := 0
var 메시지: PackedStringArray = PackedStringArray()


func _init() -> void:
	call_deferred("_실행")


func _확인(조건: bool, 글: String) -> void:
	if 조건:
		통과 += 1
	else:
		실패 += 1
		메시지.push_back("    ✗ " + 글)


func _씬목록() -> PackedStringArray:
	var 결과 := PackedStringArray()
	var d := DirAccess.open(폴더)
	if d == null:
		return 결과
	for sub in d.get_directories():
		var d2 := DirAccess.open("%s/%s" % [폴더, sub])
		if d2 == null:
			continue
		for f in d2.get_files():
			if f.ends_with(".tscn"):
				결과.push_back("%s/%s/%s" % [폴더, sub, f])
	결과.sort()
	return 결과


func _실행() -> void:
	var 목록 := _씬목록()
	print("작업자 씬 %d 개 검증\n" % 목록.size())
	for 경로 in 목록:
		var 이름 := 경로.get_file()
		var 앞 := 실패
		var ps: PackedScene = load(경로)
		if ps == null:
			실패 += 1
			print("  %s\n    ✗ 로드 실패" % 이름)
			continue
		var n: Node = ps.instantiate()
		root.add_child(n)

		var 속빔 := 이름.contains("속빔")
		_확인(n.get("shape_material") != null, "shape_material 이 비었다")
		var m = n.get("shape_material")
		if m != null:
			var metas: Array = m.get_all_edge_meta_materials()
			_확인(metas.size() == 5, "엣지 메타가 5개가 아니다 (%d)" % metas.size())
			var 방향수 := 0
			var 코너수 := 0
			for meta in metas:
				var e = meta.edge_material
				_확인(e != null, "엣지 머티리얼이 없다")
				if e == null:
					continue
				_확인(is_equal_approx(e.texture_scale, 배율),
					"texture_scale 이 %.2f 가 아니다 (%.3f)" % [배율, e.texture_scale])
				if e.use_corner_texture:
					코너수 += 1
					_확인(e.textures_corner_outer.size() > 0
						and e.textures_corner_outer[0] != null, "corner_outer 없음")
					_확인(e.textures_corner_inner.size() > 0
						and e.textures_corner_inner[0] != null, "corner_inner 없음")
				else:
					방향수 += 1
					_확인(e.textures.size() > 0 and e.textures[0] != null, "엣지 텍스처 없음")
					_확인(e.use_taper_texture, "taper 가 꺼져 있다")
					_확인(e.textures_taper_left.size() > 0
						and e.textures_taper_left[0] != null, "taper_left 없음")
					_확인(e.textures_taper_right.size() > 0
						and e.textures_taper_right[0] != null, "taper_right 없음")
			_확인(방향수 == 4, "4방향 엣지가 4개가 아니다 (%d)" % 방향수)
			_확인(코너수 == 1, "코너 엣지가 1개가 아니다 (%d)" % 코너수)
			# 속빔은 fill_textures 가 **비어 있어야** 진짜 알파 투명 내부가 된다
			if 속빔:
				_확인(m.fill_textures.is_empty(), "속빔인데 fill_textures 가 차 있다")
			else:
				_확인(m.fill_textures.size() == 1 and m.fill_textures[0] != null,
					"채움인데 fill 텍스처가 없다")
			_확인(is_equal_approx(m.fill_texture_scale, 배율), "fill_texture_scale 이 다르다")

		# 시작상태 — 이름과 맞아야 한다 (0 무색 / 1 검정 / 2 흰색)
		var 기대: int = 0
		if 이름.contains("검정"):
			기대 = 1
		elif 이름.contains("흰색"):
			기대 = 2
		_확인(int(n.get("시작상태")) == 기대,
			"시작상태가 %d 여야 하는데 %d" % [기대, int(n.get("시작상태"))])

		# 콜리전 — 이게 없으면 밟을 수 없다
		var body := n.get_node_or_null("StaticBody2D")
		_확인(body != null, "StaticBody2D 가 없다")
		_확인(n.get_node_or_null("StaticBody2D/CollisionPolygon2D") != null,
			"CollisionPolygon2D 가 없다")
		_확인(String(n.get("collision_polygon_node_path")) == "StaticBody2D/CollisionPolygon2D",
			"collision_polygon_node_path 가 안 맞는다")

		# 점 — 닫힌 사각형 4점 (작업자가 잡아 늘릴 시작 도형)
		var pa: SS2D_Point_Array = n.get_point_array()
		_확인(pa != null and pa.get_point_count() >= 4, "시작 점이 4개 미만")

		print("  %-32s %s" % [이름, "OK" if 실패 == 앞 else "FAIL"])
		for msg in 메시지:
			print(msg)
		메시지.clear()
		n.queue_free()
		root.remove_child(n)

	print("\n검증 %d 통과 / %d 실패" % [통과, 실패])
	quit(0 if 실패 == 0 else 1)
