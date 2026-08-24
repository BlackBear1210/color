extends SceneTree
## ============================================================================
## [2026-08-24 신규] P1(taper) 수정의 하위호환 증명 — 정점·UV 덤프
## ----------------------------------------------------------------------------
## 실행:
##   Godot --headless --path . -s res://tools/검증_taper_하위호환.gd -- --출력=D:/dump.txt
##
## ▣ 왜
##   P0 때와 같은 방식이다. "안 바뀐 것 같다" 가 아니라
##   기존 머티리얼 전부 x 도형 전부의 정점·UV 를 덤프해서
##   수정 전/후 SHA256 이 같은지 본다.
##
## ▣ 대상
##   저장소의 기존 SS2D 머티리얼 전부 (grass_v4 4개 + 기존 지형 12개).
##   전부 use_taper_texture = false 이고 taper 텍스처가 하나도 없으므로
##   _taper_quad() 는 get_taper_tex() 가 null 을 돌려주는 지점에서 즉시 빠진다
##   = 이번에 고친 두 줄에 도달하지 않는다. 그걸 수치로 확인한다.
## ============================================================================

const 셰이프_S := preload("res://addons/rmsmartshape/shapes/shape.gd")

var _출력 := ""


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--출력="):
			_출력 = a.substr("--출력=".length())
	call_deferred("_실행")


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


func _복합(크기: float) -> PackedVector2Array:
	var s := 크기
	return PackedVector2Array([
		Vector2(0.00 * s, 0.28 * s), Vector2(0.30 * s, 0.00 * s),
		Vector2(0.55 * s, 0.18 * s), Vector2(0.72 * s, 0.05 * s),
		Vector2(1.00 * s, 0.34 * s), Vector2(0.86 * s, 0.62 * s),
		Vector2(0.95 * s, 0.86 * s), Vector2(0.58 * s, 0.98 * s),
		Vector2(0.34 * s, 0.80 * s), Vector2(0.12 * s, 0.92 * s)])


## 폴더를 훑어 SS2D 머티리얼 .tres 를 전부 찾는다 (목록을 손으로 안 적는다)
func _머티목록() -> PackedStringArray:
	var 결과 := PackedStringArray()
	var 후보 := ["res://assets/textures/smartshape/",
		"res://assets/textures/smartshape/grass_v4/tres/"]
	for 폴더 in 후보:
		var d := DirAccess.open(폴더)
		if d == null:
			continue
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			if f.ends_with(".tres"):
				결과.push_back(폴더 + f)
			f = d.get_next()
		d.list_dir_end()
	결과.sort()
	return 결과


func _실행() -> void:
	var 도형표 := [
		["정사각", _사각(600, 600)],
		["가로긴", _사각(1200, 300)],
		["짧은변", _사각(150, 150)],
		["L자", _L자(700, 700, 260)],
		["원", _원(300, 24)],
		["작은원", _원(110, 14)],
		["언덕", _언덕(520, 200, 26)],
		["복합", _복합(700)],
	]
	var 줄 := PackedStringArray()
	var 머티들 := _머티목록()
	var 도형수 := 0

	for 경로 in 머티들:
		var m = ResourceLoader.load(경로, "", ResourceLoader.CACHE_MODE_IGNORE)
		if m == null or not (m is SS2D_Material_Shape):
			continue
		for 항목 in 도형표:
			var s: Node2D = 셰이프_S.new()
			s.shape_material = m
			root.add_child(s)
			var pa: SS2D_Point_Array = s.get_point_array()
			pa.begin_update()
			pa.add_points(항목[1])
			pa.end_update()
			pa.close_shape()
			s.force_update()
			줄.push_back("### %s | %s" % [경로.get_file(), 항목[0]])
			var ei := 0
			for e in s.get_edges():
				줄.push_back("  edge %d  z=%d  quads=%d" % [ei, e.z_index, e.quads.size()])
				var qi := 0
				for q in e.quads:
					줄.push_back("    q%03d c=%d tap=%s ts=%.4f a=(%.3f,%.3f) b=(%.3f,%.3f) c=(%.3f,%.3f) d=(%.3f,%.3f)"
						% [qi, q.corner, str(q.is_tapered), q.texture_scale,
							q.pt_a.x, q.pt_a.y, q.pt_b.x, q.pt_b.y,
							q.pt_c.x, q.pt_c.y, q.pt_d.x, q.pt_d.y])
					qi += 1
				ei += 1
			s.queue_free()
			root.remove_child(s)
			도형수 += 1

	var 본문 := "\n".join(줄)
	var 해시 := 본문.sha256_text().to_upper()
	print("머티리얼 %d개 x 도형 %d개 = 조합 %d" % [머티들.size(), 도형표.size(), 도형수])
	print("덤프 줄 수 %d" % 줄.size())
	print("SHA256 %s" % 해시)
	if not _출력.is_empty():
		var f := FileAccess.open(_출력, FileAccess.WRITE)
		if f != null:
			f.store_string(본문)
			f.close()
			print("덤프 저장: %s" % _출력)
	quit(0)
