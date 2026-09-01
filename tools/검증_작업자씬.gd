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
## ★[2026-08-31] 재질마다 확정된 텍스처 배율이 다르다.
##   철판(METAL)은 0.6 이 확정값이다 — 외곽 림과 이음선 두께를 이전의 60% 로 줄이고
##   같은 면적에 패턴을 1.67 배 더 보이게 한 결정이다
##   (`docs/작업기록_2026-08-31_Codex_철판_SS2D_템플릿.md`).
##   여기에 0.35 를 그대로 들이대면 **맞게 만든 재질이 검사에서 틀린 것으로 나온다.**
## [엣지 배율, 채움 배율] — 둘이 다를 수 있다.
## ⚠ 철판은 문서에는 둘 다 0.6 이라고 적혀 있지만 실제 `.tres` 는 채움이 **0.48** 이다.
##   어느 쪽이 맞는지는 아트 판단이라 여기서는 **지금 확정된 값을 그대로 기록**한다.
##   값을 바꾸기로 하면 이 표와 `.tres` 를 같이 고친다.
const 배율표 := { "METAL": [0.6, 0.48] }

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
		# 밑줄로 시작하는 폴더는 보관용(_ARCHIVE 등) — 작업자용 Template 이 아니다
		if sub.begins_with("_"):
			continue
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
		var 기대배율 := _기대배율(이름, 0)
		var 기대채움배율 := _기대배율(이름, 1)
		var 앞 := 실패
		var ps: PackedScene = load(경로)
		if ps == null:
			실패 += 1
			print("  %s\n    ✗ 로드 실패" % 이름)
			continue
		var n: Node = ps.instantiate()
		root.add_child(n)
		# ★[2026-08-29] 지형이 루트라는 보장이 없다 — `벽돌 테스.tscn` 은 빈 Node2D 아래에
		#   지형을 자식으로 달고 있다. 예전에는 루트에서 `시작상태` 를 못 찾아 null 이 되고
		#   `int(null)` 에서 **검사기가 통째로 죽었다**(그 뒤 씬들은 아예 안 봤다).
		var 지형 := _지형_찾기(n)
		if 지형 == null:
			실패 += 1
			print("  %s
	✗ 칠할 수 있는 지형이 없다 (지형.gd 를 안 씀)" % 이름)
			n.queue_free()
			continue

		# 이름 규칙: TEMPLATE_<재질>_<SOLID|HOLLOW>.tscn
		var 속빔 := 이름.contains("HOLLOW")
		_확인(지형.get("shape_material") != null, "shape_material 이 비었다")
		var m = 지형.get("shape_material")
		if m != null:
			var metas: Array = m.get_all_edge_meta_materials()
			# 360도 단일 엣지는 벽돌테스 방식의 미터 조인이다. 코너·테이퍼를 겹치지 않는 대신
			# CROP과 균일 폭을 반드시 켜야 도형을 늘리거나 꺾어도 테두리 두께가 유지된다.
			var 단일_사방 := metas.size() == 1
			_확인(metas.size() == 5 or 단일_사방,
				"엣지 메타가 5방향 또는 단일 사방 구성이 아니다 (%d)" % metas.size())
			if 단일_사방:
				var meta = metas[0]
				var e = meta.edge_material
				_확인(e != null, "단일 사방 엣지 머티리얼이 없다")
				_확인(meta.normal_range != null
					and is_equal_approx(meta.normal_range.distance, 360.0),
					"단일 사방 normal_range 가 360도가 아니다")
				if e != null:
					_확인(is_equal_approx(e.texture_scale, 기대배율),
						"texture_scale 이 %.2f 가 아니다 (%.3f)" % [기대배율, e.texture_scale])
					_확인(e.textures.size() == 1 and e.textures[0] != null,
						"단일 사방 엣지 텍스처가 정확히 1개가 아니다")
					_확인(not e.use_corner_texture, "단일 사방 재질에 코너 텍스처가 켜져 있다")
					_확인(not e.use_taper_texture, "단일 사방 재질에 taper 가 켜져 있다")
					_확인(int(e.fit_mode) == 1, "단일 사방 fit_mode 가 CROP이 아니다")
					_확인(e.uniform_width, "단일 사방 uniform_width 가 꺼져 있다")
			else:
				var 방향수 := 0
				var 코너수 := 0
				for meta in metas:
					var e = meta.edge_material
					_확인(e != null, "엣지 머티리얼이 없다")
					if e == null:
						continue
					_확인(is_equal_approx(e.texture_scale, 기대배율),
						"texture_scale 이 %.2f 가 아니다 (%.3f)" % [기대배율, e.texture_scale])
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
			_확인(is_equal_approx(m.fill_texture_scale, 기대채움배율),
				"fill_texture_scale 이 %.2f 가 아니다 (%.3f)"
					% [기대채움배율, m.fill_texture_scale])

		# ★검정 Template 은 무색(0)으로 나간다 — 색은 런타임 상태이고 작업자가 고른다.
		#   흰색 Template(`_WHITE` · `_흰색`)만 예외로 **흰색(2)을 갖고 태어난다.**
		#   흰 아트를 든 지형이 무색이면 "희게 보이는데 아무에게도 안 위험한" 거짓말이 된다.
		var 기대: int = 흰색씬인가(이름)
		var 실제: int = int(지형.get("시작상태"))
		_확인(실제 == 기대, "시작상태가 %d 여야 하는데 %d" % [기대, 실제])

		# 콜리전 — 이게 없으면 밟을 수 없다
		var body := 지형.get_node_or_null("StaticBody2D")
		_확인(body != null, "StaticBody2D 가 없다")
		_확인(지형.get_node_or_null("StaticBody2D/CollisionPolygon2D") != null,
			"CollisionPolygon2D 가 없다")
		_확인(String(지형.get("collision_polygon_node_path")) == "StaticBody2D/CollisionPolygon2D",
			"collision_polygon_node_path 가 안 맞는다")

		# 점 — 닫힌 사각형 4점 (작업자가 잡아 늘릴 시작 도형)
		var pa: SS2D_Point_Array = 지형.get_point_array()
		_확인(pa != null and pa.get_point_count() >= 4, "시작 점이 4개 미만")
		# 시작 두께가 '공중 발판 권장 180px' 을 이미 만족해야 한다
		if pa != null and pa.get_point_count() >= 4:
			var pts := pa.get_tessellated_points()
			var mn := pts[0]
			var mx := pts[0]
			for p in pts:
				mn = mn.min(p)
				mx = mx.max(p)
			_확인(mx.y - mn.y >= 180.0,
				"시작 두께가 %.0f px — 권장 180px 미만" % (mx.y - mn.y))

		print("  %-32s %s" % [이름, "OK" if 실패 == 앞 else "FAIL"])
		for msg in 메시지:
			print(msg)
		메시지.clear()
		n.queue_free()
		root.remove_child(n)

	print("\n검증 %d 통과 / %d 실패" % [통과, 실패])
	quit(0 if 실패 == 0 else 1)


## 이름이 흰색 키트인가 → 기대하는 시작상태(0 = 무색, 2 = 흰색).
func 흰색씬인가(이름: String) -> int:
	var 기본 := 이름.get_basename()
	return 2 if (기본.ends_with("_WHITE") or 기본.ends_with("_흰색")) else 0


## 씬 안에서 칠할 수 있는 지형 노드를 찾는다 (루트이거나 그 아래 어딘가).
func _지형_찾기(n: Node) -> Node:
	if n.has_method("반대색인가"):
		return n
	for 자식 in n.get_children():
		var 찾음 := _지형_찾기(자식)
		if 찾음 != null:
			return 찾음
	return null


## 이 씬이 기대하는 텍스처 배율. 칸 0 = 엣지, 칸 1 = 채움.
## 이름에 재질 이름이 들어 있으면 그 재질의 확정값을 쓰고, 없으면 공통 기본값을 쓴다.
func _기대배율(이름: String, 칸: int) -> float:
	for 키 in 배율표:
		if 이름.contains(String(키)):
			var 쌍: Array = 배율표[키]
			return float(쌍[칸])
	return 배율
