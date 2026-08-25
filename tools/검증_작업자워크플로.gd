extends SceneTree
## ============================================================================
## [2026-08-25 신규] STEP 2.9 — README 에 적힌 작업 순서를 **실제로 해 본다**
## ----------------------------------------------------------------------------
## 실행: Godot --headless --path . -s res://tools/검증_작업자워크플로.gd
##
## ▣ 왜
##   문서만 쓰고 "됩니다" 라고 하면 안 된다. README 6단계를 그대로 밟아서
##   정말로 Template 복제 → 이름 변경 → 배치 → 점 편집 → 저장 → 로드가
##   되는지, 그 과정에서 머티리얼/텍스처가 떨어져 나가지 않는지 확인한다.
##
## ▣ 하는 일 (README §3 과 1:1)
##   1 Template 복제        2 이름 변경        3 맵(테스트 씬)에 배치
##   4 점 편집 (긴 발판으로)  5 저장             6 다시 열어서 검사
## ============================================================================

const 템플릿 := "res://scenes/집/스마트 매쉬 assets/BRICK_벽돌/TEMPLATE_BRICK_SOLID.tscn"
const 결과씬 := "res://scenes/smartshape_test/_워크플로검증.tscn"

var 통과 := 0
var 실패 := 0


func _init() -> void:
	call_deferred("_실행")


func _확인(조건: bool, 글: String) -> void:
	if 조건:
		통과 += 1
		print("  ✔ %s" % 글)
	else:
		실패 += 1
		print("  ✗ %s" % 글)


func _실행() -> void:
	print("README 작업 순서를 그대로 실행한다\n")

	# ── 1. Template 복제 (FileSystem 우클릭 → Duplicate 과 같은 일) ───────
	#   ★ README 는 "씬 파일을 복제한다" 이지 "노드를 다른 씬으로 옮긴다" 가 아니다.
	#     그래서 여기서도 **파일을 복사**해서 시작한다.
	_확인(ResourceLoader.exists(템플릿), "1. Template 을 찾았다")
	var 원본절대 := ProjectSettings.globalize_path(템플릿)
	var 사본절대 := ProjectSettings.globalize_path(결과씬)
	DirAccess.make_dir_recursive_absolute(사본절대.get_base_dir())
	_확인(DirAccess.copy_absolute(원본절대, 사본절대) == OK, "1. 파일을 복제했다")

	# ── 2. 이름 변경 (파일 이름 = 결과씬 · 루트 노드 이름도 바꾼다) ──────
	var ps: PackedScene = ResourceLoader.load(결과씬, "", ResourceLoader.CACHE_MODE_IGNORE)
	_확인(ps != null, "2. 복제본을 열었다")
	if ps == null:
		quit(1)
		return
	var n: Node = ps.instantiate()
	n.name = "SS_BRICK_PLATFORM_01"
	_확인(n.name == "SS_BRICK_PLATFORM_01", "2. 이름 규칙대로 바꿨다")
	root.add_child(n)

	# ── 3. 맵에 배치 = 위치만 옮기면 된다 ────────────────────────────────
	n.position = Vector2(400, 600)
	_확인(n.position == Vector2(400, 600), "3. 맵에 놓을 위치를 지정했다")

	# ── 4. 점 편집 — 기본 512x192 를 긴 발판으로 늘린다 ──────────────────
	var pa: SS2D_Point_Array = n.get_point_array()
	var 전 := pa.get_point_count()
	pa.begin_update()
	for key in pa.get_all_point_keys():
		var p := pa.get_point_position(key)
		pa.set_point_position(key, Vector2(p.x * 2.4, p.y))   # 가로만 2.4배
	pa.end_update()
	n.force_update()
	var 점들 := pa.get_tessellated_points()
	var mn := 점들[0]
	var mx := 점들[0]
	for p in 점들:
		mn = mn.min(p)
		mx = mx.max(p)
	_확인(pa.get_point_count() == 전, "4. 점 개수는 그대로 (%d개)" % 전)
	_확인(mx.x - mn.x > 1100.0, "4. 가로로 늘어났다 (%.0f px)" % (mx.x - mn.x))
	_확인(mx.y - mn.y >= 180.0, "4. 두께는 권장 180px 이상 유지 (%.0f px)" % (mx.y - mn.y))

	var m = n.get("shape_material")
	_확인(m != null, "4. 점을 고쳐도 머티리얼이 그대로 붙어 있다")
	var 방향 := 0
	var 코너 := 0
	if m != null:
		for meta in m.get_all_edge_meta_materials():
			var e = meta.edge_material
			if e == null:
				continue
			if e.use_corner_texture:
				코너 += 1
			else:
				방향 += 1
	_확인(방향 == 4 and 코너 == 1, "4. 엣지 4방향 + 코너 1개 유지")

	# ── 5. 저장 (복제본 자체를 다시 저장 = Ctrl+S) ───────────────────────
	var packed := PackedScene.new()
	var ok := packed.pack(n) == OK and ResourceSaver.save(packed, 결과씬) == OK
	_확인(ok, "5. 저장했다 → %s" % 결과씬)

	# ── 6. 다시 열어서 검사 ───────────────────────────────────────────────
	var 다시: PackedScene = ResourceLoader.load(결과씬, "", ResourceLoader.CACHE_MODE_IGNORE)
	_확인(다시 != null, "6. 저장한 씬을 다시 열었다")
	if 다시 != null:
		var t: Node = 다시.instantiate()
		_확인(t.name == "SS_BRICK_PLATFORM_01", "6. 이름이 유지됐다")
		var m2 = t.get("shape_material")
		_확인(m2 != null, "6. 머티리얼이 살아 있다")
		var 텍없음 := 0
		if m2 != null:
			for meta in m2.get_all_edge_meta_materials():
				var e = meta.edge_material
				if e == null:
					텍없음 += 1
					continue
				if e.use_corner_texture:
					if e.textures_corner_outer.is_empty() or e.textures_corner_outer[0] == null:
						텍없음 += 1
				elif e.textures.is_empty() or e.textures[0] == null:
					텍없음 += 1
		_확인(텍없음 == 0, "6. 텍스처 누락 0")
		_확인(t.get_node_or_null("StaticBody2D/CollisionPolygon2D") != null,
			"6. 콜리전이 따라왔다")
		var pa2: SS2D_Point_Array = t.get_point_array()
		var pts2 := pa2.get_tessellated_points()
		var a := pts2[0]
		var b := pts2[0]
		for p in pts2:
			a = a.min(p)
			b = b.max(p)
		_확인(b.x - a.x > 1100.0, "6. 편집한 모양이 저장됐다 (%.0f px)" % (b.x - a.x))
		t.queue_free()

	print("\n워크플로 %d 통과 / %d 실패" % [통과, 실패])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(결과씬))
	quit(0 if 실패 == 0 else 1)
