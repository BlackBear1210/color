extends SceneTree
## ============================================================================
## [2026-09-15 신규 · Claude] SS2D 시그널 중복 연결 회귀 검사
## ----------------------------------------------------------------------------
## 실행: Godot --headless --path . -s res://tools/test_SS2D_중복연결.gd
##
## 무엇을 잡나: stage_2-1 을 열면 지형 36 개마다
##   "Signal 'update_finished' / 'material_override_changed' / 'changed' is already connected"
## 가 3 건씩(=108) 났다. 원인은 addons/rmsmartshape/shapes/shape.gd 의
## set_point_array() / _set_material() 이 **새 리소스에 이미 같은 연결이 있는지 안 보고** connect
## 한 것 + 엔진의 script 오버라이드 복원 경로(SceneState::instantiate, issue #2958 우회)의 조합이다.
## 자세한 원인은 shape.gd 의 주석과 docs/작업기록_2026-09-15_Claude_SS2D_중복신호_수정.md.
##
## ▣ 원칙
##   · 오류 개수만 세지 않는다 — **연결이 정확히 하나**인지, **옛 리소스는 더 이상 이 노드를 부르지 않는지**,
##     **새 리소스는 한 번만 부르는지**, **남의 연결은 남는지**를 리소스 쪽에서 직접 센다.
##   · U 계열은 트리에 넣지 않은 맨 SS2D 노드로 setter 만 검사한다 (렌더러 불필요).
##   · R 계열은 엔진의 실제 script 오버라이드 복원 경로를 **PackedScene 을 진짜로 구워서** 재현한다.
##   · S 계열은 실제 stage_2-1 을 읽고 트리에 올려 36 개 지형을 전부 센다.
##   · exit 0 이어도 stdout 에 ERROR 가 찍히면 통과가 아니다 — 수정 전에는 R/S 에서 ERROR 가 찍힌다.
## ============================================================================

const 스테이지 := "res://scenes/world_2_클로드/stage_2-1.tscn"
const 템플릿 := "res://scenes/집/스마트 매쉬 assets/WALL_벽체/TEMPLATE_WALL_SOLID.tscn"
const 하수도_스크립트 := "res://scripts/스마트월드/하수도_자연발판.gd"

var 검사수 := 0
var 실패수 := 0


func _initialize() -> void:
	Engine.max_fps = 0
	call_deferred("_실행")


func 검사(id: String, 이름: String, ok: bool, 덧: String = "") -> void:
	검사수 += 1
	if not ok:
		실패수 += 1
	print("%s %s %s%s" % ["PASS" if ok else "FAIL", id, 이름, ("  — " + 덧) if 덧 != "" else ""])


func 프레임(n: int = 3) -> void:
	for i in n:
		await physics_frame


## 리소스 `res` 의 시그널 `sig` 에 **노드 `node` 의 메서드 `method`** 가 몇 번 붙어 있나.
## 다른 노드의 연결은 세지 않는다 — "남의 연결을 지우지 않는가"를 따로 볼 수 있게.
func 연결수(res: Object, sig: String, node: Object, method: String) -> int:
	var n := 0
	for c in res.get_signal_connection_list(sig):
		var cb: Callable = c["callable"]
		if cb.get_object() == node and cb.get_method() == method:
			n += 1
	return n


## 지형 하나의 세 연결 개수를 [점:update_finished, 점:material_override_changed, 재질:changed] 로.
func 세연결(s: Node) -> Array[int]:
	var pa: Object = s.get("_points")
	var m: Object = s.get("shape_material")
	return [
		연결수(pa, "update_finished", s, "_points_modified") if pa != null else -1,
		연결수(pa, "material_override_changed", s, "_handle_material_override_change") if pa != null else -1,
		연결수(m, "changed", s, "_handle_material_change") if m != null else -1,
	]


