extends SceneTree
## ============================================================================
## [2026-09-02 신규] 지형 Template 을 두 번 꽂으면 **점이 독립인가**
## ----------------------------------------------------------------------------
## 실행: godot --headless --path . -s res://tools/test_템플릿_점독립.gd
##
## ▣ 무엇을 고정하나 (성진님 지시 2026-09-02: "템플릿을 독립적하게 만들어")
##   Template 하나를 **두 번 인스턴스**해서
##     1. 점 배열(`SS2D_Point_Array`)이 서로 다른 객체인가
##     2. 점(`SS2D_Point`) 하나하나도 서로 다른 객체인가  ← 여기가 진짜다
##     3. 한쪽 점을 옮겨도 다른 쪽이 안 움직이는가        ← 이게 증상이다
##
## ⚠ 2 번이 왜 진짜인가
##   점 배열에만 `resource_local_to_scene` 을 주면 배열은 갈라지는데
##   **안의 점은 그대로 공유된다.** 그러면 1 번은 통과하는데 3 번이 깨진다.
##   실제로 그 상태를 한 번 만들어 보고 확인했다.
## ============================================================================

const 폴더 := "res://scenes/집/스마트 매쉬 assets"

var 통과 := 0
var 실패 := 0


func _init() -> void:
	call_deferred("_실행")


func _확인(조건: bool, 글: String) -> void:
	if 조건:
		통과 += 1
	else:
		실패 += 1
		print("  ✖ %s" % 글)


func _실행() -> void:
	var 파일들: Array[String] = []
	_모으기(폴더, 파일들)
	파일들.sort()

	print("\n=== 지형 Template 점 독립 검사 (%d 개) ===" % 파일들.size())
	for 경로 in 파일들:
		await _한개(경로)

	print("\n── 인스턴스를 고치고 맵을 저장해도 **원본 Template 이 안 다치나**")
	for 경로 in 파일들:
		_원본_안다치나(경로)

	print("\n════════════════════════════════════════")
	print("  통과 %d · 실패 %d" % [통과, 실패])
	print("════════════════════════════════════════\n")
	quit(1 if 실패 > 0 else 0)


func _템플릿인가(경로: String) -> bool:
	var 이름 := 경로.get_file()
	if 이름.begins_with("TEMPLATE_"):
		return true
	return 이름 in ["벽돌 계단.tscn", "벽돌 계단_흰색.tscn", "벽돌 테스.tscn", "벽돌 테스_흰색.tscn"]


func _모으기(폴더_: String, 담을곳: Array[String]) -> void:
	var d := DirAccess.open(폴더_)
	if d == null:
		return
	d.list_dir_begin()
	var 이름 := d.get_next()
	while 이름 != "":
		var 경로 := "%s/%s" % [폴더_, 이름]
		if d.current_is_dir():
			if not 이름.begins_with(".") and 이름 != "_ARCHIVE":
				_모으기(경로, 담을곳)
		elif 이름.ends_with(".tscn") and _템플릿인가(경로):
			담을곳.append(경로)
		이름 = d.get_next()
	d.list_dir_end()