func _실행() -> void:
	print("\n════════ SS2D 중복 연결 검사 ════════")
	_U_점배열()
	_U_재질()
	_U_공유()
	_U_널()
	await _R_스크립트교체()
	await _S_스테이지()
	print("\nSS2D_CONNECT_RESULT %d/%d PASS" % [검사수 - 실패수, 검사수])
	quit(1 if 실패수 > 0 else 0)


# ──────────────────────────────────────────────────────────────────────────
# U · 점배열 setter
# ──────────────────────────────────────────────────────────────────────────
func _U_점배열() -> void:
	var s := SS2D_Shape_Closed.new()
	var A := SS2D_Point_Array.new()
	var B := SS2D_Point_Array.new()

	s.set_point_array(A)
	검사("U01", "A 를 처음 넣으면 두 시그널이 각 1 개 연결", 세연결(s)[0] == 1 and 세연결(s)[1] == 1)

	s.set_point_array(A)
	검사("U02", "같은 A 를 다시 넣어도 연결은 그대로 1 개", 세연결(s)[0] == 1 and 세연결(s)[1] == 1, str(세연결(s)))

	# 엔진 복원 경로를 흉내: B 에 **이 노드의 콜러블**이 미리 붙어 있는 상태에서 B 로 바꾼다.
	B.update_finished.connect(s._points_modified)
	B.material_override_changed.connect(s._handle_material_override_change)
	s.set_point_array(B)
	검사("U03", "미리 연결된 B 로 바꿔도 연결은 1 개 (늘어나지 않음)", 세연결(s)[0] == 1 and 세연결(s)[1] == 1, str(세연결(s)))
	검사("U04", "옛 A 에서는 이 노드의 연결이 사라짐",
		연결수(A, "update_finished", s, "_points_modified") == 0
		and 연결수(A, "material_override_changed", s, "_handle_material_override_change") == 0)

	# 행동 확인: A 는 더 이상 이 노드를 부르지 않고, B 는 한 번만 부른다.
	var 횟수 := [0]
	s.points_modified.connect(func() -> void: 횟수[0] += 1)
	A.update_finished.emit()
	검사("U05", "A.update_finished 는 이 노드를 부르지 않음", 횟수[0] == 0, "호출 %d" % 횟수[0])
	B.update_finished.emit()
	검사("U06", "B.update_finished 는 정확히 한 번 부름", 횟수[0] == 1, "호출 %d" % 횟수[0])

	s._dirty = false
	s.set_point_array(B)
	검사("U07", "같은 값을 다시 넣어도 set_as_dirty 는 유지됨", s._dirty == true)

	s.free()


# ──────────────────────────────────────────────────────────────────────────
# U · 재질 setter
# ──────────────────────────────────────────────────────────────────────────
func _U_재질() -> void:
	var s := SS2D_Shape_Closed.new()
	var A := SS2D_Material_Shape.new()
	var B := SS2D_Material_Shape.new()

	s.shape_material = A
	검사("U11", "재질 A 처음 넣으면 changed 1 개 연결", 연결수(A, "changed", s, "_handle_material_change") == 1)
	s.shape_material = A
	검사("U12", "같은 A 다시 넣어도 1 개", 연결수(A, "changed", s, "_handle_material_change") == 1)

	B.changed.connect(s._handle_material_change)
	s.shape_material = B
	검사("U13", "미리 연결된 B 로 바꿔도 1 개", 연결수(B, "changed", s, "_handle_material_change") == 1)
	검사("U14", "옛 A 에서는 사라짐", 연결수(A, "changed", s, "_handle_material_change") == 0)

	s._dirty = false
	A.emit_changed()
	검사("U15", "A.changed 는 이 노드를 더럽히지 않음", s._dirty == false)
	B.emit_changed()
	검사("U16", "B.changed 는 이 노드를 더럽힘", s._dirty == true)

	s.free()


# ──────────────────────────────────────────────────────────────────────────
# U · 공유 리소스 — 남의 연결을 건드리지 않는가
# ──────────────────────────────────────────────────────────────────────────
func _U_공유() -> void:
	var s1 := SS2D_Shape_Closed.new()
	var s2 := SS2D_Shape_Closed.new()
	var P := SS2D_Point_Array.new()
	var M := SS2D_Material_Shape.new()
	s1.set_point_array(P)
	s2.set_point_array(P)
	s1.shape_material = M
	s2.shape_material = M
	검사("U21", "두 노드가 같은 점배열을 쓰면 각자 1 개씩",
		연결수(P, "update_finished", s1, "_points_modified") == 1
		and 연결수(P, "update_finished", s2, "_points_modified") == 1)
	# s1 이 다른 리소스로 떠나도 s2 의 연결은 남아야 한다.
	s1.set_point_array(SS2D_Point_Array.new())
	s1.shape_material = SS2D_Material_Shape.new()
	검사("U22", "s1 이 떠나도 s2 의 점배열 연결은 유지", 연결수(P, "update_finished", s2, "_points_modified") == 1)
	검사("U23", "s1 이 떠나도 s2 의 재질 연결은 유지", 연결수(M, "changed", s2, "_handle_material_change") == 1)
	검사("U24", "s1 의 옛 연결은 정리됨",
		연결수(P, "update_finished", s1, "_points_modified") == 0
		and 연결수(M, "changed", s1, "_handle_material_change") == 0)
	s1.free()
	s2.free()


# ──────────────────────────────────────────────────────────────────────────
# U · null 처리
# ──────────────────────────────────────────────────────────────────────────
func _U_널() -> void:
	var s := SS2D_Shape_Closed.new()
	var A := SS2D_Point_Array.new()
	s.set_point_array(A)
	s.set_point_array(null)
	var pa: Object = s.get("_points")
	검사("U31", "null 점배열은 새 빈 배열로 대체되고 연결됨",
		pa != null and pa != A and 연결수(pa, "update_finished", s, "_points_modified") == 1)
	검사("U32", "옛 A 의 연결은 정리됨", 연결수(A, "update_finished", s, "_points_modified") == 0)

	var M := SS2D_Material_Shape.new()
	s.shape_material = M
	s.shape_material = null
	검사("U33", "null 재질은 null 로 남고 옛 연결은 정리됨",
		s.shape_material == null and 연결수(M, "changed", s, "_handle_material_change") == 0)
	s.free()


# ──────────────────────────────────────────────────────────────────────────
# R · 엔진의 script 오버라이드 복원 경로를 **진짜 PackedScene** 으로 재현
#     (TEMPLATE_WALL_SOLID 인스턴스 → 부모 씬에서 script 만 하수도_자연발판.gd 로 바꿔 저장 → 다시 인스턴스)
#     수정 전이면 여기서 stdout 에 ERROR 3 건이 찍힌다.
# ──────────────────────────────────────────────────────────────────────────
func _R_스크립트교체() -> void:
	var tpl := load(템플릿) as PackedScene
	if tpl == null:
		검사("R01", "템플릿 로드", false, 템플릿)
		return
	var 부모 := Node2D.new()
	부모.name = "R"
	var inst := tpl.instantiate() as Node2D
	inst.name = "지형"
	부모.add_child(inst)
	inst.owner = 부모  # 새로 만든 노드에만 owner (CLAUDE.md §6)
	inst.set_script(load(하수도_스크립트))
	var ps := PackedScene.new()
	var err := ps.pack(부모)
	검사("R01", "script 오버라이드가 든 씬 굽기", err == OK, "err=%d" % err)
	부모.free()
	if err != OK:
		return

	# 굽힌 상태 확인: 인스턴스 노드에 script 오버라이드가 정말 들어갔나
	var st := ps.get_state()
	var script_override := false
	for i in st.get_node_count():
		if st.get_node_name(i) == "지형":
			for p in st.get_node_property_count(i):
				if st.get_node_property_name(i, p) == "script":
					script_override = true
	검사("R02", "구운 씬에 인스턴스 노드의 script 오버라이드가 들어 있음", script_override)

	# 다시 인스턴스 = 엔진의 복원 경로(옛 상태 저장 → set_script → 옛 값 재대입)가 실제로 돈다.
	var again := ps.instantiate() as Node2D
	var s := again.get_node("지형")
	검사("R03", "새 인스턴스의 스크립트가 하수도_자연발판.gd", s.get_script() != null and s.get_script().resource_path == 하수도_스크립트)
	var c := 세연결(s)
	검사("R04", "복원 뒤에도 세 연결이 각 1 개 (중복·누락 없음)", c == [1, 1, 1], str(c))
	# 트리에 올려 _ready(하수도_벽돌지형: 재질 duplicate 재대입)까지 지나도 1 개인가
	root.add_child(again)
	await 프레임(3)
	c = 세연결(s)
	검사("R05", "_ready 뒤(재질 복제 재대입)에도 각 1 개", c == [1, 1, 1], str(c))
	again.queue_free()
	await 프레임(2)