func _한개(경로: String) -> void:
	var 이름 := 경로.get_file()
	var 씬 := load(경로) as PackedScene
	if 씬 == null:
		_확인(false, "%s: 씬을 못 읽었다" % 이름)
		return

	var a := 씬.instantiate()
	var b := 씬.instantiate()
	root.add_child(a)
	root.add_child(b)
	var sa := _지형_찾기(a)
	var sb := _지형_찾기(b)
	if sa == null or sb == null:
		_확인(false, "%s: SS2D 지형 노드를 못 찾았다" % 이름)
		a.free()
		b.free()
		return

	var pa = sa.get_point_array()
	var pb = sb.get_point_array()
	_확인(pa != pb, "%s: 점 배열이 아직 같은 객체다" % 이름)

	var 키들: PackedInt32Array = pa.get_all_point_keys()
	if 키들.is_empty():
		_확인(false, "%s: 점이 하나도 없다" % 이름)
		a.free()
		b.free()
		return

	# 점 객체가 하나라도 공유되면 안 된다.
	var 공유된_점 := 0
	for k in 키들:
		if pa.get_point(k) == pb.get_point(k):
			공유된_점 += 1
	_확인(공유된_점 == 0, "%s: 점 %d 개가 아직 공유 중이다" % [이름, 공유된_점])

	# 진짜 증상: 한쪽을 옮기면 다른 쪽이 따라오나.
	var 키: int = 키들[0]
	var 원래: Vector2 = pb.get_point_position(키)
	pa.set_point_position(키, pa.get_point_position(키) + Vector2(500, 300))
	_확인(pb.get_point_position(키) == 원래,
			"%s: A 를 옮겼는데 B 도 움직였다 (%s → %s)" % [이름, 원래, pb.get_point_position(키)])

	a.free()
	b.free()


## ★성진님 질문 그대로: "인스턴스된 걸 독립적으로 수정해도 원본을 안 해치지?"
##
## ▣ 에디터가 하는 일을 그대로 흉내 낸다
##   1. `GEN_EDIT_STATE_INSTANCE` 로 꽂는다   ← 에디터가 씬에 인스턴스를 놓을 때 쓰는 모드
##   2. 점을 끌어서 모양을 바꾼다
##   3. 맵 씬을 저장한다(`PackedScene.pack()` + `ResourceSaver.save()`)
##   4. **Template 파일의 내용이 그대로인지** 바이트로 대조한다
##      + 맵 씬에 `_points` 덮어쓰기가 저장됐는지 본다(= 수정이 맵 쪽에 담겼다는 증거)
func _원본_안다치나(경로: String) -> void:
	var 이름 := 경로.get_file()
	var 전_내용 := FileAccess.get_file_as_string(경로)

	var 씬 := load(경로) as PackedScene
	var 맵 := Node2D.new()
	맵.name = "가짜맵"
	var n := 씬.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	맵.add_child(n)
	n.owner = 맵

	var s := _지형_찾기(n)
	if s == null:
		맵.free()
		return
	# ⚠ Template 5 개(`벽돌 테스` · METAL_SOLID · PIPE)는 SS2D 가 **껍데기 안의 자식**이다.
	#   Godot 은 인스턴스 **안쪽** 노드의 수정을 "Editable Children" 을 켰을 때만 저장한다.
	#   에디터에서도 똑같다 — 안 켜면 그 지형은 아예 선택이 안 된다.
	#   그래서 여기서도 같은 조건을 만들어 준다.
	if s != n:
		맵.set_editable_instance(n, true)
	var p = s.get_point_array()
	var 키들: PackedInt32Array = p.get_all_point_keys()
	if 키들.is_empty():
		맵.free()
		return
	# 점을 끈다 = 작업자가 모양을 고치는 것
	p.set_point_position(키들[0], p.get_point_position(키들[0]) + Vector2(777, 555))

	var 팩 := PackedScene.new()
	팩.pack(맵)
	var 임시 := "user://_점독립검사.tscn"
	ResourceSaver.save(팩, 임시)
	var 저장된 := FileAccess.get_file_as_string(임시)
	맵.free()

	_확인(FileAccess.get_file_as_string(경로) == 전_내용,
			"%s: 인스턴스를 고쳤더니 **Template 파일이 바뀌었다**" % 이름)
	_확인(저장된.contains("_points = SubResource("),
			"%s: 맵 씬에 `_points` 덮어쓰기가 안 저장됐다 (수정이 어디로 갔나?)" % 이름)


## Template 루트가 SS2D 가 아닌 경우(`벽돌 테스`)가 있다 — 껍데기 아래를 한 겹 본다.
func _지형_찾기(n: Node) -> Node:
	if n.has_method("get_point_array"):
		return n
	for c in n.get_children():
		if c.has_method("get_point_array"):
			return c
	return null