# ──────────────────────────────────────────────────────────────────────────
# S · 실제 stage_2-1
# ──────────────────────────────────────────────────────────────────────────
func _S_스테이지() -> void:
	var ps := load(스테이지) as PackedScene
	if ps == null:
		검사("S01", "stage_2-1 로드", false)
		return
	var 씬 := ps.instantiate() as Node2D
	var 하수도들: Array[Node] = []
	_모으기(씬, 하수도들)
	검사("S01", "하수도_자연발판 지형 수 (기록 당시 36)", 하수도들.size() > 0, "%d 개" % 하수도들.size())

	var 나쁜 := 0
	for s in 하수도들:
		if 세연결(s) != [1, 1, 1]:
			나쁜 += 1
			print("   ✗ %s → %s" % [s.name, str(세연결(s))])
	검사("S02", "인스턴스 직후 모든 지형의 세 연결이 각 1 개", 나쁜 == 0, "어긋남 %d 개" % 나쁜)

	# 오버라이드가 복원값(템플릿 리소스)에 덮이지 않고 최종 씬 값으로 남았는가.
	# resource_path 는 local_to_scene 복제본에서 믿을 수 없어 **점 좌표**로 비교한다.
	var 템플릿점 := 0
	var tpl_inst := (load(템플릿) as PackedScene).instantiate()
	var tv: PackedVector2Array = (tpl_inst.get("_points") as SS2D_Point_Array).get_vertices()
	tpl_inst.free()
	for s in 하수도들:
		var pa := s.get("_points") as SS2D_Point_Array
		if pa != null and pa.get_vertices() == tv:
			템플릿점 += 1
	검사("S03", "점배열이 템플릿 것이 아니라 씬에 저장된 것 (36 개 모두 _points 오버라이드)", 템플릿점 == 0, "템플릿 좌표와 같은 것 %d 개" % 템플릿점)

	root.add_child(씬)
	await 프레임(4)
	나쁜 = 0
	for s in 하수도들:
		if 세연결(s) != [1, 1, 1]:
			나쁜 += 1
	검사("S04", "_ready 이후에도 모든 지형이 각 1 개", 나쁜 == 0, "어긋남 %d 개" % 나쁜)

	# 해제 후 다시 읽어도 같은가 (누적 연결이 리소스 캐시에 남지 않는가)
	씬.queue_free()
	await 프레임(2)
	var 씬2 := ps.instantiate() as Node2D
	var 둘 := []
	_모으기(씬2, 둘)
	나쁜 = 0
	for s in 둘:
		if 세연결(s) != [1, 1, 1]:
			나쁜 += 1
	검사("S05", "해제 후 재로드해도 각 1 개", 나쁜 == 0, "어긋남 %d 개" % 나쁜)
	씬2.free()


func _모으기(n: Node, out: Array) -> void:
	var sc: Variant = n.get_script()
	if sc != null and sc.resource_path == 하수도_스크립트:
		out.append(n)
	for c in n.get_children():
		_모으기(c, out)
